"""Authenticated, persistent, room-scoped real-time sheet collaboration.

Distinct service from arcside_companion: room keys cannot execute Python.
Rooms persist in SQLite with an ordered event journal. Fine-grained cell
updates merge when independent; same-cell stale writes are rejected rather
than silently replacing another editor's work. Structural replacements use
optimistic workbook revision checks. Trusted LOCAL development deployment.
"""
from __future__ import annotations

import asyncio
import copy
import hashlib
import hmac
import json
import re
import secrets
import sqlite3
import time
from collections import defaultdict
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

ROOM_RE = re.compile(r"^[a-f0-9]{24}$")
CELL_RE = re.compile(r"^[A-Z]{1,3}[1-9][0-9]{0,5}$")
ORIGIN_RE = re.compile(r"^https?://[a-zA-Z0-9.:-]+$")
HOST_RE = re.compile(r"^(?:127\.0\.0\.1|localhost):[0-9]{2,5}$")
MAX_SNAPSHOT_BYTES=6_000_000
MAX_PATCH_BYTES=700_000
MAX_CELL_OPS=1200
MAX_EVENT_ROWS=300


def _json(value: Any) -> str:
    return json.dumps(value, separators=(",",":"), ensure_ascii=False, allow_nan=False)


def _hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _token() -> str:
    return secrets.token_urlsafe(32)


def _reference(value: str) -> str:
    if not isinstance(value, str):
        raise ValueError("Invalid cell reference")
    value=value.upper()
    if not CELL_RE.fullmatch(value):
        raise ValueError("Invalid cell reference")
    letters=re.match(r"[A-Z]+",value).group()
    n=0
    for c in letters:n=n*26+ord(c)-64
    row=int(value[len(letters):])
    if n>256 or row>100000:
        raise ValueError("Cell exceeds Arcside Sheets dimensions")
    return value


def _workbook(snapshot: Any) -> dict:
    if not isinstance(snapshot,dict):
        raise ValueError("Workbook must be an object")
    if len(_json(snapshot).encode())>MAX_SNAPSHOT_BYTES:
        raise ValueError("Workbook exceeds 6MB collaboration limit")
    workbook=snapshot.get("workbook")
    if not isinstance(workbook,dict):
        raise ValueError("Missing workbook document")
    sheets=workbook.get("sheets")
    if not isinstance(sheets,list) or not 1<=len(sheets)<=32:
        raise ValueError("Workbook requires 1-32 sheets")
    seen=set()
    total=0
    for sheet in sheets:
        if not isinstance(sheet,dict):
            raise ValueError("Invalid sheet object")
        name=sheet.get("name")
        if not isinstance(name,str) or not 1<=len(name)<=64 or "!" in name or name in seen:
            raise ValueError("Invalid or duplicate sheet name")
        seen.add(name)
        cells=sheet.get("cells")
        styles=sheet.get("styles",{})
        widths=sheet.get("widths",{})
        if not isinstance(cells,dict) or not isinstance(styles,dict) or not isinstance(widths,dict):
            raise ValueError("Invalid sheet cells/styles/widths")
        total+=len(cells)
        if total>250000:
            raise ValueError("Workbook exceeds 250,000 populated cells")
        for ref,raw in cells.items():
            _reference(ref)
            if not isinstance(raw,str) or len(raw)>10000:
                raise ValueError("Invalid cell value")
        for ref,value in styles.items():
            _reference(ref)
            if not isinstance(value,dict) or len(_json(value))>2000:
                raise ValueError("Invalid cell style")
        if len(widths)>256:
            raise ValueError("Excessive column widths")
    for key,cap in (("rules",200),("charts",100),("pivots",100)):
        values=workbook.get(key,[])
        if not isinstance(values,list) or len(values)>cap:
            raise ValueError("Invalid workbook "+key)
    name=snapshot.get("name","Shared workbook")
    if not isinstance(name,str) or len(name)>120:
        raise ValueError("Invalid workbook title")
    return snapshot


