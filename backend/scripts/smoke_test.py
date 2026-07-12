from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from typing import Any
from uuid import uuid4

BASE_URL = sys.argv[1].rstrip('/') if len(sys.argv) > 1 else 'http://127.0.0.1:8000'


def request(method: str, path: str, payload: dict[str, Any] | None = None) -> Any:
    data = None if payload is None else json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        f'{BASE_URL}{path}',
        data=data,
        method=method,
        headers={'content-type': 'application/json'},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            body = response.read().decode('utf-8')
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as exc:
        body = exc.read().decode('utf-8')
        raise RuntimeError(f'{method} {path} failed: {exc.code} {body}') from exc


def main() -> None:
    suffix = uuid4().hex[:8]
    print('health:', request('GET', '/health'))
    user = request('POST', '/users', {'email': f'demo-{suffix}@sportsterminal.local', 'display_name': 'Demo User', 'role': 'admin'})
    user_id = user['id']
    print('created user:', user_id)
    print('favorite teams:', request('POST', f'/users/{user_id}/favorite-teams', {'item_id': 'OKC'}))
    print('watchlist:', request('POST', f'/users/{user_id}/watchlist', {'player_id': 'jokicni01', 'source': 'smoke_test'}))
    workbook = request('POST', '/workbooks', {'owner_user_id': user_id, 'title': 'Smoke Test Workbook'})
    print('workbook:', workbook['id'])
    print('cell update:', request('PUT', f"/workbooks/{workbook['id']}/cells", {'sheet': 'Sheet 1', 'cell_ref': 'A1', 'raw_value': 'Sports Terminal'}))
    post = request('POST', '/community/posts', {'author_user_id': user_id, 'board': 'Product Feedback', 'title': 'Smoke test post', 'body': 'Backend smoke test succeeded.'})
    print('post:', post['id'])
    print('readiness:', request('GET', '/launch/readiness')['status'])


if __name__ == '__main__':
    main()
