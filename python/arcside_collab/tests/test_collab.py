from __future__ import annotations
import pytest
from fastapi.testclient import TestClient
from arcside_collab.server import create_app

ORIGIN="http://127.0.0.1:8765"
HOST="127.0.0.1:8767"
ADMIN="test-administrator-only"
HEADERS={"Host":HOST,"Origin":ORIGIN}
def auth(token):
    return {**HEADERS,"Authorization":"Bearer "+token}
def sample():
    return {
        "name":"Shared workbook",
        "workbook":{
            "version":1,"active":"Analysis",
            "sheets":[{"name":"Analysis","cells":{"A1":"Name","B1":"Value","A2":"Alpha","B2":"10"},
                      "styles":{},"widths":{}}],
            "rules":[],"charts":[],"pivots":[],
        },
    }

@pytest.fixture
def server(tmp_path):
    with TestClient(create_app(tmp_path/"rooms.sqlite",origins=[ORIGIN],admin_token=ADMIN),
                    base_url="http://127.0.0.1:8767") as client:
        yield client

@pytest.fixture
def room(server):
    result=server.post("/api/rooms",json={"snapshot":sample()},headers=auth(ADMIN))
    assert result.status_code==200,result.text
    return result.json()

def join(server,room,key,name="Editor"):
    ws=server.websocket_connect("/ws/rooms/"+room,headers=HEADERS)
    return ws

def login(ws,key,name="Editor"):
    ws.send_json({"type":"authenticate","key":key,"name":name})
    message=ws.receive_json()
    assert message["type"]=="welcome"
    assert ws.receive_json()["type"]=="presence"
    return message

def test_create_room_requires_admin_and_explicit_origin(server):
    assert server.get("/health").json()["ready"]
    assert server.post("/api/rooms",headers=auth("wrong"),json={"snapshot":sample()}).status_code==401
    assert server.post("/api/rooms",headers={**auth(ADMIN),"Origin":"http://evil.invalid"},
                       json={"snapshot":sample()}).status_code==403
    assert server.post("/api/rooms",headers={**auth(ADMIN),"Host":"evil.invalid:8767"},
                       json={"snapshot":sample()}).status_code==403

def test_invalid_workbooks_rejected(server):
    invalid=sample()
    invalid["workbook"]["sheets"][0]["cells"]["A100001"]="too far"
    response=server.post("/api/rooms",json={"snapshot":invalid},headers=auth(ADMIN))
    assert response.status_code==400
    invalid=sample()
    invalid["workbook"]["sheets"].append(invalid["workbook"]["sheets"][0])
    assert server.post("/api/rooms",json={"snapshot":invalid},headers=auth(ADMIN)).status_code==400

def test_room_access_levels_and_no_token_in_rest_metadata(server,room):
    rid=room["room"]
    for role in ("owner","editor","viewer"):
        res=server.get("/api/rooms/"+rid,headers=auth(room[f"{role}_key"]))
        assert res.status_code==200
        assert res.json()["role"]==role
        assert res.json()["snapshot"]["workbook"]["sheets"][0]["cells"]["B2"]=="10"
        assert all(key not in res.text for key in (room["owner_key"],room["editor_key"],room["viewer_key"]))
    assert server.get("/api/rooms/"+rid).status_code==401
    assert server.get("/api/rooms/"+rid,headers=auth("wrong")).status_code==401
    assert server.get("/api/rooms/"+"z"*24,headers=auth(room["owner_key"])).status_code==401

def test_concurrent_distinct_cell_patches_merge_without_overwrite(server,room):
    rid=room["room"]
    with join(server,rid,room["owner_key"]) as owner:
        assert login(owner,room["owner_key"],"Owner")["role"]=="owner"
        with join(server,rid,room["editor_key"]) as peer:
            assert login(peer,room["editor_key"],"Peer")["role"]=="editor"
            assert owner.receive_json()["type"]=="presence"
            owner.send_json({"type":"patch","id":"owner-a3","base":0,"changes":[
                {"sheet":"Analysis","ref":"A3","field":"raw","value":"Beta"}]})
            assert owner.receive_json()["revision"]==1
            event=peer.receive_json()
            assert event["type"]=="event" and event["revision"]==1
            peer.send_json({"type":"patch","id":"peer-b3","base":0,"changes":[
                {"sheet":"Analysis","ref":"B3","field":"raw","value":"20"}]})
            assert peer.receive_json()["type"]=="ack"
            assert owner.receive_json()["type"]=="event"
    result=server.get("/api/rooms/"+rid,headers=auth(room["owner_key"]))
    assert result.json()["revision"]==2
    cells=result.json()["snapshot"]["workbook"]["sheets"][0]["cells"]
    assert cells["A3"]=="Beta" and cells["B3"]=="20"
    history=server.get("/api/rooms/"+rid+"/history",headers=auth(room["viewer_key"]))
    assert [x["kind"] for x in history.json()["events"]]==["patch","patch"]

