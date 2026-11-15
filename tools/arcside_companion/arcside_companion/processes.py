"""Bounded subprocess helpers for local, explicitly trusted source code."""
from __future__ import annotations

import asyncio
import os
import re
import shutil
import signal
import sys
from dataclasses import dataclass
from pathlib import Path
from collections.abc import Callable

MAX_OUTPUT = 2_000_000
PACKAGE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*(?:\[[A-Za-z0-9_.,-]+\])?(?:(?:==|!=|>=|<=|~=|>|<)[A-Za-z0-9_.+*-]+)?$")


@dataclass
class CommandResult:
    returncode: int
    stdout: str
    stderr: str
    timed_out: bool = False

    def dictionary(self) -> dict:
        return {"exit_code": self.returncode, "stdout": self.stdout,
                "stderr": self.stderr, "timeout": self.timed_out}


async def run_command(args: list[str], root: Path, timeout: int = 90,
                      on_start: Callable[[asyncio.subprocess.Process], None] | None = None) -> CommandResult:
    """Never invoke a shell to execute user-controlled command arguments."""
    env = {**os.environ, "PYTHONUNBUFFERED": "1", "MPLBACKEND": "Agg"}
    proc = await asyncio.create_subprocess_exec(
        *args, cwd=root, env=env,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
        start_new_session=(os.name != "nt"),
    )
    if on_start:
        on_start(proc)
    # subprocess.communicate() buffers *all* output, regardless of the
    # truncation applied afterwards. Drain both pipes continuously with hard
    # memory caps instead, so logging a giant dataset cannot exhaust memory.
    async def drain(stream: asyncio.StreamReader) -> str:
        chunks: list[bytes] = []
        remaining = MAX_OUTPUT
        truncated = False
        while block := await stream.read(65536):
            if len(block) > remaining:
                truncated = True
            if remaining:
                kept = block[:remaining]
                chunks.append(kept)
                remaining -= len(kept)
        output = b"".join(chunks).decode("utf-8", "replace")
        return output + ("\n[Arcside output truncated at 2 MB]\n" if truncated else "")

    stdout_task = asyncio.create_task(drain(proc.stdout))
    stderr_task = asyncio.create_task(drain(proc.stderr))
    expired = False
    try:
        try:
            await asyncio.wait_for(proc.wait(), timeout=timeout)
        except asyncio.TimeoutError:
            expired = True
            if os.name != "nt":
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            else:
                proc.kill()
            await proc.wait()
        try:
            stdout, stderr = await asyncio.wait_for(
                asyncio.gather(stdout_task, stderr_task), timeout=4)
        except asyncio.TimeoutError:
            for task in (stdout_task, stderr_task):
                task.cancel()
            stdout, stderr = "", "Output streams remained open after process exit"
    finally:
        if proc.returncode is None:
            if os.name != "nt":
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            else:
                proc.kill()
            await proc.wait()
        for task in (stdout_task, stderr_task):
            if not task.done():
                task.cancel()
    return CommandResult(proc.returncode or 0, stdout, stderr, expired)


def interpreter(root: Path) -> str:
    for relative in ((".venv", "Scripts", "python.exe") if os.name == "nt"
                     else (".venv", "bin", "python"),):
        path = root.joinpath(*relative)
        if path.is_file():
            # Preserve the venv/conda launcher path: resolving a symlink can
            # discard pyvenv.cfg and silently switch to global Python.
            return str(path)
    for relative in ((".conda", "python.exe") if os.name == "nt"
                     else (".conda", "bin", "python"),):
        path = root.joinpath(*relative)
        if path.is_file():
            return str(path)
    return sys.executable


def available_tools(root: Path) -> dict[str, bool | str]:
    return {"python": interpreter(root),
            "uv": bool(shutil.which("uv")),
            "conda": bool(shutil.which("conda")),
            "ruff": bool(shutil.which("ruff")),
            "pytest": bool(shutil.which("pytest")),
            "git": bool(shutil.which("git")),
            "lsp": shutil.which("pyright-langserver") or shutil.which("pylsp") or "",
            "debugpy": True}


async def create_environment(root: Path, manager: str) -> CommandResult:
    if manager not in {"venv", "uv", "conda"}:
        raise ValueError("Manager must be venv, uv or conda")
    dest = root / (".conda" if manager == "conda" else ".venv")
    if dest.is_symlink():
        raise ValueError("Refusing to create environment via symlink")
    if dest.exists():
        raise ValueError("Environment directory already exists")
    if manager == "venv":
        return await run_command([sys.executable, "-m", "venv", str(dest)], root, 180)
    if manager == "uv":
        tool = shutil.which("uv")
        if not tool:
            raise ValueError("uv not installed; install it locally first")
        return await run_command([tool, "venv", str(dest)], root, 180)
    tool = shutil.which("conda")
    if not tool:
        raise ValueError("conda not installed")
    return await run_command([tool, "create", "--yes", "--prefix", str(dest),
                              "python=3.12"], root, 180)


async def install_packages(root: Path, packages: list[str]) -> CommandResult:
    if not 1 <= len(packages) <= 15 or any(not PACKAGE_RE.fullmatch(p) for p in packages):
        raise ValueError("Use 1-15 pinned package names; URLs, paths and option flags are not allowed")
    exe = interpreter(root)
    venv = (root / ".venv").exists() or (root / ".conda").exists()
    if not venv:
        raise ValueError("Create a project environment before installing packages")
    uv = shutil.which("uv")
    if uv and (root / ".venv").exists():
        return await run_command([uv, "pip", "install", "--python", exe, *packages], root, 180)
    return await run_command([exe, "-m", "pip", "install", "--disable-pip-version-check",
                              *packages], root, 180)
