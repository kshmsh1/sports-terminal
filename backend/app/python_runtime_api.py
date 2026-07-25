from __future__ import annotations

import ast
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(prefix="/v2/runtime/python", tags=["python-runtime"])

_WORKER = Path(__file__).with_name("sandbox_worker.py")
_MAX_CODE = 20_000
_MAX_ROWS = 500
_MAX_COLUMNS = 64
_MAX_INPUT_BYTES = 2_000_000
_MAX_OUTPUT_BYTES = 100_000

_ALLOWED_CALLS = {
    "abs",
    "all",
    "any",
    "bool",
    "column",
    "dict",
    "enumerate",
    "filter",
    "float",
    "group_by",
    "int",
    "len",
    "list",
    "map",
    "max",
    "mean",
    "median",
    "min",
    "numeric",
    "percentile",
    "print",
    "range",
    "reversed",
    "round",
    "set",
    "sorted",
    "str",
    "sum",
    "tuple",
    "zip",
}

_DISALLOWED_NODES = (
    ast.Import,
    ast.ImportFrom,
    ast.Attribute,
    ast.ClassDef,
    ast.Lambda,
    ast.With,
    ast.AsyncWith,
    ast.Try,
    ast.Raise,
    ast.Global,
    ast.Nonlocal,
    ast.Delete,
    ast.Await,
    ast.Yield,
    ast.YieldFrom,
)


class PythonExecutionRequest(BaseModel):
    code: str
    rows: list[dict[str, Any]] = Field(default_factory=list)
    columns: list[dict[str, Any]] = Field(default_factory=list)
    timeout_seconds: float = Field(default=3.0, ge=0.25, le=5.0)


class PythonExecutionResponse(BaseModel):
    status: str
    stdout: str = ""
    result: Any = None
    row_count: int = 0
    column_count: int = 0
    duration_ms: int = 0
    warnings: list[str] = Field(default_factory=list)


class _SafetyVisitor(ast.NodeVisitor):
    def __init__(self, defined_functions: set[str]) -> None:
        self.errors: list[str] = []
        self.defined_functions = defined_functions

    def visit_FunctionDef(self, node: ast.FunctionDef) -> Any:
        if node.name.startswith("__"):
            self.errors.append("Dunder function names are not allowed.")
        if len(node.args.args) > 12:
            self.errors.append(
                "Functions may accept at most 12 positional arguments."
            )
        self.generic_visit(node)

    def visit_Name(self, node: ast.Name) -> Any:
        if node.id.startswith("__"):
            self.errors.append(f"Dunder name is not allowed: {node.id}")
        self.generic_visit(node)

    def visit_Call(self, node: ast.Call) -> Any:
        if not isinstance(node.func, ast.Name):
            self.errors.append(
                "Only direct calls to approved helpers or notebook-defined "
                "functions are allowed."
            )
        else:
            name = node.func.id
            if name not in _ALLOWED_CALLS and name not in self.defined_functions:
                self.errors.append(f"Call is not allowed: {name}")
        if len(node.args) + len(node.keywords) > 32:
            self.errors.append("A function call may use at most 32 arguments.")
        self.generic_visit(node)

    def generic_visit(self, node: ast.AST) -> Any:
        if isinstance(node, _DISALLOWED_NODES):
            self.errors.append(
                "Syntax is not allowed in the notebook runtime: "
                f"{type(node).__name__}"
            )
            return None
        return super().generic_visit(node)


def validate_python_code(code: str) -> list[str]:
    if not code.strip():
        return ["Notebook code is empty."]
    if len(code) > _MAX_CODE:
        return [f"Notebook code exceeds {_MAX_CODE} characters."]
    try:
        tree = ast.parse(code, mode="exec")
    except SyntaxError as error:
        return [f"Syntax error on line {error.lineno}: {error.msg}"]
    defined_functions = {
        node.name
        for node in ast.walk(tree)
        if isinstance(node, ast.FunctionDef)
    }
    visitor = _SafetyVisitor(defined_functions)
    visitor.visit(tree)
    return list(dict.fromkeys(visitor.errors))


