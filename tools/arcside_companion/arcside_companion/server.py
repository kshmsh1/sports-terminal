"""Arcside trusted local IDE API.

Run explicitly: arcside-companion --workspace /path/to/project
The process binds 127.0.0.1, generates a fresh bearer token, and never
starts automatically when the web application opens.

WARNING: Python programs and PTY shells have the permissions of the local
user. This is a trusted development tool, NOT a multi-tenant code sandbox.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import signal
from pathlib import Path
import shutil
import sys
import tempfile
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException, Request, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from .processes import (available_tools, create_environment, install_packages,
                        interpreter, run_command)
from .protocols import debugger, language_server, terminal
from .security import MAX_FILE, MAX_FILES, MAX_PROJECT, Settings


class SyncPayload(BaseModel):
    files: dict[str, str] = Field(default_factory=dict)


class EntryPayload(BaseModel):
    entry: str = "main.py"
    timeout: int = Field(default=90, ge=1, le=120)
    job_id: str = Field(default="foreground", pattern=r"^[A-Za-z0-9_-]{1,80}$")


class SnippetPayload(BaseModel):
    code: str = Field(max_length=500_000)
    timeout: int = Field(default=60, ge=1, le=120)
    job_id: str = Field(default="foreground", pattern=r"^[A-Za-z0-9_-]{1,80}$")


class CancelPayload(BaseModel):
    job_id: str = Field(pattern=r"^[A-Za-z0-9_-]{1,80}$")


class EnvironmentPayload(BaseModel):
    manager: str = "venv"


class InstallPayload(BaseModel):
    packages: list[str]


def create_app(settings: Settings) -> FastAPI:
    app = FastAPI(title="Arcside local Python companion", version="0.1.0",
                  docs_url=None, redoc_url=None, openapi_url=None)
    active_jobs: dict[str, asyncio.subprocess.Process] = {}
    app.add_middleware(CORSMiddleware, allow_origins=list(settings.origins),
                       allow_credentials=False, allow_methods=["GET", "POST", "OPTIONS"],
                       allow_headers=["X-Arcside-Token", "Content-Type"])

    def authorized(request: Request,
                   x_arcside_token: Annotated[str | None, Header()] = None) -> None:
        if not settings.origin_allowed(request.headers.get("origin")):
            raise HTTPException(403, "Browser origin is not authorized")
        if not settings.authorized(x_arcside_token):
            raise HTTPException(401, "Invalid or missing Arcside token")

    @app.get("/v1/health", dependencies=[Depends(authorized)])
    async def health():
        return {"ok": True, "version": "0.1.0", "workspace": str(settings.workspace),
                "os": os.name, "tools": available_tools(settings.workspace),
                "warning": "Trusted local code has your current user's operating-system permissions"}

    @app.post("/v1/files/sync", dependencies=[Depends(authorized)])
    async def sync(payload: SyncPayload):
        if not 1 <= len(payload.files) <= MAX_FILES:
            raise HTTPException(422, "Project must contain 1-256 files")
        byte_count = sum(len(content.encode("utf-8")) for content in payload.files.values())
        if byte_count > MAX_PROJECT:
            raise HTTPException(413, "Project exceeds 12 MB")
        targets: list[tuple[Path, str]] = []
        for name, content in payload.files.items():
            if len(content.encode("utf-8")) > MAX_FILE:
                raise HTTPException(413, f"{name}: file exceeds 2 MB")
            try:
                targets.append((settings.path(name), content))
            except ValueError as error:
                raise HTTPException(400, str(error)) from error
        for target, content in targets:
            target.parent.mkdir(parents=True, exist_ok=True)
            # Atomic replacement; re-validate after parent creation for symlinks.
            if not target.resolve(strict=False).is_relative_to(settings.workspace):
                raise HTTPException(403, "Target escaped workspace")
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8",
                                             dir=target.parent, delete=False) as handle:
                handle.write(content)
                temp_name = handle.name
            os.replace(temp_name, target)
        return {"ok": True, "files": len(targets), "bytes": byte_count}

    def valid_entry(name: str) -> Path:
        try:
            target = settings.path(name)
        except ValueError as error:
            raise HTTPException(400, str(error)) from error
        if not target.is_file() or target.suffix != ".py":
            raise HTTPException(404, "Python entry file not found")
        return target

    async def tracked(args: list[str], timeout: int, job_id: str):
        if job_id in active_jobs:
            raise HTTPException(409, "A job with that identifier is already running")
        def register(proc: asyncio.subprocess.Process) -> None:
            active_jobs[job_id] = proc
        try:
            return (await run_command(args, settings.workspace, timeout,
                                      on_start=register)).dictionary()
        finally:
            active_jobs.pop(job_id, None)

    @app.post("/v1/run", dependencies=[Depends(authorized)])
    async def run(payload: EntryPayload):
        entry = valid_entry(payload.entry)
        return await tracked([interpreter(settings.workspace), str(entry)],
                             payload.timeout, payload.job_id)

    @app.post("/v1/snippet", dependencies=[Depends(authorized)])
    async def snippet(payload: SnippetPayload):
        return await tracked([interpreter(settings.workspace), "-c", payload.code],
                             payload.timeout, payload.job_id)

    @app.post("/v1/tests", dependencies=[Depends(authorized)])
    async def tests(payload: EntryPayload):
        return await tracked([interpreter(settings.workspace), "-m", "pytest",
                             "-q", "--disable-warnings", "--maxfail=10"],
                             payload.timeout, payload.job_id)

    @app.post("/v1/stop", dependencies=[Depends(authorized)])
    async def stop(payload: CancelPayload):
        proc = active_jobs.get(payload.job_id)
        if proc is None or proc.returncode is not None:
            return {"ok": True, "stopped": False}
        if os.name != "nt":
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        else:
            proc.kill()
        return {"ok": True, "stopped": True}

    @app.get("/v1/environment", dependencies=[Depends(authorized)])
    async def environment():
        executable = interpreter(settings.workspace)
        query = ("import json,sys,platform; "
                 "print(json.dumps({'python':sys.executable,'version':sys.version,"
                 "'platform':platform.platform(),'prefix':sys.prefix}))")
        result = await run_command([executable, "-c", query], settings.workspace, 15)
        return {"interpreter": executable, "details": json.loads(result.stdout)
                if result.returncode == 0 else {"error": result.stderr},
                "tools": available_tools(settings.workspace)}

    @app.post("/v1/environment/create", dependencies=[Depends(authorized)])
    async def env_create(payload: EnvironmentPayload):
        try:
            result = await create_environment(settings.workspace, payload.manager)
        except ValueError as error:
            raise HTTPException(400, str(error)) from error
        return result.dictionary()

    @app.post("/v1/environment/install", dependencies=[Depends(authorized)])
    async def env_install(payload: InstallPayload):
        try:
            result = await install_packages(settings.workspace, payload.packages)
        except ValueError as error:
            raise HTTPException(400, str(error)) from error
        return result.dictionary()

    @app.post("/v1/format", dependencies=[Depends(authorized)])
    async def formatter(payload: EntryPayload):
        target = valid_entry(payload.entry)
        ruff = shutil.which("ruff")
        if not ruff:
            raise HTTPException(501, "Install ruff to enable native formatting")
        result = await run_command([ruff, "format", str(target)], settings.workspace, 45)
        return result.dictionary()

    @app.post("/v1/lint", dependencies=[Depends(authorized)])
    async def lint(payload: EntryPayload):
        target = valid_entry(payload.entry)
        ruff = shutil.which("ruff")
        if not ruff:
            raise HTTPException(501, "Install ruff to enable native linting")
        result = await run_command([ruff, "check", "--output-format", "json", str(target)],
                                   settings.workspace, 45)
        return result.dictionary()

    @app.get("/v1/git/status", dependencies=[Depends(authorized)])
    async def git_status():
        git = shutil.which("git")
        if not git:
            raise HTTPException(501, "Git not installed")
        result = await run_command([git, "status", "--short", "--untracked-files=normal"],
                                   settings.workspace, 15)
        return result.dictionary()

    @app.websocket("/v1/ws/terminal")
    async def ws_terminal(ws: WebSocket):
        await terminal(ws, settings)

    @app.websocket("/v1/ws/lsp")
    async def ws_lsp(ws: WebSocket):
        await language_server(ws, settings)

    @app.websocket("/v1/ws/debug")
    async def ws_debug(ws: WebSocket):
        await debugger(ws, settings)
    return app


def main() -> None:
    parser = argparse.ArgumentParser(description="Arcside trusted local Python companion")
    parser.add_argument("--workspace", default=".", help="Explicit local project directory")
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--allow-origin", action="append", default=[],
                        help="Exact trusted browser origin, e.g. http://localhost:8765")
    args = parser.parse_args()
    settings = Settings.make(args.workspace, origins=args.allow_origin or None,
                             port=args.port)
    print("\nArcside Local Companion — TRUSTED LOCAL CODE ONLY")
    print("Workspace:", settings.workspace)
    print("Bind: http://127.0.0.1:" + str(settings.port))
    print("Allowed browser origins:", ", ".join(settings.origins))
    print("SESSION TOKEN (paste into Arcside, not into source code):", settings.token)
    print("Shells and Python scripts can access files under your OS account. Ctrl+C exits.\n",
          flush=True)
    import uvicorn
    uvicorn.run(create_app(settings), host="127.0.0.1", port=settings.port,
                access_log=False, server_header=False)


if __name__ == "__main__":
    main()
