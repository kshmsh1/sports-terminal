"""Run local Arcside collaboration with explicit allowed browser origins."""
from __future__ import annotations
import argparse
import secrets
from pathlib import Path
import uvicorn
from .server import create_app

def main() -> None:
    parser = argparse.ArgumentParser(description="Arcside Sheets authenticated collaboration")
    parser.add_argument("--db", type=Path, default=Path.home()/".arcside"/"collaboration.sqlite")
    parser.add_argument("--port", type=int, default=8767)
    parser.add_argument("--host", choices=["127.0.0.1","localhost"], default="127.0.0.1",
                        help="Loopback only: do not expose collaboration credentials to the network")
    parser.add_argument("--allow-origin", action="append", default=[],
                        help="Explicit browser Origin, e.g. http://127.0.0.1:8765")
    args=parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error("Port must be 1024-65535")
    args.db.parent.mkdir(parents=True,exist_ok=True)
    admin_token=secrets.token_urlsafe(32)
    origins=args.allow_origin or ["http://127.0.0.1:8765","http://localhost:8765"]
    app=create_app(args.db,origins=origins,admin_token=admin_token)
    print("\nArcside Sheets collaboration — LOCAL ONLY",flush=True)
    print(f"Service: http://127.0.0.1:{args.port}",flush=True)
    print(f"Database: {args.db.resolve()}",flush=True)
    print(f"Room creation key: {admin_token}",flush=True)
    print("Share only room-specific editor/viewer access keys, NOT the creation key.",flush=True)
    print("Rooms persist in SQLite. The creation key is regenerated at every server restart.",flush=True)
    uvicorn.run(app,host="127.0.0.1",port=args.port,access_log=False)

if __name__=="__main__":main()