def test_same_cell_stale_write_conflicts_and_preserves_remote(server,room):
    rid=room["room"]
    with join(server,rid,room["owner_key"]) as first:
        login(first,room["owner_key"])
        first.send_json({"type":"patch","id":"1","base":0,"changes":[
            {"sheet":"Analysis","ref":"B2","field":"raw","value":"21"}]})
        assert first.receive_json()["type"]=="ack"
    with join(server,rid,room["editor_key"]) as other:
        login(other,room["editor_key"])
        other.send_json({"type":"patch","id":"stale","base":0,"changes":[
            {"sheet":"Analysis","ref":"B2","field":"raw","value":"999"}]})
        conflict=other.receive_json()
        assert conflict["type"]=="conflict" and conflict["revision"]==1
        assert conflict["snapshot"]["workbook"]["sheets"][0]["cells"]["B2"]=="21"
    state=server.get("/api/rooms/"+rid,headers=auth(room["owner_key"])).json()
    assert state["revision"]==1

def test_viewer_socket_cannot_modify_any_cells(server,room):
    rid=room["room"]
    with join(server,rid,room["viewer_key"]) as ws:
        assert login(ws,room["viewer_key"])["role"]=="viewer"
        ws.send_json({"type":"patch","id":"no","base":0,"changes":[
            {"sheet":"Analysis","ref":"B2","field":"raw","value":"HACK"}]})
        assert ws.receive_json()["type"]=="error"
    assert server.get("/api/rooms/"+rid,headers=auth(room["owner_key"])).json()["revision"]==0

def test_structural_cas_and_room_persistence(tmp_path):
    db=tmp_path/"persist.sqlite"
    app=create_app(db,origins=[ORIGIN],admin_token=ADMIN)
    with TestClient(app,base_url="http://127.0.0.1:8767") as server:
        keys=server.post("/api/rooms",headers=auth(ADMIN),json={"snapshot":sample()}).json()
        document=sample()
        document["workbook"]["sheets"].append({
            "name":"Second","cells":{"A1":"New"},"styles":{},"widths":{}})
        with join(server,keys["room"],keys["owner_key"]) as ws:
            login(ws,keys["owner_key"])
            ws.send_json({"type":"replace","id":"restructure","base":0,"snapshot":document})
            assert ws.receive_json()["type"]=="ack"
            ws.send_json({"type":"replace","id":"stale","base":0,"snapshot":sample()})
            assert ws.receive_json()["type"]=="conflict"
    with TestClient(create_app(db,origins=[ORIGIN],admin_token=ADMIN),
                    base_url="http://127.0.0.1:8767") as server:
        restored=server.get("/api/rooms/"+keys["room"],headers=auth(keys["viewer_key"])).json()
        assert restored["revision"]==1
        assert len(restored["snapshot"]["workbook"]["sheets"])==2

def test_reject_duplicate_patch_keys_and_overlong_value(server,room):
    rid=room["room"]
    with join(server,rid,room["owner_key"]) as ws:
        login(ws,room["owner_key"])
        change={"sheet":"Analysis","ref":"B2","field":"raw","value":"x"}
        ws.send_json({"type":"patch","id":"dupes","base":0,"changes":[change,change]})
        assert ws.receive_json()["type"]=="error"
        ws.send_json({"type":"patch","id":"huge","base":0,"changes":[{**change,"value":"x"*10001}]})
        assert ws.receive_json()["type"]=="error"
    assert server.get("/api/rooms/"+rid,headers=auth(room["owner_key"])).json()["revision"]==0


def test_version_history_authentication_and_owner_only_restore(server,room):
    rid=room["room"]
    with join(server,rid,room["editor_key"]) as editor:
        login(editor,room["editor_key"])
        editor.send_json({"type":"patch","id":"one","base":0,"changes":[
            {"sheet":"Analysis","ref":"B2","field":"raw","value":"111"}]})
        assert editor.receive_json()["revision"]==1
        editor.send_json({"type":"patch","id":"two","base":1,"changes":[
            {"sheet":"Analysis","ref":"B2","field":"raw","value":"222"}]})
        assert editor.receive_json()["revision"]==2
        editor.send_json({"type":"restore","id":"denied","base":2,"target":0})
        assert editor.receive_json()["type"]=="error"
    for revision,expected in [(0,"10"),(1,"111"),(2,"222")]:
        response=server.get(f"/api/rooms/{rid}/versions/{revision}",
                            headers=auth(room["viewer_key"]))
        assert response.status_code==200
        assert response.json()["snapshot"]["workbook"]["sheets"][0]["cells"]["B2"]==expected
    assert server.get(f"/api/rooms/{rid}/versions/0",headers=auth("bad")).status_code==401
    with join(server,rid,room["owner_key"]) as owner:
        login(owner,room["owner_key"])
        owner.send_json({"type":"restore","id":"undo","base":2,"target":0})
        assert owner.receive_json()["type"]=="ack"
    state=server.get("/api/rooms/"+rid,headers=auth(room["viewer_key"])).json()
    assert state["revision"]==3
    assert state["snapshot"]["workbook"]["sheets"][0]["cells"]["B2"]=="10"
    history=server.get("/api/rooms/"+rid+"/history",headers=auth(room["owner_key"])).json()
    assert len(history["events"])==3
    assert history["events"][0]["kind"]=="replace"
