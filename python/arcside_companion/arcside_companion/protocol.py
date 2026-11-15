"""Local WebSocket bridges for the actual LSP, debugpy DAP, and Unix PTY."""
from __future__ import annotations

import asyncio
import contextlib
import json
import os
import shutil
import struct
from pathlib import Path

from fastapi import WebSocket, WebSocketDisconnect

from .processes import interpreter_for, run_env, terminate

MAX_FRAME = 8_000_000


async def read_frame(reader: asyncio.StreamReader) -> dict:
    """Consume one Content-Length framed JSON-RPC or DAP packet."""
    length = None
    for _ in range(32):
        line = await reader.readline()
        if not line:
            raise EOFError("Language/debug server stopped")
        if len(line) > 8192:
            raise ValueError("Oversized protocol header")
        if line in (b"\r\n", b"\n"):
            break
        key, _, value = line.decode("ascii", "replace").partition(":")
        if key.lower() == "content-length":
            length = int(value.strip())
    if length is None or length < 0 or length > MAX_FRAME:
        raise ValueError("Missing or invalid Content-Length")
    return json.loads(await reader.readexactly(length))


def encode_frame(value: dict) -> bytes:
    data = json.dumps(value, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    if len(data) > MAX_FRAME:
        raise ValueError("Oversized protocol payload")
    return f"Content-Length: {len(data)}\r\n\r\n".encode() + data


async def framed_bridge(ws: WebSocket, cmd: list[str], cwd: Path, env: dict,
                        *, enforce_launch_scope: bool = False) -> None:
    """Only trusted authenticated clients reach this subprocess bridge."""
    proc = await asyncio.create_subprocess_exec(
        *cmd, cwd=str(cwd), env=env, stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
        start_new_session=(os.name == "posix"),
    )
    assert proc.stdin and proc.stdout and proc.stderr

    async def from_process() -> None:
        while True:
            message = await read_frame(proc.stdout)
            await ws.send_json({"type": "protocol", "payload": message})

    async def from_client() -> None:
        while True:
            message = await ws.receive_json()
            if message.get("type") != "protocol" or not isinstance(message.get("payload"), dict):
                continue
            payload = message["payload"]
            if enforce_launch_scope and payload.get("command") in ("launch", "attach"):
                if payload["command"] == "attach":
                    await ws.send_json({"type": "error", "message": "Attach to arbitrary processes is disabled"})
                    continue
                args = payload.get("arguments") or {}
                program = args.get("program")
                if not program or not isinstance(program, str):
                    await ws.send_json({"type": "error", "message": "No launch program"})
                    continue
                candidate = Path(program).resolve()
                if candidate != cwd and not candidate.is_relative_to(cwd):
                    await ws.send_json({"type": "error", "message": "Debug launch is outside workspace"})
                    continue
            proc.stdin.write(encode_frame(payload))
            await proc.stdin.drain()

    # Consume stderr to avoid deadlocks from verbose language servers.
    async def read_stderr() -> None:
        while await proc.stderr.read(4096):
            pass

    stderr_task = asyncio.create_task(read_stderr())
    tasks = [asyncio.create_task(from_process()), asyncio.create_task(from_client())]
    try:
        done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for task in done:
            if not task.cancelled():
                error = task.exception()
                if error and not isinstance(error, (WebSocketDisconnect, EOFError, asyncio.IncompleteReadError)):
                    with contextlib.suppress(Exception):
                        await ws.send_json({"type": "error", "message": str(error)[:500]})
    finally:
        for task in tasks:
            task.cancel()
        await terminate(proc)
        stderr_task.cancel()
        with contextlib.suppress(Exception):
            await ws.close()


async def terminal(ws: WebSocket, cwd: Path, interpreter: Path) -> None:
    if os.name != "posix":
        await ws.send_json({"type": "error", "message": "PTY terminal is supported on macOS and Linux only"})
        await ws.close()
        return
    import fcntl
    import pty
    import termios

    master, slave = pty.openpty()
    shell = os.environ.get("SHELL", "/bin/sh")
    if not Path(shell).is_file():
        shell = "/bin/sh"
    env = run_env(cwd, interpreter)
    env["TERM"] = "xterm-256color"
    proc = None
    try:
        proc = await asyncio.create_subprocess_exec(
            shell, "-i", cwd=str(cwd), env=env, stdin=slave,
            stdout=slave, stderr=slave, start_new_session=True,
        )
    finally:
        os.close(slave)

    async def incoming() -> None:
        while True:
            message = await ws.receive_json()
            if message.get("type") == "input":
                raw = str(message.get("data", ""))[:20000].encode("utf-8")
                os.write(master, raw)
            elif message.get("type") == "resize":
                cols = max(20, min(500, int(message.get("cols", 80))))
                rows = max(5, min(200, int(message.get("rows", 24))))
                fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))

    async def outgoing() -> None:
        while True:
            chunk = await asyncio.to_thread(os.read, master, 4096)
            if not chunk:
                return
            await ws.send_json({"type": "output", "data": chunk.decode("utf-8", "replace")})

    tasks = [asyncio.create_task(incoming()), asyncio.create_task(outgoing())]
    try:
        await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
    finally:
        os.close(master)
        for task in tasks:
            task.cancel()
        if proc:
            await terminate(proc)
        with contextlib.suppress(Exception):
            await ws.close()