class RoomRequest(BaseModel):
    snapshot: dict


def create_app(db_path: Path, *, origins: list[str] | None = None,
               admin_token: str | None = None) -> FastAPI:
    origins=origins or ["http://127.0.0.1:8765","http://localhost:8765"]
    if not origins or any(not ORIGIN_RE.fullmatch(o) for o in origins):
        raise ValueError("Use an explicit trusted http(s) Origin, not a wildcard")
    admin_token=admin_token or _token()
    db_path=Path(db_path).expanduser()
    db_path.parent.mkdir(parents=True,exist_ok=True)
    db=sqlite3.connect(str(db_path), check_same_thread=False, isolation_level=None)
    db.row_factory=sqlite3.Row
    db.execute("PRAGMA journal_mode=WAL")
    db.execute("PRAGMA busy_timeout=5000")
    db.executescript("""
    CREATE TABLE IF NOT EXISTS rooms (
      room TEXT PRIMARY KEY, revision INTEGER NOT NULL,
      snapshot TEXT NOT NULL, created_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS grants (
      room TEXT NOT NULL, token_hash TEXT NOT NULL, role TEXT NOT NULL,
      PRIMARY KEY (room,token_hash)
    );
    CREATE TABLE IF NOT EXISTS cell_revisions (
      room TEXT NOT NULL, sheet TEXT NOT NULL, ref TEXT NOT NULL,
      field TEXT NOT NULL, revision INTEGER NOT NULL,
      PRIMARY KEY (room,sheet,ref,field)
    );
    CREATE TABLE IF NOT EXISTS events (
      room TEXT NOT NULL, revision INTEGER NOT NULL,
      client TEXT NOT NULL, kind TEXT NOT NULL,
      payload TEXT NOT NULL, time_ms INTEGER NOT NULL,
      PRIMARY KEY (room,revision)
    );
    CREATE TABLE IF NOT EXISTS versions (
      room TEXT NOT NULL, revision INTEGER NOT NULL,
      snapshot TEXT NOT NULL, time_ms INTEGER NOT NULL,
      PRIMARY KEY (room,revision)
    );
    """)
    app=FastAPI(title="Arcside Sheets local collaboration",version="0.1",
                docs_url=None,redoc_url=None,openapi_url=None)
    app.add_middleware(CORSMiddleware,allow_origins=origins,allow_methods=["GET","POST","OPTIONS"],
                       allow_headers=["authorization","content-type"])
    app.state.admin_token=admin_token
    app.state.db=db
    guard=asyncio.Lock()
    members:dict[str,dict[WebSocket,dict]]=defaultdict(dict)

    def trusted(headers)->None:
        origin=headers.get("origin")
        if origin is not None and origin not in origins:
            raise HTTPException(403,"Browser Origin not permitted")
        if not HOST_RE.fullmatch(headers.get("host","")):
            raise HTTPException(403,"Loopback Host required")

    def role(room:str,token:str)->str|None:
        if not ROOM_RE.fullmatch(room) or not isinstance(token,str) or not token or len(token)>512 or not token.isascii():
            return None
        provided=_hash(token)
        rows=db.execute("SELECT token_hash,role FROM grants WHERE room=?",(room,)).fetchall()
        for row in rows:
            if hmac.compare_digest(row["token_hash"],provided):
                return row["role"]
        return None

    def require(request:Request,room:str,minimum:str="viewer")->str:
        trusted(request.headers)
        authorization=request.headers.get("authorization","")
        grant=role(room,authorization[7:] if authorization.startswith("Bearer ") else "")
        if grant is None:
            raise HTTPException(401,"Invalid room access key")
        if minimum=="editor" and grant=="viewer":
            raise HTTPException(403,"Viewer cannot modify the workbook")
        return grant

    def room_state(room:str)->dict:
        row=db.execute("SELECT revision,snapshot FROM rooms WHERE room=?",(room,)).fetchone()
        if row is None:raise HTTPException(404,"Room not found")
        return {"revision":row["revision"],"snapshot":json.loads(row["snapshot"])}

    @app.middleware("http")
    async def private_responses(request:Request,call_next):
        response=await call_next(request)
        if request.url.path.startswith("/api/"):
            response.headers["Cache-Control"]="no-store"
            response.headers["X-Content-Type-Options"]="nosniff"
            response.headers["Referrer-Policy"]="no-referrer"
        return response

    @app.get("/health")
    def health()->dict:
        return {"service":"arcside-collab","ready":True}

    @app.post("/api/rooms")
    async def create_room(request:Request,body:RoomRequest)->dict:
        trusted(request.headers)
        credential=request.headers.get("authorization","")
        if not credential.startswith("Bearer ") or not credential[7:].isascii() or len(credential[7:])>512 or not hmac.compare_digest(credential[7:],admin_token):
            raise HTTPException(401,"Room creation key required")
        try:
            snapshot=_workbook(body.snapshot)
        except (ValueError,TypeError) as error:
            raise HTTPException(400,str(error)) from None
        room=secrets.token_hex(12)
        owner,editor,viewer=_token(),_token(),_token()
        async with guard:
            db.execute("BEGIN IMMEDIATE")
            try:
                db.execute("INSERT INTO rooms VALUES (?,?,?,?)",(room,0,_json(snapshot),int(time.time())))
                db.execute("INSERT INTO versions VALUES (?,?,?,?)",
                           (room,0,_json(snapshot),int(time.time()*1000)))
                db.executemany("INSERT INTO grants VALUES (?,?,?)",[
                    (room,_hash(owner),"owner"),(room,_hash(editor),"editor"),
                    (room,_hash(viewer),"viewer")])
                db.execute("COMMIT")
            except Exception:
                db.execute("ROLLBACK")
                raise
        return {"room":room,"revision":0,"owner_key":owner,"editor_key":editor,"viewer_key":viewer}

    @app.get("/api/rooms/{room}")
    def get_room(request:Request,room:str)->dict:
        grant=require(request,room)
        return {**room_state(room),"role":grant}

    @app.get("/api/rooms/{room}/history")
    def room_history(request:Request,room:str)->dict:
        require(request,room)
        history=db.execute(
            "SELECT revision,client,kind,time_ms FROM events WHERE room=? "
            "ORDER BY revision DESC LIMIT ?",(room,MAX_EVENT_ROWS)).fetchall()
        return {"events":[dict(row) for row in history]}

    @app.get("/api/rooms/{room}/versions/{revision}")
    def workbook_version(request:Request,room:str,revision:int)->dict:
        require(request,room)
        if revision<0:raise HTTPException(400,"Invalid revision")
        old=db.execute("SELECT snapshot,time_ms FROM versions WHERE room=? AND revision=?",
                       (room,revision)).fetchone()
        if old is None:raise HTTPException(404,"Snapshot version unavailable")
        return {"revision":revision,"snapshot":json.loads(old["snapshot"]),
                "time_ms":old["time_ms"]}

    async def announce(room:str,event:dict,*,exclude:WebSocket|None=None)->None:
        dead=[]
        for ws in list(members.get(room,{})):
            if ws is exclude:continue
            try:await ws.send_json(event)
            except Exception:dead.append(ws)
        for ws in dead:members[room].pop(ws,None)

    async def presence(room:str)->None:
        await announce(room,{"type":"presence","participants":[
            {"id":value["id"],"name":value["name"],"role":value["role"]}
            for value in members[room].values()]})

    def apply_patch(room:str,client:str,payload:dict)->dict:
        changes=payload.get("changes")
        if not isinstance(changes,list) or not 1<=len(changes)<=MAX_CELL_OPS:
            raise ValueError("Patch requires 1-1200 changes")
        base=payload.get("base")
        if not isinstance(base,int) or base<0:raise ValueError("Missing revision base")
        current=room_state(room)
        if base>current["revision"]:raise ValueError("Future base revision")
        data=current["snapshot"]
        by_name={sheet["name"]:sheet for sheet in data["workbook"]["sheets"]}
        validated=[]
        seen=set()
        for change in changes:
            if not isinstance(change,dict):raise ValueError("Invalid patch")
            sheet=change.get("sheet")
            if sheet not in by_name:raise ValueError("Unknown sheet")
            ref=_reference(change.get("ref"))
            field=change.get("field")
            if field not in ("raw","style"):
                raise ValueError("Only cell value and style patches are supported")
            if (sheet,ref,field) in seen:
                raise ValueError("Duplicate patch key")
            seen.add((sheet,ref,field))
            value=change.get("value")
            if field=="raw":
                if not isinstance(value,str) or len(value)>10000:
                    raise ValueError("Invalid cell text")
            elif value is not None and (not isinstance(value,dict) or len(_json(value))>2000):
                raise ValueError("Invalid style object")
            stamp=db.execute(
                "SELECT revision FROM cell_revisions "
                "WHERE room=? AND sheet=? AND ref=? AND field=?",
                (room,sheet,ref,field)).fetchone()
            if stamp and stamp["revision"]>base:
                return {"type":"conflict","revision":current["revision"],
                        "message":"Another editor changed the same cell; your changes were not saved.",
                        "keys":[{"sheet":sheet,"ref":ref,"field":field}],"snapshot":data}
            validated.append((sheet,ref,field,value))
        for sheet,ref,field,value in validated:
            target=by_name[sheet]["cells" if field=="raw" else "styles"]
            if field=="raw":
                if value:target[ref]=value
                else:target.pop(ref,None)
            elif value is None:target.pop(ref,None)
            else:target[ref]=value
        _workbook(data)
        revision=current["revision"]+1
        for sheet,ref,field,_ in validated:
            db.execute("INSERT INTO cell_revisions VALUES (?,?,?,?,?) "
                       "ON CONFLICT(room,sheet,ref,field) DO UPDATE SET revision=excluded.revision",
                       (room,sheet,ref,field,revision))
        return persist(room,revision,data,client,"patch",{"changes":changes})

    def persist(room:str,revision:int,data:dict,client:str,kind:str,payload:dict)->dict:
        event={"type":"event","kind":kind,"revision":revision,
               "client":client,**payload}
        db.execute("UPDATE rooms SET revision=?,snapshot=? WHERE room=?",
                   (revision,_json(data),room))
        db.execute("INSERT INTO events VALUES (?,?,?,?,?,?)",
                   (room,revision,client,kind,_json(payload),int(time.time()*1000)))
        db.execute("INSERT INTO versions VALUES (?,?,?,?)",
                   (room,revision,_json(data),int(time.time()*1000)))
        # Bound disk usage for workbooks with frequent edits; keep the latest
        # 200 revisions (plus their event metadata) per room.
        cutoff=max(0,revision-199)
        db.execute("DELETE FROM versions WHERE room=? AND revision<?",(room,cutoff))
        db.execute("DELETE FROM events WHERE room=? AND revision<?",(room,cutoff))
        return event

    def apply_replace(room:str,client:str,payload:dict)->dict:
        base=payload.get("base")
        if not isinstance(base,int):raise ValueError("Missing revision base")
        current=room_state(room)
        if base!=current["revision"]:
            return {"type":"conflict","revision":current["revision"],
                    "message":"Workbook structure changed; download a backup of local edits before refreshing.",
                    "snapshot":current["snapshot"]}
        data=_workbook(payload.get("snapshot"))
        revision=base+1
        # A structural replacement must invalidate all prior per-cell revision
        # assumptions so a stale peer cannot overwrite the new sheet layout.
        db.execute("DELETE FROM cell_revisions WHERE room=?",(room,))
        for sheet in data["workbook"]["sheets"]:
            for ref in sheet["cells"]:
                db.execute("INSERT INTO cell_revisions VALUES (?,?,?,?,?)",
                           (room,sheet["name"],ref,"raw",revision))
            for ref in sheet.get("styles",{}):
                db.execute("INSERT INTO cell_revisions VALUES (?,?,?,?,?)",
                           (room,sheet["name"],ref,"style",revision))
        return persist(room,revision,data,client,"replace",{"snapshot":data})

    @app.websocket("/ws/rooms/{room}")
    async def join(ws:WebSocket,room:str)->None:
        try:
            trusted(ws.headers)
        except HTTPException:
            await ws.close(code=1008,reason="Untrusted Origin or Host")
            return
        if not ROOM_RE.fullmatch(room):
            await ws.close(code=1008,reason="Invalid room")
            return
        await ws.accept()
        try:
            hello=await asyncio.wait_for(ws.receive_json(),timeout=8)
            if not isinstance(hello,dict) or hello.get("type")!="authenticate":
                raise ValueError("Authentication required")
            grant=role(room,hello.get("key",""))
            if grant is None:
                await ws.close(code=1008,reason="Invalid room key")
                return
            cid=secrets.token_hex(6)
            username=str(hello.get("name","Guest")).strip()[:48] or "Guest"
            async with guard:
                members[room][ws]={"id":cid,"role":grant,"name":username}
                state=room_state(room)
                await ws.send_json({"type":"welcome","client":cid,"role":grant,
                                    **state})
                await presence(room)
            while True:
                payload=await ws.receive_json()
                if not isinstance(payload,dict) or len(_json(payload).encode())>MAX_PATCH_BYTES:
                    await ws.send_json({"type":"error","message":"Invalid or oversized message"})
                    continue
                kind=payload.get("type")
                if kind=="cursor":
                    sheet=str(payload.get("sheet",""))[:64]
                    ref=str(payload.get("ref",""))[:12]
                    if CELL_RE.fullmatch(ref):
                        await announce(room,{"type":"cursor","client":cid,"name":username,
                                             "sheet":sheet,"ref":ref},exclude=ws)
                    continue
                if kind not in ("patch","replace","restore"):
                    await ws.send_json({"type":"error","message":"Unknown event type"})
                    continue
                if grant=="viewer":
                    await ws.send_json({"type":"error","message":"Read-only room access"})
                    continue
                if kind=="restore" and grant!="owner":
                    await ws.send_json({"type":"error","message":"Only room owner may restore revisions"})
                    continue
                async with guard:
                    db.execute("BEGIN IMMEDIATE")
                    try:
                        if kind=="patch":
                            result=apply_patch(room,cid,payload)
                        elif kind=="replace":
                            result=apply_replace(room,cid,payload)
                        else:
                            target=payload.get("target")
                            if not isinstance(target,int) or target<0:
                                raise ValueError("Invalid restore target")
                            saved=db.execute(
                                "SELECT snapshot FROM versions WHERE room=? AND revision=?",
                                (room,target)).fetchone()
                            if saved is None:raise ValueError("Requested version unavailable")
                            result=apply_replace(room,cid,{
                                "base":payload.get("base"),
                                "snapshot":json.loads(saved["snapshot"]),
                            })
                        db.execute("COMMIT")
                    except (ValueError,TypeError,sqlite3.Error) as error:
                        db.execute("ROLLBACK")
                        await ws.send_json({"type":"error","message":str(error)[:300]})
                        continue
                    except Exception:
                        db.execute("ROLLBACK")
                        raise
                    if result["type"]=="conflict":
                        await ws.send_json(result)
                    else:
                        # Client applies the ACK locally and receives all later remote events.
                        await ws.send_json({"type":"ack","id":str(payload.get("id",""))[:80],
                                            "revision":result["revision"]})
                        await announce(room,result,exclude=ws)
        except (WebSocketDisconnect,asyncio.TimeoutError,ValueError):
            pass
        finally:
            members[room].pop(ws,None)
            await presence(room)
            try:await ws.close()
            except Exception:pass

    @app.on_event("shutdown")
    def shutdown()->None:
        db.close()
    return app
