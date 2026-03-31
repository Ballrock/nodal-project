#!/usr/bin/env bash
# Sert les screenshots E2E via une galerie HTML locale.
# Usage : ./serve_screenshots.sh [port]
# Par defaut le port est 8899.

set -euo pipefail

PORT="${1:-8899}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCREENSHOTS_DIR="$SCRIPT_DIR/tests/e2e/screenshots"

# Trouver le dossier de screenshots le plus recent
LATEST_DIR=$(ls -td "$SCREENSHOTS_DIR"/*/ 2>/dev/null | head -1)

if [ -z "$LATEST_DIR" ]; then
    echo "Aucun screenshot trouve dans $SCREENSHOTS_DIR"
    exit 1
fi

# IP locale
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")

echo "=== Galerie de screenshots E2E ==="
echo "Dossier : $LATEST_DIR"
echo ""
echo "Acces local :  http://localhost:$PORT/"
echo "Acces reseau : http://$LOCAL_IP:$PORT/"
echo ""
echo "Ctrl+C pour arreter."
echo "==================================="

cd "$LATEST_DIR"
exec python3 "$SCRIPT_DIR/serve_screenshots.py" "$PORT"