async def notebook(ws: WebSocket, root: Path, interpreter: Path) -> None:
    """Real Jupyter kernel via jupyter_client; one kernel per authenticated WS."""
    try:
        from jupyter_client import AsyncKernelManager
        from jupyter_client.kernelspec import KernelSpec
    except ImportError:
        await ws.send_json({"type": "error", "message": "Install arcside-companion[notebook] first"})
        await ws.close()
        return

    # Explicit spec pins the notebook to the currently selected environment.
    # ipykernel must be installed in that environment.
    km = AsyncKernelManager(kernel_name="python3")
    km.kernel_spec = KernelSpec(
        argv=[str(interpreter), "-m", "ipykernel_launcher", "-f", "{connection_file}"],
        display_name="Arcside Python", language="python",
    )
    client = None
    try:
        await km.start_kernel(cwd=str(root), env=run_env(root, interpreter))
        client = km.client()
        client.start_channels()
        await client.wait_for_ready(timeout=30)
        await ws.send_json({"type": "ready", "interpreter": str(interpreter)})
        while True:
            message = await ws.receive_json()
            if message.get("type") == "interrupt":
                await km.interrupt_kernel()
                continue
            if message.get("type") != "execute":
                continue
            source = str(message.get("source", ""))[:100_000]
            cell_id = str(message.get("id", ""))[:80]
            msg_id = client.execute(source, store_history=True, allow_stdin=False)
            await ws.send_json({"type": "started", "id": cell_id})
            while True:
                try:
                    packet = await asyncio.wait_for(client.get_iopub_msg(), timeout=90)
                except asyncio.TimeoutError:
                    await ws.send_json({"type": "error", "id": cell_id, "message": "Kernel output timeout"})
                    break
                if packet.get("parent_header", {}).get("msg_id") != msg_id:
                    continue
                kind = packet.get("msg_type")
                body = packet.get("content", {})
                if kind in ("stream", "execute_result", "display_data", "error", "clear_output"):
                    await ws.send_json({"type": "cell_output", "id": cell_id, "kind": kind,
                                        "content": body})
                if kind == "status" and body.get("execution_state") == "idle":
                    await ws.send_json({"type": "finished", "id": cell_id})
                    break
    except (WebSocketDisconnect, asyncio.CancelledError):
        pass
    except Exception as error:
        with contextlib.suppress(Exception):
            await ws.send_json({"type": "error", "message": f"Kernel error: {error}"[:600]})
    finally:
        if client:
            client.stop_channels()
        with contextlib.suppress(Exception):
            if km.has_kernel:
                await km.shutdown_kernel(now=True)
        with contextlib.suppress(Exception):
            await ws.close()
