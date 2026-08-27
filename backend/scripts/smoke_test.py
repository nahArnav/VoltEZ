"""
VoltEZ Smoke Test

Quick health check for the running API.
Run: python scripts/smoke_test.py [BASE_URL]
Default BASE_URL: http://localhost:8000
"""

import sys
import httpx


def main():
    base_url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"
    print(f"🔍 Running smoke tests against {base_url}\n")

    endpoints = [
        ("/health/live", "Liveness"),
        ("/health/ready", "Readiness"),
        ("/version", "Version"),
        ("/api/v1/openapi.json", "OpenAPI contract"),
    ]

    passed = 0
    failed = 0

    for path, name in endpoints:
        try:
            response = httpx.get(f"{base_url}{path}", timeout=5.0)
            if response.status_code == 200:
                print(f"  ✅ {name:20s} → {response.status_code} {response.json()}")
                passed += 1
            else:
                print(f"  ❌ {name:20s} → {response.status_code}")
                failed += 1
        except httpx.ConnectError:
            print(f"  ❌ {name:20s} → Connection refused (is the server running?)")
            failed += 1
        except Exception as e:
            print(f"  ❌ {name:20s} → Error: {e}")
            failed += 1

    print(f"\n{'='*50}")
    print(f"Results: {passed} passed, {failed} failed out of {len(endpoints)}")

    if failed > 0:
        print("❌ Smoke test FAILED")
        sys.exit(1)
    else:
        print("✅ All smoke tests PASSED")
        sys.exit(0)


if __name__ == "__main__":
    main()
