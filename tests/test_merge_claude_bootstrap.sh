#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib.sh
source "$ROOT/tests/lib.sh"

MERGE="$ROOT/config/merge-claude-bootstrap.sh"

echo "  merge: second fragment overrides duplicate server name"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME/.claude"
SANDBOX="$tmp/sandbox"
mkdir -p "$SANDBOX/config/claude-bootstrap" "$SANDBOX/secrets"

cat > "$SANDBOX/config/claude-bootstrap/mcp.json" <<'JSON'
{"mcpServers":{"srv":{"type":"http","url":"http://first"}}}
JSON
cat > "$SANDBOX/secrets/claude-mcp.json" <<'JSON'
{"mcpServers":{"srv":{"type":"http","url":"http://second"}}}
JSON

"$MERGE" "$SANDBOX"

python3 - <<PY
import json
with open("$HOME/.claude.json") as f:
    d = json.load(f)
assert d["mcpServers"]["srv"]["url"] == "http://second", d
PY

echo "  merge: preserves unrelated keys in existing ~/.claude.json"
rm -rf "$HOME"
mkdir -p "$HOME/.claude"
printf '%s\n' '{"oauth":{"x":1},"mcpServers":{"old":{"type":"http","url":"http://old"}}}' >"$HOME/.claude.json"
rm -f "$SANDBOX/secrets/claude-mcp.json"
cat > "$SANDBOX/config/claude-bootstrap/mcp.json" <<'JSON'
{"mcpServers":{"new":{"type":"http","url":"http://new"}}}
JSON

"$MERGE" "$SANDBOX"

python3 - <<PY
import json
with open("$HOME/.claude.json") as f:
    d = json.load(f)
assert d.get("oauth") == {"x": 1}
assert "old" in d["mcpServers"] and "new" in d["mcpServers"]
PY

echo "  merge: workspace/.ai-sandbox-private/claude-bootstrap/mcp.json merged; secrets wins on duplicate name"
rm -rf "$HOME" "$SANDBOX"
export HOME="$tmp/home_ws"
mkdir -p "$HOME/.claude"
SANDBOX="$tmp/sandbox_ws"
mkdir -p "$SANDBOX/config/claude-bootstrap" "$SANDBOX/workspace/.ai-sandbox-private/claude-bootstrap" "$SANDBOX/secrets"
printf '%s\n' '{"mcpServers":{"dup":{"type":"http","url":"http://from-boot"}}}' >"$SANDBOX/config/claude-bootstrap/mcp.json"
printf '%s\n' '{"mcpServers":{"dup":{"type":"http","url":"http://from-workspace"},"onlyws":{"type":"http","url":"http://ws-only"}}}' >"$SANDBOX/workspace/.ai-sandbox-private/claude-bootstrap/mcp.json"
printf '%s\n' '{"mcpServers":{"dup":{"type":"http","url":"http://from-secrets"}}}' >"$SANDBOX/secrets/claude-mcp.json"

"$MERGE" "$SANDBOX"

python3 - <<PY
import json
with open("$HOME/.claude.json") as f:
    d = json.load(f)
m = d["mcpServers"]
assert m["dup"]["url"] == "http://from-secrets", m
assert m["onlyws"]["url"] == "http://ws-only", m
PY

echo "  merge: copies skills when SKILL.md present"
rm -rf "$HOME" "$SANDBOX"
export HOME="$tmp/home2"
mkdir -p "$HOME/.claude"
SANDBOX="$tmp/sandbox_sk"
mkdir -p "$SANDBOX/config/claude-bootstrap/skills/ex"
printf '%s\n' '---' 'name: ex' '---' >"$SANDBOX/config/claude-bootstrap/skills/ex/SKILL.md"

"$MERGE" "$SANDBOX"

assert_file_exists "$HOME/.claude/skills/ex/SKILL.md"

echo "  merge: no mcp fragments and no SKILL.md — no claude.json, no skills copy"
rm -rf "$HOME" "$SANDBOX"
export HOME="$tmp/home3"
mkdir -p "$HOME/.claude"
SANDBOX="$tmp/sandbox_empty"
mkdir -p "$SANDBOX/config/claude-bootstrap/skills"

"$MERGE" "$SANDBOX"

assert_file_missing "$HOME/.claude.json"
assert_file_missing "$HOME/.claude/skills"

echo "  merge-claude-bootstrap: ok"
