"""CI-only loopback service with a fixed throwaway token and temporary project."""
from __future__ import annotations
import atexit
import shutil
import tempfile
from pathlib import Path

import uvicorn
from arcside_companion.security import Settings
from arcside_companion.server import create_app

root=Path(tempfile.mkdtemp(prefix="arcside-browser-test-"))
atexit.register(shutil.rmtree, root, ignore_errors=True)
settings=Settings.make(root,origins=["http://127.0.0.1:8765"],
                       token="arcside-ci-throwaway-token",port=8766)
uvicorn.run(create_app(settings),host="127.0.0.1",port=8766,access_log=False)
