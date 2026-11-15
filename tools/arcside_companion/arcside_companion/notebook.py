"""Persistent, authenticated Jupyter kernel for the selected local environment.

Kernel lifetime is scoped to one authorized WebSocket. On disconnect the
kernel is shut down and any child process is terminated by jupyter_client.
HTML output is not forwarded for rendering, to avoid accidental DOM injection.
"""
from __future__ import annotations

import asyncio
import json

from fastapi import WebSocket
from starlette.websockets import WebSocketDisconnect

from .processes import interpreter, run_command
from .protocols import authenticate
from .security import Settings


async def notebook(ws: WebSocket, settings: Settings) -> None:
    if not await authenticate(ws, settings, "notebook"):
        return
    try:
        from jupyter_client import AsyncKernelManager
        from jupyter_client.kernelspec import KernelSpec
    except ImportError:
        await ws.send_json({"type": "error", "message": "Install jupyter_client and ipykernel in the companion environment"})
        await ws.close()
        return
    exe = interpreter(settings.workspace)
    check = await run_command([exe, "-c", "import ipykernel"], settings.workspace, 20)
    if check.returncode != 0:
        await ws.send_json({"type": "error", "message": "Install ipykernel in the selected project Python environment before running notebook cells"})
        await ws.close()
        return
    km = AsyncKernelManager(kernel_name="python3")
    km._kernel_spec = KernelSpec(
        argv=[exe, "-m", "ipykernel_launcher", "-f", "{connection_file}"],
        display_name="Arcside project Python", language="python")
    client = None
    current: asyncio.Task | None = None
    try:
        await asyncio.wait_for(km.start_kernel(cwd=str(settings.workspace)), timeout=35)
        client = km.client()
        client.start_channels()
        await asyncio.wait_for(client.wait_for_ready(timeout=30), timeout=35)
        await ws.send_json({"type": "kernel-ready", "python": exe})

        async def execute(code: str, request_id: str):
            try:
                msg_id = client.execute(code, store_history=True, allow_stdin=False,
                                        stop_on_error=True)
                deadline = asyncio.get_running_loop().time() + 120
                while asyncio.get_running_loop().time() < deadline:
                    try:
                        message = await asyncio.wait_for(client.get_iopub_msg(), timeout=25)
                    except asyncio.TimeoutError:
                        continue
                    if message.get("parent_header", {}).get("msg_id") != msg_id:
                        continue
                    kind = message.get("msg_type")
                    content = message.get("content", {})
                    if kind == "stream":
                        await ws.send_json({"type": "stream", "id": request_id,
                                            "name": content.get("name", "stdout"),
                                            "text": str(content.get("text", ""))[:500000]})
                    elif kind in ("execute_result", "display_data"):
                        data = content.get("data", {})
                        if "image/png" in data:
                            await ws.send_json({"type": "image", "id": request_id,
                                                "data": str(data["image/png"])[:3_000_000]})
                        if "text/plain" in data:
                            await ws.send_json({"type": "display", "id": request_id,
                                                "text": str(data["text/plain"])[:500000]})
                    elif kind == "error":
                        await ws.send_json({"type": "error-output", "id": request_id,
                                            "traceback": "\n".join(content.get("traceback", []))[:500000]})
                    elif kind == "status" and content.get("execution_state") == "idle":
                        return
                await ws.send_json({"type": "error-output", "id": request_id,
                                    "traceback": "Notebook cell timed out (120 seconds)"})
            except (asyncio.CancelledError, WebSocketDisconnect):
                raise
            except Exception as error:
                await ws.send_json({"type": "error-output", "id": request_id,
                                    "traceback": str(error)})
            finally:
                try:
                    await ws.send_json({"type": "finished", "id": request_id,
                                        "execution": "idle"})
                except Exception:
                    pass

        while True:
            payload = await ws.receive_json()
            if not isinstance(payload, dict):
                continue
            command = payload.get("type")
            if command == "execute":
                source = payload.get("code", "")
                if not isinstance(source, str) or len(source) > 250_000:
                    await ws.send_json({"type": "error", "message": "Cell exceeds 250 KB"})
                    continue
                if current is not None and not current.done():
                    await ws.send_json({"type": "busy", "id": payload.get("id")})
                    continue
                request_id = str(payload.get("id", ""))[:100]
                current = asyncio.create_task(execute(source, request_id))
            elif command == "interrupt":
                await km.interrupt_kernel()
                await ws.send_json({"type": "interrupted"})
            elif command == "restart":
                if current is not None and not current.done():
                    current.cancel()
                client.stop_channels()
                await km.restart_kernel(now=True)
                client = km.client()
                client.start_channels()
                await client.wait_for_ready(timeout=30)
                await ws.send_json({"type": "kernel-ready", "python": exe})
    except (WebSocketDisconnect, asyncio.CancelledError):
        pass
    finally:
        if current is not None and not current.done():
            current.cancel()
        if client is not None:
            client.stop_channels()
        if km.has_kernel:
            try:
                await asyncio.wait_for(km.shutdown_kernel(now=True), timeout=10)
            except Exception:
                pass
