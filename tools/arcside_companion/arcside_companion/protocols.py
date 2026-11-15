"""WebSocket PTY and LSP/DAP transports for a user-started local companion."""
from __future__ import annotations

import asyncio
import json
import os
import pty
import re
import shutil
import signal
import socket
import struct
import subprocess
import sys
from typing import Any

from fastapi import WebSocket
from starlette.websockets import WebSocketDisconnect

from .security import Settings

MAX_FRAME = 4_000_000


async def authenticate(ws: WebSocket, settings: Settings, channel: str) -> bool:
    if not settings.origin_allowed(ws.headers.get("origin")):
        await ws.close(code=4403)
        return False
    await ws.accept()
    try:
        hello = await asyncio.wait_for(ws.receive_json(), timeout=8)
        if (not isinstance(hello, dict) or hello.get("type") != "auth"
                or not settings.authorized(hello.get("token"))):
            await ws.close(code=4401)
            return False
    except (asyncio.TimeoutError, WebSocketDisconnect, ValueError):
        await ws.close(code=4401)
        return False
    await ws.send_json({"type": "ready", "channel": channel})
    return True


def terminate_process(proc: asyncio.subprocess.Process | subprocess.Popen) -> None:
    if proc.returncode is not None if isinstance(proc, asyncio.subprocess.Process) else proc.poll() is not None:
        return
    try:
        if os.name != "nt":
            os.killpg(proc.pid, signal.SIGKILL)
        else:
            proc.kill()
    except ProcessLookupError:
        pass


async def terminal(ws: WebSocket, settings: Settings) -> None:
    if not await authenticate(ws, settings, "terminal"):
        return
    if os.name == "nt":
        await ws.send_json({"type": "error", "message": "PTY currently requires macOS or Linux; Windows ConPTY is not yet implemented"})
        await ws.close()
        return
    shell = os.environ.get("SHELL", "/bin/sh")
    if os.path.basename(shell) not in {"bash", "zsh", "fish", "sh", "dash", "ksh"} or not os.path.isfile(shell):
        shell = "/bin/sh"
    master, slave = pty.openpty()
    env = {**os.environ, "TERM": "xterm-256color", "PYTHONUNBUFFERED": "1"}
    proc = subprocess.Popen([shell, "-i"], stdin=slave, stdout=slave, stderr=slave,
                            cwd=settings.workspace, env=env, start_new_session=True,
                            close_fds=True)
    os.close(slave)
    loop = asyncio.get_running_loop()
    messages: asyncio.Queue[bytes | None] = asyncio.Queue(maxsize=256)

    def on_read():
        try:
            block = os.read(master, 16384)
            if not block:
                messages.put_nowait(None)
            elif not messages.full():
                messages.put_nowait(block)
        except (OSError, asyncio.QueueFull):
            if not messages.full():
                messages.put_nowait(None)

    loop.add_reader(master, on_read)

    async def writer():
        while True:
            block = await messages.get()
            if block is None:
                return
            await ws.send_json({"type": "output", "data": block.decode("utf-8", "replace")})

    async def reader():
        while True:
            payload = await ws.receive_json()
            if not isinstance(payload, dict):
                continue
            if payload.get("type") == "input":
                data = str(payload.get("data", ""))[:20000]
                os.write(master, data.encode("utf-8", "replace"))
            elif payload.get("type") == "resize":
                try:
                    import fcntl
                    import termios
                    cols = max(20, min(300, int(payload.get("cols", 80))))
                    rows = max(5, min(120, int(payload.get("rows", 24))))
                    fcntl.ioctl(master, termios.TIOCSWINSZ,
                                struct.pack("HHHH", rows, cols, 0, 0))
                except (ValueError, TypeError, OSError):
                    pass

    tasks = [asyncio.create_task(writer()), asyncio.create_task(reader())]
    try:
        await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
    except WebSocketDisconnect:
        pass
    finally:
        for task in tasks:
            task.cancel()
        loop.remove_reader(master)
        os.close(master)
        terminate_process(proc)
        await asyncio.to_thread(proc.wait)


