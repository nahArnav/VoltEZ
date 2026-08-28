#!/usr/bin/env bash
set -e

# ═════════════════════════════════════════════════════════════════════════════
# VoltEZ Dynamic Phone Runner & APK Builder
# ═════════════════════════════════════════════════════════════════════════════
# Automatically resolves the host machine's Wi-Fi / LAN IP, sets up ADB reverse
# port forwarding, and builds/runs the Flutter app for seamless physical phone testing.

# Resolve repository root and frontend path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -d "$REPO_ROOT/frontend" ]; then
  FRONTEND_DIR="$REPO_ROOT/frontend"
else
  FRONTEND_DIR="$REPO_ROOT"
fi

# Detect host LAN IP address
get_host_ip() {
  local ip=""
  # macOS network interfaces
  if [[ "$OSTYPE" == "darwin"* ]]; then
    for iface in en0 en1 en2 en3 pdp_ip0 bridge0; do
      ip=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
      if [[ -n "$ip" && "$ip" != "127.0.0.1" ]]; then
        echo "$ip"
        return
      fi
    done
  fi

  # Linux network interfaces
  if command -v hostname >/dev/null 2>&1; then
    ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
    if [[ -n "$ip" && "$ip" != "127.0.0.1" ]]; then
      echo "$ip"
      return
    fi
  fi

  # Fallback to localhost if no LAN IP detected
  echo "127.0.0.1"
}

HOST_IP=$(get_host_ip)
PORT="${PORT:-8000}"

# Check for flags
USE_LAN=false
if [[ "$*" == *"--lan"* || "$*" == *"--wifi"* ]]; then
  USE_LAN=true
fi

if [ "$USE_LAN" = true ]; then
  ACTIVE_HOST="$HOST_IP"
else
  ACTIVE_HOST="127.0.0.1"
fi

API_URL="http://${ACTIVE_HOST}:${PORT}/api/v1"
WS_URL="ws://${ACTIVE_HOST}:${PORT}/api/v1"

echo "========================================================"
echo "  ⚡ VoltEZ Multi-Device Phone Testing Suite ⚡"
echo "========================================================"
echo "  • Local Machine IP : $HOST_IP"
echo "  • Active Target    : $ACTIVE_HOST (Port $PORT)"
echo "  • API Base URL     : $API_URL"
echo "  • WebSocket URL    : $WS_URL"
echo "========================================================"

# Ensure environment variables for Android SDK/Java if present
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
if [ -d "$ANDROID_HOME/cmdline-tools/latest/bin" ]; then
  export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
fi

# Auto configure ADB Reverse Port Forwarding for connected devices
if command -v adb >/dev/null 2>&1; then
  echo "🔍 Checking connected ADB devices..."
  DEVICES=$(adb devices | grep -v "List" | grep "device$" | awk '{print $1}' || true)
  if [ -n "$DEVICES" ]; then
    for dev in $DEVICES; do
      echo "  📲 Setting up reverse port forward (${PORT} -> ${PORT}) on device: $dev"
      adb -s "$dev" reverse "tcp:${PORT}" "tcp:${PORT}" 2>/dev/null || true
    done
  fi
fi

cd "$FRONTEND_DIR"

if [[ "$1" == "--build-apk" || "$1" == "build" ]]; then
  echo "🔨 Building release APK with target: $API_URL..."
  flutter build apk --release \
    --dart-define=API_BASE_URL="$API_URL" \
    --dart-define=WS_BASE_URL="$WS_URL" \
    "${@:2}"
  echo "✅ APK successfully generated at: $FRONTEND_DIR/build/app/outputs/flutter-apk/app-release.apk"
else
  echo "🚀 Launching app on phone..."
  flutter run \
    --dart-define=API_BASE_URL="$API_URL" \
    --dart-define=WS_BASE_URL="$WS_URL" \
    "$@"
fi
