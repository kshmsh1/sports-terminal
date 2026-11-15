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
                  stdin: bytes | None = None) -> dict:
    """No shell=True. Executables may still execute arbitrary trusted code."""
    proc = await asyncio.create_subprocess_exec(
        *args, cwd=str(cwd), stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
        env=env, start_new_session=(os.name == "posix"),
    )
    try:
        out, err = await asyncio.wait_for(proc.communicate(stdin), timeout=timeout)
    except asyncio.TimeoutError:
        await terminate(proc)
        return {"returncode": 124, "stdout": "", "stderr": f"Process timed out after {timeout}s",
                "timed_out": True}
    return {"returncode": proc.returncode,
            "stdout": out[:MAX_OUTPUT].decode("utf-8", "replace"),
            "stderr": err[:MAX_OUTPUT].decode("utf-8", "replace"),
            "output_truncated": len(out) > MAX_OUTPUT or len(err) > MAX_OUTPUT}


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
    values["ARCSIDE_WORKSPACE"] = str(root)
    values["PYTHONUNBUFFERED"] = "1"
    values["MPLBACKEND"] = "Agg"
    # Keep VIRTUAL_ENV aligned with the selected Python environment.
    if interpreter.parent.name in ("bin", "Scripts"):
        values["VIRTUAL_ENV"] = str(interpreter.parent.parent)
        values["PATH"] = str(interpreter.parent) + os.pathsep + values.get("PATH", "")
    return values
