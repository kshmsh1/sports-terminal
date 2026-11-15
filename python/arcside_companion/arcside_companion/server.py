"""Opt-in authenticated local companion: code execution is only for trusted owners.

Not a public execution API. Bind loopback, require 256-bit bearer token and
explicit browser Origin, confine file-management routes to a chosen workspace.
Any executed Python, shell, package install, debugpy or Git operation has the
OS permissions of the user who launched this companion.
"""
from __future__ import annotations

import asyncio
import hashlib
import importlib.util
import os
import re
import shutil
import sys
import uuid
from pathlib import Path
from typing import Literal

from fastapi import Depends, FastAPI, HTTPException, Request, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from .processes import command, interpreter_for, run_env, terminate
from .protocol import framed_bridge, notebook, terminal
from .security import Security


class FileSync(BaseModel):
    files: dict[str, str]
    expected: dict[str, str] = Field(default_factory=dict)
    force: bool = False


class ReadRequest(BaseModel):
    path: str


class Execution(BaseModel):
    entry: str = "main.py"
    source: str | None = None
    mode: Literal["run", "selection", "test", "coverage", "profile"] = "run"
    timeout: int = Field(default=90, ge=1, le=300)
    job_id: str = Field(default_factory=lambda: uuid.uuid4().hex)


class EnvironmentRequest(BaseModel):
    name: str = "default"
    manager: Literal["venv", "uv", "conda"] = "venv"


class InstallRequest(BaseModel):
    packages: list[str] = Field(min_length=1, max_length=24)


class GitRequest(BaseModel):
    action: Literal["status", "init", "diff", "log", "branches", "add", "commit"]
    paths: list[str] = Field(default_factory=list, max_length=100)
    message: str = ""


class FileRequest(BaseModel):
    path: str
    action: Literal["format", "lint"] = "format"


class InterruptRequest(BaseModel):
    job_id: str


