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

# The deployed Render API is the safe default. Local modes stay explicit so a
# release APK never silently points at the phone's own loopback interface.
DEPLOYED_SERVER="https://voltez-sb0w.onrender.com"
USE_LAN=false
USE_LOCAL=false
BUILD_APK=false
CUSTOM_SERVER="${SERVER_URL:-}"
FLUTTER_ARGS=()

while (($#)); do
  case "$1" in
    --lan|--wifi)
      USE_LAN=true
      shift
      ;;
    --local|--usb)
      USE_LOCAL=true
      shift
      ;;
    --server|--render|--url)
      if (($# < 2)); then
        echo "Missing URL after $1" >&2
        exit 2
      fi
      CUSTOM_SERVER="$2"
      shift 2
      ;;
    --server=*|--render=*|--url=*)
      CUSTOM_SERVER="${1#*=}"
      shift
      ;;
    --build-apk|build)
      BUILD_APK=true
      shift
      ;;
    *)
      FLUTTER_ARGS+=("$1")
      shift
      ;;
  esac
done

if [ -n "$CUSTOM_SERVER" ]; then
  CUSTOM_SERVER="${CUSTOM_SERVER%/}"
  if [[ "$CUSTOM_SERVER" != http* ]]; then
    CUSTOM_SERVER="https://$CUSTOM_SERVER"
  fi
  if [[ "$CUSTOM_SERVER" != */api/v1 ]]; then
    API_URL="${CUSTOM_SERVER}/api/v1"
  else
    API_URL="$CUSTOM_SERVER"
  fi
  if [[ "$API_URL" == https* ]]; then
    WS_URL="${API_URL/https:\/\//wss:\/\/}"
  else
    WS_URL="${API_URL/http:\/\//ws:\/\/}"
  fi
  ACTIVE_HOST="$CUSTOM_SERVER"
elif [ "$USE_LAN" = true ]; then
  ACTIVE_HOST="$HOST_IP"
  API_URL="http://${ACTIVE_HOST}:${PORT}/api/v1"
  WS_URL="ws://${ACTIVE_HOST}:${PORT}/api/v1"
elif [ "$USE_LOCAL" = true ]; then
  ACTIVE_HOST="127.0.0.1"
  API_URL="http://${ACTIVE_HOST}:${PORT}/api/v1"
  WS_URL="ws://${ACTIVE_HOST}:${PORT}/api/v1"
else
  ACTIVE_HOST="$DEPLOYED_SERVER"
  API_URL="${DEPLOYED_SERVER}/api/v1"
  WS_URL="wss://voltez-sb0w.onrender.com/api/v1"
fi


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

if [ "$BUILD_APK" = true ]; then
  echo "🔨 Building release APK with target: $API_URL..."
  flutter build apk --release \
    --dart-define=API_BASE_URL="$API_URL" \
    --dart-define=WS_BASE_URL="$WS_URL" \
    "${FLUTTER_ARGS[@]}"
  echo "✅ APK successfully generated at: $FRONTEND_DIR/build/app/outputs/flutter-apk/app-release.apk"
else
  echo "🚀 Launching app on phone..."
  flutter run \
    --dart-define=API_BASE_URL="$API_URL" \
    --dart-define=WS_BASE_URL="$WS_URL" \
    "${FLUTTER_ARGS[@]}"
fi
