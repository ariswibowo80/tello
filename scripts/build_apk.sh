#!/usr/bin/env bash
# Loads .env (see .env.example) and builds the debug APK with its values
# passed through as --dart-define. Usage: ./scripts/build_apk.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "No .env found - copy .env.example to .env and fill in real values first."
  exit 1
fi

set -a
source .env
set +a

flutter build apk --debug \
  --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY:-}"