def create_app(root: Path, origins: list[str] | None = None, token: str | None = None) -> FastAPI:
    origins = origins or ["http://127.0.0.1:8765", "http://localhost:8765"]
    security = Security(root, origins, token)
    app = FastAPI(title="Arcside trusted local Python companion",
                  description="Loopback-only. Run trusted workspaces, never exposed to untrusted clients.",
                  version="0.2.0", docs_url=None, redoc_url=None, openapi_url=None)
    app.state.security = security
    app.state.environment = "default"
    app.state.jobs = {}
    app.state.semaphore = asyncio.Semaphore(3)
    app.add_middleware(CORSMiddleware, allow_origins=list(security.origins),
                       allow_credentials=False, allow_methods=["GET", "POST", "OPTIONS"],
                       allow_headers=["authorization", "content-type"])

    def authorize(request: Request):
        security.check_http(request)

    def selected_python() -> Path:
        try:
            return interpreter_for(security.root, app.state.environment)
        except (ValueError, FileNotFoundError) as exc:
            raise HTTPException(400, str(exc)) from None

    def validate_file(path: str) -> Path:
        file = security.file(path)
        if file.relative_to(security.root).parts[0] in {".git", ".arcside"}:
            raise HTTPException(403, "Reserved project directory")
        return file

    async def run_job(args: list[str], timeout: int = 90, job_id: str | None = None):
        # A single browser owner can still accidentally exhaust their machine.
        # Cap simultaneous commands and support explicit interrupt via process ID.
        async with app.state.semaphore:
            from .processes import command
            def remember(proc):
                if job_id:
                    app.state.jobs[job_id] = proc
            try:
                return await command(args, security.root, timeout, env=run_env(security.root, selected_python()),
                                     on_start=remember)
            finally:
                if job_id:
                    app.state.jobs.pop(job_id, None)

    @app.get("/health")
    async def health() -> dict:
        # No filesystem or credential information available without a token.
        return {"ready": True, "service": "arcside-companion"}

    @app.get("/api/status", dependencies=[Depends(authorize)])
    async def status() -> dict:
        interpreter = selected_python()
        return {
            "workspace": str(security.root),
            "environment": app.state.environment,
            "interpreter": str(interpreter),
            "python": sys.version.split()[0],
            "capabilities": {
                "terminal": os.name == "posix",
                "environments": ["venv", *(["uv"] if shutil.which("uv") else []),
                                 *(["conda"] if shutil.which("conda") else [])],
                "lsp": bool(importlib.util.find_spec("pylsp")),
                "dap": bool(importlib.util.find_spec("debugpy")),
                "notebook": bool(importlib.util.find_spec("jupyter_client")),
                "git": shutil.which("git") is not None,
                "formatter": bool(importlib.util.find_spec("ruff") or importlib.util.find_spec("black")),
            },
        }

    @app.post("/api/sync", dependencies=[Depends(authorize)])
    async def sync(body: FileSync) -> dict:
        if len(body.files) > 1000:
            raise HTTPException(413, "Too many project files")
        if sum(len(source.encode("utf-8")) for source in body.files.values()) > 8_000_000:
            raise HTTPException(413, "Project exceeds 8 MB sync quota")
        # Validate all paths first; avoid partially writing malformed projects.
        entries = []
        conflicts = []
        for name, source in body.files.items():
            if len(source) > 700_000:
                raise HTTPException(413, f"File too large: {name}")
            path = validate_file(name)
            content = source.encode("utf-8")
            digest = hashlib.sha256(content).hexdigest()
            if path.exists():
                if not path.is_file():
                    raise HTTPException(409, f"Not a regular file: {name}")
                old = path.read_bytes()
                old_hash = hashlib.sha256(old).hexdigest()
                expected_hash = body.expected.get(name)
                # Never silently overwrite a pre-existing local file. After
                # first sync, updates require optimistic concurrency checks.
                if old != content and not body.force and expected_hash != old_hash:
                    conflicts.append(name)
            entries.append((name, path, content, digest))
        if conflicts:
            raise HTTPException(409, "Local files changed or pre-exist: "+
                                ", ".join(conflicts[:20])+
                                ". Import them first; do not overwrite blindly.")
        for _, path, content, _ in entries:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        return {"written": len(entries), "hashes": {name:digest for name,_,_,digest in entries}}

    @app.post("/api/read", dependencies=[Depends(authorize)])
    async def read_file(body: ReadRequest) -> dict:
        path = validate_file(body.path)
        if not path.is_file():
            raise HTTPException(404, "File not found")
        raw = path.read_bytes()
        if len(raw) > 700_000:
            raise HTTPException(413, "File exceeds 700 kB editor limit")
        try:
            source = raw.decode("utf-8")
        except UnicodeDecodeError:
            raise HTTPException(415, "Binary files cannot be opened as text") from None
        return {"path": body.path, "source": source, "sha256": hashlib.sha256(raw).hexdigest()}

    @app.get("/api/files", dependencies=[Depends(authorize)])
    async def files() -> dict:
        found = []
        for p in security.root.rglob("*"):
            if len(found) >= 1000:
                break
            if any(part in {".git", ".arcside", "__pycache__", "node_modules", ".venv"} for part in p.relative_to(security.root).parts):
                continue
            if p.resolve().is_relative_to(security.root) and p.is_file() and p.stat().st_size < 700_000:
                found.append(str(p.relative_to(security.root)).replace(os.sep, "/"))
        return {"files": sorted(found)}

    @app.post("/api/run", dependencies=[Depends(authorize)])
    async def execute(body: Execution) -> dict:
        if not re.fullmatch(r"[a-f0-9]{32}", body.job_id):
            raise HTTPException(400, "Invalid job identifier")
        python = selected_python()
        if body.mode == "test":
            if importlib.util.find_spec("pytest"):
                args = [str(python), "-m", "pytest", "-q"]
            else:
                args = [str(python), "-m", "unittest", "discover", "-v"]
        elif body.mode == "coverage":
            args = [str(python), "-m", "coverage", "run", "-m", "pytest", "-q"]
        elif body.mode == "profile":
            entry = validate_file(body.entry)
            if not entry.is_file():
                raise HTTPException(404, "Entry source has not been synced")
            # Isolated interpreter startup prevents a project file named
            # profile.py from shadowing the stdlib module used by cProfile.
            profiler_code = (
                "import cProfile, runpy, sys, os\n"
                "target = os.path.abspath(sys.argv[1])\n"
                "sys.path.insert(0, os.path.dirname(target))\n"
                "profiler = cProfile.Profile()\n"
                "try:\n"
                "    profiler.runcall(runpy.run_path, target, run_name='__main__')\n"
                "finally:\n"
                "    profiler.print_stats('cumulative')\n"
            )
            args = [str(python), "-I", "-c", profiler_code, str(entry)]
        elif body.mode == "selection":
            if not body.source or len(body.source) > 150_000:
                raise HTTPException(400, "Selection is empty or too large")
            args = [str(python), "-c", body.source]
        else:
            entry = validate_file(body.entry)
            if not entry.is_file():
                raise HTTPException(404, "Entry source has not been synced")
            args = [str(python), str(entry)]
        result = await run_job(args, body.timeout, body.job_id)
        if body.mode == "coverage" and not result.get("timed_out"):
            report = await run_job([str(python), "-m", "coverage", "report", "-m"], 30)
            result["stdout"] += "\n" + report.get("stdout", "")
            result["stderr"] += report.get("stderr", "")
        return {"job_id": body.job_id, **result}

    @app.post("/api/interrupt", dependencies=[Depends(authorize)])
    async def interrupt(body: InterruptRequest) -> dict:
        proc = app.state.jobs.get(body.job_id)
        if not proc:
            return {"interrupted": False}
        await terminate(proc)
        return {"interrupted": True}

    @app.get("/api/env", dependencies=[Depends(authorize)])
    async def environments() -> dict:
        folder = security.root / ".arcside" / "envs"
        names = [p.name for p in folder.iterdir() if p.is_dir()] if folder.is_dir() else []
        return {"active": app.state.environment, "names": sorted(["system", *names]),
                "interpreter": str(selected_python())}

    @app.post("/api/env/create", dependencies=[Depends(authorize)])
    async def create_environment(body: EnvironmentRequest) -> dict:
        if not re.fullmatch(r"[A-Za-z][\w-]{0,31}", body.name):
            raise HTTPException(400, "Environment name must use letters, digits, _ or -")
        folder = security.root / ".arcside" / "envs" / body.name
        if folder.exists():
            raise HTTPException(409, "Environment already exists")
        folder.parent.mkdir(parents=True, exist_ok=True)
        if body.manager == "venv":
            args = [sys.executable, "-m", "venv", str(folder)]
        elif body.manager == "uv":
            if not shutil.which("uv"):
                raise HTTPException(400, "Install uv first")
            args = ["uv", "venv", str(folder)]
        else:
            if not shutil.which("conda"):
                raise HTTPException(400, "Install conda first")
            args = ["conda", "create", "-y", "-p", str(folder), "python"]
        result = await run_job(args, 240)
        if result["returncode"] == 0:
            app.state.environment = body.name
        return {**result, "active": app.state.environment}

    @app.post("/api/env/select", dependencies=[Depends(authorize)])
    async def choose_environment(body: EnvironmentRequest) -> dict:
        if body.name != "system":
            try:
                interpreter_for(security.root, body.name)
            except (ValueError, FileNotFoundError) as exc:
                raise HTTPException(404, str(exc)) from None
        app.state.environment = body.name
        return {"active": body.name, "interpreter": str(selected_python())}

    @app.post("/api/env/install", dependencies=[Depends(authorize)])
    async def install(body: InstallRequest) -> dict:
        for package in body.packages:
            if len(package) > 120 or not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.+~<>=!,-]*", package):
                raise HTTPException(400, "Package names and simple version specifiers only")
        python = selected_python()
        return await run_job([str(python), "-m", "pip", "install", *body.packages], 240)

    @app.post("/api/tool", dependencies=[Depends(authorize)])
    async def tool(body: FileRequest) -> dict:
        path = validate_file(body.path)
        if not path.is_file() or path.suffix != ".py":
            raise HTTPException(404, "Python file not found")
        python = selected_python()
        if body.action == "lint":
            args = [str(python), "-m", "ruff", "check", str(path)]
        else:
            args = [str(python), "-m", "ruff", "format", str(path)]
        result = await run_job(args, 90)
        if body.action == "format" and result["returncode"] == 0:
            result["source"] = path.read_text(encoding="utf-8")
        return result

    @app.post("/api/git", dependencies=[Depends(authorize)])
    async def git(body: GitRequest) -> dict:
        if not shutil.which("git"):
            raise HTTPException(400, "Git is not installed")
        args = ["git"]
        if body.action == "status":
            args += ["status", "--short", "--branch"]
        elif body.action == "init":
            args += ["init"]
        elif body.action == "diff":
            args += ["diff", "--"]
        elif body.action == "log":
            args += ["log", "--oneline", "--decorate", "-n", "20"]
        elif body.action == "branches":
            args += ["branch", "--list", "-vv"]
        elif body.action == "add":
            if not body.paths:
                raise HTTPException(400, "Select files to stage")
            # Paths are relative to the selected workspace, not host files.
            for file in body.paths:
                validate_file(file)
            args += ["add", "--", *body.paths]
        elif body.action == "commit":
            if not body.message or len(body.message) > 1000:
                raise HTTPException(400, "Commit message required")
            args += ["commit", "-m", body.message]
        return await run_job(args, 45)

    @app.websocket("/ws/terminal")
    async def terminal_socket(ws: WebSocket):
        if await security.check_ws(ws):
            await terminal(ws, security.root, selected_python())

    @app.websocket("/ws/lsp")
    async def lsp_socket(ws: WebSocket):
        if not await security.check_ws(ws):
            return
        python = selected_python()
        await framed_bridge(ws, [str(python), "-m", "pylsp"], security.root,
                            run_env(security.root, python))

    @app.websocket("/ws/dap")
    async def dap_socket(ws: WebSocket):
        if not await security.check_ws(ws):
            return
        python = selected_python()
        await framed_bridge(ws, [str(python), "-m", "debugpy.adapter"], security.root,
                            run_env(security.root, python), enforce_launch_scope=True)

    @app.websocket("/ws/notebook")
    async def notebook_socket(ws: WebSocket):
        if await security.check_ws(ws):
            await notebook(ws, security.root, selected_python())

    return app
