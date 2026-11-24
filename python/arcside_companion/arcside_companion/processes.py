"""Workspace-bound local process management. Explicitly trusted, not sandboxed."""
from __future__ import annotations

import asyncio
import os
import signal
import sys
from pathlib import Path

MAX_OUTPUT = 700_000


async def terminate(proc: asyncio.subprocess.Process) -> None:
    if proc.returncode is not None:
        return
    if os.name == "posix":
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            return
    else:
        proc.kill()
    await proc.wait()


async def command(args: list[str], cwd: Path, timeout: float = 90, *, env: dict | None = None,
                  stdin: bytes | None = None, on_start=None) -> dict:
    """No shell=True. Executables may still execute arbitrary trusted code."""
    # Strip service secrets from any child, including callers that omit env.
    env = dict(os.environ if env is None else env)
    for secret in ("ARCSIDE_COMPANION_TOKEN", "ARCSIDE_COLLAB_ADMIN_KEY"):
        env.pop(secret, None)
    proc = await asyncio.create_subprocess_exec(
        *args, cwd=str(cwd), stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
        env=env, start_new_session=(os.name == "posix"),
    )
    async def capture(stream: asyncio.StreamReader) -> tuple[bytes, bool]:
        # Drain both pipes concurrently but never accumulate unbounded child output.
        result = bytearray()
        truncated = False
        while chunk := await stream.read(65536):
            remaining = MAX_OUTPUT - len(result)
            if len(chunk) > remaining:
                truncated = True
            if remaining > 0:
                result.extend(chunk[:remaining])
        return bytes(result), truncated

    async def send_input() -> None:
        if proc.stdin is None:
            return
        try:
            if stdin:
                proc.stdin.write(stdin)
                await proc.stdin.drain()
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            proc.stdin.close()

    async def collect():
        assert proc.stdout is not None and proc.stderr is not None
        return await asyncio.gather(capture(proc.stdout), capture(proc.stderr), send_input(), proc.wait())

    task = asyncio.create_task(collect())
    try:
        if on_start:
            on_start(proc)
        (out, out_truncated), (err, err_truncated), _, _ = await asyncio.wait_for(asyncio.shield(task), timeout=timeout)
    except asyncio.TimeoutError:
        await terminate(proc)
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)
        return {"returncode": 124, "stdout": "", "stderr": f"Process timed out after {timeout}s",
                "timed_out": True}
    except BaseException:
        await terminate(proc)
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)
        raise
    return {"returncode": proc.returncode,
            "stdout": out.decode("utf-8", "replace"),
            "stderr": err.decode("utf-8", "replace"),
            "output_truncated": out_truncated or err_truncated}


def interpreter_for(root: Path, name: str = "default") -> Path:
    if name == "system":
        return Path(sys.executable)
    if not name.replace("_", "").replace("-", "").isalnum() or len(name) > 32:
        raise ValueError("Invalid environment name")
    prefix = root / ".arcside" / "envs" / name
    executable = prefix / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    if not executable.is_file():
        if name == "default":
            return Path(sys.executable)
        raise FileNotFoundError(f"No environment named {name}; create it first")
    return executable


def run_env(root: Path, interpreter: Path) -> dict[str, str]:
    values = os.environ.copy()
    for secret in ("ARCSIDE_COMPANION_TOKEN", "ARCSIDE_COLLAB_ADMIN_KEY"):
        values.pop(secret, None)
    values["ARCSIDE_WORKSPACE"] = str(root)
    values["PYTHONUNBUFFERED"] = "1"
    values["MPLBACKEND"] = "Agg"
    # Keep VIRTUAL_ENV aligned with the selected Python environment.
    if interpreter.parent.name in ("bin", "Scripts"):
        values["VIRTUAL_ENV"] = str(interpreter.parent.parent)
        values["PATH"] = str(interpreter.parent) + os.pathsep + values.get("PATH", "")
    return values