def _resource_limiter() -> None:
    try:
        import resource

        resource.setrlimit(resource.RLIMIT_CPU, (4, 4))
        resource.setrlimit(
            resource.RLIMIT_AS,
            (256 * 1024 * 1024, 256 * 1024 * 1024),
        )
        resource.setrlimit(
            resource.RLIMIT_FSIZE,
            (1 * 1024 * 1024, 1 * 1024 * 1024),
        )
        resource.setrlimit(resource.RLIMIT_NOFILE, (16, 16))
        resource.setrlimit(resource.RLIMIT_NPROC, (0, 0))
    except Exception:
        # Wall-clock timeout, isolated mode, AST validation and a temporary
        # working directory remain active on platforms without POSIX controls.
        return


def execute_python_notebook(
    payload: PythonExecutionRequest,
) -> PythonExecutionResponse:
    errors = validate_python_code(payload.code)
    if errors:
        raise HTTPException(
            status_code=422,
            detail={
                "message": "Notebook code was rejected by the sandbox policy",
                "errors": errors,
            },
        )

    rows = payload.rows[:_MAX_ROWS]
    columns = payload.columns[:_MAX_COLUMNS]
    warnings: list[str] = []
    if len(payload.rows) > _MAX_ROWS:
        warnings.append(
            f"Input was truncated to {_MAX_ROWS} rows for interactive execution."
        )
    if len(payload.columns) > _MAX_COLUMNS:
        warnings.append(
            f"Input was truncated to {_MAX_COLUMNS} columns for interactive execution."
        )

    request_bytes = json.dumps(
        {"code": payload.code, "rows": rows, "columns": columns},
        separators=(",", ":"),
    ).encode("utf-8")
    if len(request_bytes) > _MAX_INPUT_BYTES:
        raise HTTPException(
            status_code=413,
            detail="Notebook input exceeds the interactive runtime payload limit",
        )

    started = time.perf_counter()
    with tempfile.TemporaryDirectory(
        prefix="sports-terminal-python-"
    ) as temporary_directory:
        environment = {
            "PATH": os.environ.get("PATH", ""),
            "PYTHONIOENCODING": "utf-8",
            "PYTHONDONTWRITEBYTECODE": "1",
        }
        try:
            completed = subprocess.run(
                [sys.executable, "-I", "-S", str(_WORKER)],
                input=request_bytes,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=temporary_directory,
                env=environment,
                timeout=payload.timeout_seconds,
                check=False,
                preexec_fn=_resource_limiter if os.name == "posix" else None,
            )
        except subprocess.TimeoutExpired as error:
            duration_ms = int((time.perf_counter() - started) * 1000)
            raise HTTPException(
                status_code=408,
                detail={
                    "message": "Notebook execution exceeded the time limit",
                    "duration_ms": duration_ms,
                },
            ) from error

    duration_ms = int((time.perf_counter() - started) * 1000)
    stdout = completed.stdout[:_MAX_OUTPUT_BYTES]
    stderr = completed.stderr[:_MAX_OUTPUT_BYTES]
    if len(completed.stdout) > _MAX_OUTPUT_BYTES:
        warnings.append("Notebook output was truncated.")
    if completed.returncode != 0:
        detail = stderr.decode("utf-8", errors="replace").strip()
        raise HTTPException(
            status_code=422,
            detail={
                "message": "Notebook execution failed",
                "error": detail[-8000:],
                "duration_ms": duration_ms,
            },
        )
    try:
        response = json.loads(stdout.decode("utf-8"))
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail="Sandbox returned an invalid response",
        ) from error
    return PythonExecutionResponse(
        status="completed",
        stdout=str(response.get("stdout") or "")[:_MAX_OUTPUT_BYTES],
        result=response.get("result"),
        row_count=int(response.get("row_count") or 0),
        column_count=int(response.get("column_count") or 0),
        duration_ms=duration_ms,
        warnings=warnings,
    )


@router.get("/capabilities")
def runtime_capabilities() -> dict[str, Any]:
    return {
        "runtime": "isolated-python",
        "execution": "server-subprocess",
        "imports": False,
        "filesystem": False,
        "network": False,
        "processes": False,
        "reflection": False,
        "max_code_characters": _MAX_CODE,
        "max_rows": _MAX_ROWS,
        "max_columns": _MAX_COLUMNS,
        "max_timeout_seconds": 5,
        "helpers": [
            "column",
            "numeric",
            "mean",
            "median",
            "percentile",
            "group_by",
        ],
        "result_contract": (
            "Assign a JSON-compatible value to the variable result."
        ),
    }


@router.post("/execute", response_model=PythonExecutionResponse)
def execute_notebook(
    payload: PythonExecutionRequest,
) -> PythonExecutionResponse:
    return execute_python_notebook(payload)
