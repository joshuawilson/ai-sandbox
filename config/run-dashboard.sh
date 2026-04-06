#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_SANDBOX_DASHBOARD_TOKEN="${AI_SANDBOX_DASHBOARD_TOKEN:?Set AI_SANDBOX_DASHBOARD_TOKEN for the API}"
exec python3 -m uvicorn dashboard:app --host 127.0.0.1 --port "${PORT:-8080}" --app-dir "$DIR"