async def read_framed(reader: asyncio.StreamReader) -> dict[str, Any]:
    headers = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), timeout=3600)
    if len(headers) > 16384:
        raise ValueError("Oversized protocol headers")
    match = re.search(rb"(?:^|\r\n)Content-Length:\s*(\d+)\s*(?:\r\n|$)", headers, re.I)
    if not match:
        raise ValueError("Protocol message missing Content-Length")
    length = int(match.group(1))
    if length < 1 or length > MAX_FRAME:
        raise ValueError("Protocol frame limit exceeded")
    return json.loads(await reader.readexactly(length))


def write_framed(message: dict[str, Any]) -> bytes:
    body = json.dumps(message, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    if len(body) > MAX_FRAME:
        raise ValueError("Outbound protocol frame limit exceeded")
    return b"Content-Length: " + str(len(body)).encode() + b"\r\n\r\n" + body


async def bridge(ws: WebSocket, incoming: asyncio.StreamReader,
                 outgoing: asyncio.StreamWriter | asyncio.StreamWriter) -> None:
    async def from_protocol():
        while True:
            await ws.send_json({"type": "rpc", "message": await read_framed(incoming)})

    async def from_browser():
        while True:
            payload = await ws.receive_json()
            if isinstance(payload, dict) and payload.get("type") == "rpc":
                message = payload.get("message")
                if isinstance(message, dict):
                    outgoing.write(write_framed(message))
                    await outgoing.drain()

    tasks = [asyncio.create_task(from_protocol()), asyncio.create_task(from_browser())]
    try:
        await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
    finally:
        for task in tasks:
            task.cancel()


async def language_server(ws: WebSocket, settings: Settings) -> None:
    if not await authenticate(ws, settings, "lsp"):
        return
    executable = shutil.which("pyright-langserver") or shutil.which("pylsp")
    if not executable:
        await ws.send_json({"type": "error", "message": "Install pyright-langserver (npm install -g pyright) or python-lsp-server (pip install python-lsp-server)"})
        await ws.close()
        return
    args = [executable, "--stdio"] if "pyright" in executable else [executable]
    proc = await asyncio.create_subprocess_exec(
        *args, cwd=settings.workspace, stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
        start_new_session=(os.name != "nt"))
    assert proc.stdin and proc.stdout
    try:
        await bridge(ws, proc.stdout, proc.stdin)
    except (WebSocketDisconnect, ConnectionError, asyncio.IncompleteReadError):
        pass
    finally:
        terminate_process(proc)
        await proc.wait()


def vacant_port() -> int:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])
    finally:
        sock.close()


async def debugger(ws: WebSocket, settings: Settings) -> None:
    if not await authenticate(ws, settings, "dap"):
        return
    port = vacant_port()
    proc = await asyncio.create_subprocess_exec(
        sys.executable, "-m", "debugpy.adapter", "--host", "127.0.0.1",
        "--port", str(port), cwd=settings.workspace,
        stdin=asyncio.subprocess.DEVNULL,
        stdout=asyncio.subprocess.DEVNULL,
        stderr=asyncio.subprocess.PIPE,
        start_new_session=(os.name != "nt"),
    )
    reader = writer = None
    try:
        for _ in range(100):
            if proc.returncode is not None:
                break
            try:
                reader, writer = await asyncio.open_connection("127.0.0.1", port)
                break
            except OSError:
                await asyncio.sleep(0.075)
        if not reader or not writer:
            await ws.send_json({"type": "error", "message": "debugpy adapter could not start"})
            return
        await ws.send_json({"type": "adapter-ready",
                            "workspace": str(settings.workspace),
                            "python": str(settings.workspace.joinpath(".venv", "bin", "python"))
                                      if settings.workspace.joinpath(".venv", "bin", "python").is_file()
                                      else sys.executable})
        await bridge(ws, reader, writer)
    except (WebSocketDisconnect, ConnectionError, asyncio.IncompleteReadError):
        pass
    finally:
        if writer:
            writer.close()
            try:
                await writer.wait_closed()
            except OSError:
                pass
        terminate_process(proc)
        await proc.wait()
