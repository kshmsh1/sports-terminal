import os
import re
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from arcside_companion.security import Settings
from arcside_companion.processes import PACKAGE_RE
from arcside_companion.protocols import write_framed
from arcside_companion.server import create_app

ORIGIN = "http://127.0.0.1:8765"


@pytest.fixture
def companion(tmp_path: Path):
    settings = Settings.make(tmp_path, origins=[ORIGIN], token="test-secret")
    client = TestClient(create_app(settings))
    return client, tmp_path


def authorized(**other):
    return {"headers": {"X-Arcside-Token": "test-secret", "Origin": ORIGIN}, **other}


def test_token_and_browser_origin_enforced(companion):
    client, _ = companion
    assert client.get("/v1/health").status_code == 401
    assert client.get("/v1/health", headers={"X-Arcside-Token": "bad"}).status_code == 401
    assert client.get("/v1/health", headers={
        "X-Arcside-Token": "test-secret", "Origin": "https://evil.example"
    }).status_code == 403
    good = client.get("/v1/health", **authorized())
    assert good.status_code == 200
    assert good.json()["ok"] is True
    assert good.json()["tools"]["python"] == sys.executable


def test_reject_parent_and_symlink_paths(companion, tmp_path):
    client, root = companion
    for path in ("../outside.py", "/tmp/outside.py", ".venv/hijack.py",
                 ".git/config", "a\\b.py"):
        result = client.post("/v1/files/sync", json={"files": {path: "print('bad')"}},
                             **authorized())
        assert result.status_code == 400, path
    (root / "link").symlink_to(root.parent, target_is_directory=True)
    response = client.post("/v1/files/sync",
                           json={"files": {"link/escape.py": "print('bad')"}},
                           **authorized())
    assert response.status_code == 400
    assert not (root.parent / "escape.py").exists()


def test_sync_and_execute_actual_local_python(companion):
    client, root = companion
    content = "import math\nprint('arcside-native-runtime', math.factorial(5))\n"
    sync = client.post("/v1/files/sync", json={"files": {"src/main.py": content}},
                       **authorized())
    assert sync.status_code == 200 and sync.json()["files"] == 1
    assert (root / "src" / "main.py").read_text() == content
    result = client.post("/v1/run", json={"entry": "src/main.py"}, **authorized())
    assert result.status_code == 200, result.text
    assert result.json()["exit_code"] == 0
    assert "arcside-native-runtime 120" in result.json()["stdout"]
    missing = client.post("/v1/run", json={"entry": "../bad.py"}, **authorized())
    assert missing.status_code == 400


def test_environment_introspection_and_git_errors(companion):
    client, root = companion
    environment = client.get("/v1/environment", **authorized())
    assert environment.status_code == 200
    assert environment.json()["details"]["python"] == sys.executable
    result = client.get("/v1/git/status", **authorized())
    assert "exit_code" in result.json()


def test_packages_require_env_and_reject_url_or_flags(companion):
    client, _ = companion
    for payload in (["-r", "requirements.txt"], ["git+https://evil.example/repo"],
                    ["../../escape"], []):
        result = client.post("/v1/environment/install",
                             json={"packages": payload}, **authorized())
        assert result.status_code == 400
    valid = client.post("/v1/environment/install",
                        json={"packages": ["numpy==2.2.4"]}, **authorized())
    assert valid.status_code == 400  # Must create explicit local environment first.
    assert PACKAGE_RE.fullmatch("pandas>=2.0")
    assert PACKAGE_RE.fullmatch("scikit-learn[extra]==1.1.0")


def test_websocket_requires_session_token_and_origin(companion):
    client, _ = companion
    with client.websocket_connect("/v1/ws/terminal", headers={"origin": ORIGIN}) as ws:
        ws.send_json({"type": "auth", "token": "wrong"})
        with pytest.raises(Exception):
            ws.receive_json()
    with pytest.raises(Exception):
        with client.websocket_connect("/v1/ws/terminal",
                                      headers={"origin": "https://evil.example"}) as ws:
            ws.receive_json()


def test_dap_message_framing_is_utf8_and_bounded():
    message = {"seq": 1, "type": "request", "command": "initialize",
               "arguments": {"clientID": "Arcside Ω"}}
    framed = write_framed(message)
    header, content = framed.split(b"\r\n\r\n", 1)
    assert int(re.search(rb"\d+", header).group()) == len(content)
    assert "Arcside Ω".encode("utf8") in content


def test_read_file_roundtrip_and_no_secret_leaks(companion):
    client, root = companion
    assert client.get("/v1/ready").json() == {"ready": True}
    source="import sys\nprint(sys.version_info.major)\n"
    assert client.post("/v1/files/sync", json={"files": {"analysis.py": source}},
                       **authorized()).status_code == 200
    response=client.post("/v1/files/read", json={"entry": "analysis.py"}, **authorized())
    assert response.status_code == 200
    assert response.json()["source"] == source
    assert "test-secret" not in str(response.json())
    assert client.post("/v1/files/read",json={"entry":"../bad.py"},
                       **authorized()).status_code == 400


def test_snippet_execution_and_native_environment_creation(companion):
    client,root=companion
    result=client.post("/v1/snippet",json={"code":"print('native-snippet', 7*7)"},
                       **authorized())
    assert result.status_code == 200
    assert "native-snippet 49" in result.json()["stdout"]
    created=client.post("/v1/environment/create",json={"manager":"venv"},**authorized())
    assert created.status_code == 200
    assert created.json()["exit_code"] == 0
    info=client.get("/v1/environment",**authorized()).json()
    assert ".venv" in info["interpreter"]
    assert client.post("/v1/environment/create",json={"manager":"venv"},
                       **authorized()).status_code == 400


def test_stop_unknown_job_is_idempotent(companion):
    client,_=companion
    result=client.post("/v1/stop",json={"job_id":"does_not_exist"},**authorized())
    assert result.status_code == 200 and result.json()["stopped"] is False


def test_native_output_is_bounded_even_for_multi_megabyte_logs(companion):
    client, _ = companion
    program = "import sys\nsys.stdout.write('x' * 2600000)\nsys.stderr.write('e' * 2700000)\n"
    response=client.post("/v1/snippet",json={"code":program},**authorized())
    assert response.status_code == 200
    result=response.json()
    assert result["exit_code"] == 0
    assert "[Arcside output truncated at 2 MB]" in result["stdout"]
    assert "[Arcside output truncated at 2 MB]" in result["stderr"]
    assert len(result["stdout"]) < 2_001_000
    assert len(result["stderr"]) < 2_001_000


def test_native_run_times_out_and_terminates_process(companion):
    client,_=companion
    response=client.post("/v1/snippet",json={
        "code":"import time\nprint('starting',flush=True)\ntime.sleep(5)\n",
        "timeout":1},**authorized())
    assert response.status_code == 200
    assert response.json()["timeout"] is True
    assert "starting" in response.json()["stdout"]
