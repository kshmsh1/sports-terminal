"""Entry point: python -m arcside_companion --workspace /path --allow-origin ..."""
from __future__ import annotations

import argparse
import os
from pathlib import Path

import uvicorn

from .server import create_app


def main() -> None:
    parser = argparse.ArgumentParser(description="Trusted Arcside local IDE companion (opt-in)")
    parser.add_argument("--workspace", type=Path, required=True,
                        help="Existing directory allowed for source files and code execution")
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--allow-origin", action="append", default=[],
                        help="Exactly trusted browser origin, e.g. http://127.0.0.1:8765")
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error("Port must be 1024–65535")
    origins = args.allow_origin or ["http://127.0.0.1:8765", "http://localhost:8765"]
    app = create_app(args.workspace, origins,
                     token=os.environ.get('ARCSIDE_COMPANION_TOKEN') or None)
    token = app.state.security.token
    print("\nArcside local companion — TRUSTED PROJECTS ONLY", flush=True)
    print(f"Workspace: {app.state.security.root}", flush=True)
    print(f"URL: http://127.0.0.1:{args.port}", flush=True)
    if not os.environ.get('ARCSIDE_HIDE_TOKEN_IN_OUTPUT'):
        print(f"Connection token (paste in Arcside Python Lab): {token}", flush=True)
    print("Token grants local code execution. Never share it or expose this process publicly.", flush=True)
    print("Browser origins allowed: " + ", ".join(origins) + "\n", flush=True)
    uvicorn.run(app, host="127.0.0.1", port=args.port, access_log=False)


if __name__ == "__main__":
    main()
