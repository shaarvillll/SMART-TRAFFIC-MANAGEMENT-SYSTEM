#!/usr/bin/env bash
# ============================================================
#  Smart Traffic Simulator — macOS Launch Script
#  Connects to the deployed backend at Render.
# ============================================================
set -e

BACKEND_URL="${BACKEND_URL:-https://smart-traffic-management-system-xtar.onrender.com}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SIM_DIR="$SCRIPT_DIR/traffic_simulation"

echo "========================================================"
echo "  Smart Traffic Simulator (JavaFX Desktop)"
echo "  Backend: $BACKEND_URL"
echo "========================================================"

# Build if target/classes or fat jar does not exist
cd "$SIM_DIR"
if [ ! -f "traffic-desktop/target/traffic-desktop-1.0.0-SNAPSHOT.jar" ]; then
  echo "[Build] Compiling — this only runs once..."
  mvn clean package -pl traffic-core,traffic-desktop -am -DskipTests -q
  echo "[Build] Done."
fi

JAR="$SIM_DIR/traffic-desktop/target/traffic-desktop-1.0.0-SNAPSHOT.jar"

# Detect Java 17+ (required for JavaFX)
JAVA_BIN="$(which java 2>/dev/null || echo "")"
if [ -z "$JAVA_BIN" ]; then
  echo "[Error] Java not found. Install Java 17+ from https://adoptium.net"
  exit 1
fi

JAVA_VERSION=$("$JAVA_BIN" -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)
if [ "$JAVA_VERSION" -lt 17 ] 2>/dev/null; then
  echo "[Error] Java 17+ required. Found: $JAVA_VERSION"
  exit 1
fi

echo "[Launch] Starting simulator..."
"$JAVA_BIN" \
  --enable-native-access=ALL-UNNAMED \
  -DBACKEND_URL="$BACKEND_URL" \
  -jar "$JAR"
