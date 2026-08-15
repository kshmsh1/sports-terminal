from __future__ import annotations

from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    source = (root / "app" / "environment_promotion_api.py").read_text(encoding="utf-8")
    authorization = (root / "app" / "authorization_guard.py").read_text(encoding="utf-8")
    assert 'prefix="/v2/operations/environments"' in source
    assert '@router.post("/promote")' in source
    assert '@router.post("/{environment}/healthy")' in source
    assert "EnvironmentPromotionService().promote" in source
    assert "EnvironmentPromotionService().mark_healthy" in source
    assert '"/v2/operations/"' in authorization
    assert "Platform administrator access is required" in authorization
    print("environment_promotion_api_contract: PASS")


if __name__ == "__main__":
    main()
