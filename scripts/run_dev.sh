#!/usr/bin/env bash
# Loads .env (see .env.example) and runs the app with its values passed
# through as --dart-define. Usage: ./scripts/run_dev.sh [extra flutter run args]
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "No .env found - copy .env.example to .env and fill in real values first."
  exit 1
fi

set -a
source .env
set +a

flutter run \
  --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY:-}" \
  "$@"
