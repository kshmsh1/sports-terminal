"""Endpoint regression tests: trust boundary, real process execution and workspace scope."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from arcside_companion.protocol import encode_frame, read_frame
from arcside_companion.server import create_app


@pytest.fixture
def client(tmp_path):
    app = create_app(tmp_path, ["http://127.0.0.1:8765"], "test-secret")
    with TestClient(app, base_url="http://127.0.0.1:8766") as c:
        yield c


def auth():
    return {"Authorization": "Bearer test-secret", "Origin": "http://127.0.0.1:8765"}


def test_denies_unauthenticated_untrusted_origin_and_bad_host(client):
    assert client.get("/api/status").status_code == 401
    assert client.get("/api/status", headers={"Authorization": "Bearer wrong"}).status_code == 401
    assert client.get("/api/status", headers={
        "Authorization": "Bearer test-secret", "Origin": "https://untrusted.example"
    }).status_code == 403
    assert client.get("/api/status", headers={**auth(), "Host": "malicious.test:8766"}).status_code == 403
    status = client.get("/api/status", headers=auth())
    assert status.status_code == 200
    assert "interpreter" in status.json()


def test_sync_and_run_actual_python(client, tmp_path):
    payload = {"files": {
        "main.py": "print('arcside sidecar actual python')\nprint(2**10)\n",
        "helpers/math.py": "x = 42\n",
    }}
    assert client.post("/api/sync", json=payload, headers=auth()).json()["written"] == 2
    run = client.post("/api/run", json={"entry": "main.py"}, headers=auth())
    assert run.status_code == 200
    assert run.json()["returncode"] == 0
    assert "arcside sidecar actual python" in run.json()["stdout"]
    assert "1024" in run.json()["stdout"]
    assert (tmp_path / "helpers" / "math.py").read_text() == "x = 42\n"


def test_run_python_selection_without_file(client):
    run = client.post("/api/run", json={"mode": "selection", "source": "print(3*14)"}, headers=auth())
    assert run.status_code == 200
    assert run.json()["stdout"].strip() == "42"


def test_workspace_restrictions_and_symlink_escape(client, tmp_path):
    for file in ["../outside.py", "/tmp/bad.py", "a//b.py", ".git/config",
                 ".arcside/token", "bad\\name.py"]:
        response = client.post("/api/sync", json={"files": {file: "hello"}}, headers=auth())
        assert response.status_code in (400, 403), (file, response.text)
    external = tmp_path.parent / ("outside-" + tmp_path.name)
    external.mkdir()
    (tmp_path / "linked").symlink_to(external, target_is_directory=True)
    result = client.post("/api/sync", json={"files": {"linked/hack.py": "print(1)"}}, headers=auth())
    assert result.status_code == 403
    assert not (external / "hack.py").exists()


def test_workspace_file_quota(client):
    assert client.post("/api/sync", json={"files": {"large.py": "a"*700001}},
                       headers=auth()).status_code == 413


def test_websocket_first_message_auth(client):
    with client.websocket_connect("/ws/terminal", headers={"Origin": "http://127.0.0.1:8765", "Host": "127.0.0.1:8766"}) as ws:
        ws.send_json({"type": "authenticate", "token": "test-secret"})
        assert ws.receive_json()["type"] == "authenticated"


def test_environment_listing(client):
    r = client.get("/api/env", headers=auth())
    assert r.status_code == 200
    assert "system" in r.json()["names"]
    assert client.post("/api/env/create", json={"name": "../escape"}, headers=auth()).status_code == 400


def test_git_init_and_status(client):
    from shutil import which
    if not which("git"):
        pytest.skip("Git not installed")
    result = client.post("/api/git", headers=auth(), json={"action": "init"})
    assert result.status_code == 200, result.text
    assert result.json()["returncode"] == 0
    state = client.post("/api/git", headers=auth(), json={"action": "status"})
    assert state.status_code == 200
    assert state.json()["returncode"] == 0


def test_test_runner(client):
    assert client.post("/api/sync", headers=auth(), json={"files": {
        "test_numbers.py": "import unittest\nclass Numbers(unittest.TestCase):\n"
                           "    def test_sum(self): self.assertEqual(1+2,3)\n"
    }}).status_code == 200
    result = client.post("/api/run", headers=auth(), json={"mode": "test"}).json()
    assert result["returncode"] == 0, result


def test_interrupted_missing_job(client):
    response = client.post("/api/interrupt", headers=auth(), json={"job_id": "not-running"})
    assert response.json()["interrupted"] is False


def test_protected_status_lists_no_token(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert "test-secret" not in response.text


@pytest.mark.asyncio
async def test_framed_protocol_roundtrip():
    from asyncio import StreamReader
    obj = {"jsonrpc": "2.0", "id": 1, "method": "textDocument/hover",
           "params": {"textDocument": {"uri": "file:///tmp/a.py"}}}
    reader = StreamReader()
    reader.feed_data(encode_frame(obj))
    reader.feed_eof()
    assert await read_frame(reader) == obj


def test_read_local_project_and_safe_revision_checked_updates(client,tmp_path):
    (tmp_path/"main.py").write_text("print('existing')\n",encoding="utf-8")
    response=client.post("/api/sync",headers=auth(),json={
        "files":{"main.py":"print('replacement')\n"},
    })
    assert response.status_code==409
    assert (tmp_path/"main.py").read_text()=="print('existing')\n"
    opened=client.post("/api/read",headers=auth(),json={"path":"main.py"})
    assert opened.status_code==200
    assert opened.json()["source"]=="print('existing')\n"
    sha=opened.json()["sha256"]
    response=client.post("/api/sync",headers=auth(),json={
        "files":{"main.py":"print('edited')\n"},"expected":{"main.py":sha},
    })
    assert response.status_code==200,response.text
    updated=response.json()["hashes"]["main.py"]
    assert len(updated)==64
    (tmp_path/"main.py").write_text("print('external edit')\n")
    conflicting=client.post("/api/sync",headers=auth(),json={
        "files":{"main.py":"print('stale edit')\n"},"expected":{"main.py":updated},
    })
    assert conflicting.status_code==409
    assert (tmp_path/"main.py").read_text()=="print('external edit')\n"


def test_file_read_denies_symlink_escape(client,tmp_path):
    target=tmp_path.parent / ("secret-"+tmp_path.name+".txt")
    target.write_text("not accessible",encoding="utf-8")
    (tmp_path/"secret.txt").symlink_to(target)
    response=client.post("/api/read",headers=auth(),json={"path":"secret.txt"})
    assert response.status_code==403
    assert "not accessible" not in response.text


def test_local_execution_timeout_kills_process(client):
    r=client.post("/api/run",headers=auth(),json={
        "mode":"selection",
        "source":"import time;time.sleep(5)",
        "timeout":1,
    })
    assert r.status_code==200
    assert r.json()["timed_out"] is True
    assert r.json()["returncode"]==124


def test_native_cprofile_reports_call_stats(client):
    client.post("/api/sync",headers=auth(),json={
        "files":{"profile.py":"from statistics import mean\nprint(mean([2, 4, 6]))\n"}
    })
    response=client.post("/api/run",headers=auth(),json={
        "mode":"profile","entry":"profile.py",
    })
    assert response.status_code==200,response.text
    assert response.json()["returncode"]==0,response.text
    assert "function calls" in response.json()["stdout"]


def test_native_pytest_coverage_report(client):
    client.post("/api/sync",headers=auth(),json={"files":{
        "sample.py":"def double(x): return x*2\n",
        "test_sample.py":"from sample import double\n"
                         "def test_double(): assert double(8)==16\n",
    }})
    response=client.post("/api/run",headers=auth(),json={"mode":"coverage"})
    assert response.status_code==200,response.text
    assert response.json()["returncode"]==0,response.text
    assert "TOTAL" in response.json()["stdout"]
