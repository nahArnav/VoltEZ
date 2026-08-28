#!/usr/bin/env bash
set -euo pipefail

# Keep one canonical implementation. The frontend runner owns Flutter/ADB
# setup; this root entrypoint exists so teammates can run it from the repo root
# without maintaining a second copy of the networking logic.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../frontend/scripts/run_phone.sh" "$@"
