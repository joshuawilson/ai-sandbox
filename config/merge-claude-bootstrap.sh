#!/bin/bash
# Merge host-backed MCP fragments into ~/.claude.json and copy personal skills into ~/.claude/skills/.
# Intended to run inside the guest (paths use $HOME). See config/claude-bootstrap/ and spec/how/runtime.md.
set -euo pipefail

SANDBOX="${1:?usage: merge-claude-bootstrap.sh /path/to/ai-sandbox}"

BOOT="$SANDBOX/config/claude-bootstrap"
BOOT_WS_PRIVATE="$SANDBOX/workspace/.ai-sandbox-private/claude-bootstrap"
SECRETS_MCP="$SANDBOX/secrets/claude-mcp.json"
CLAUDE_JSON="${HOME}/.claude.json"
SKILLS_SRC="$BOOT/skills"
SKILLS_PRIVATE="$BOOT_WS_PRIVATE/skills"
SKILLS_DST="${HOME}/.claude/skills"

mkdir -p "${HOME}/.claude"

FRAGMENTS=()
if [[ -f "$BOOT/mcp.json" ]]; then
  FRAGMENTS+=("$BOOT/mcp.json")
fi
if [[ -f "$BOOT_WS_PRIVATE/mcp.json" ]]; then
  FRAGMENTS+=("$BOOT_WS_PRIVATE/mcp.json")
fi
if [[ -f "$SECRETS_MCP" ]]; then
  FRAGMENTS+=("$SECRETS_MCP")
fi

if [[ ${#FRAGMENTS[@]} -gt 0 ]]; then
  python3 - "$CLAUDE_JSON" "${FRAGMENTS[@]}" <<'PY'
import json, sys, os

path = sys.argv[1]
frag_paths = sys.argv[2:]

data = {}
if os.path.isfile(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

mcp = data.get("mcpServers")
if not isinstance(mcp, dict):
    mcp = {}

for fp in frag_paths:
    with open(fp, encoding="utf-8") as f:
        frag = json.load(f)
    servers = frag.get("mcpServers")
    if not isinstance(servers, dict):
        continue
    mcp.update(servers)

data["mcpServers"] = mcp

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
  echo "Merged MCP servers from host into ${CLAUDE_JSON} (${#FRAGMENTS[@]} fragment(s))."
fi

# Copy when at least one SKILL.md exists (personal skills are directories under ~/.claude/skills/).
# Order: committed config/claude-bootstrap/skills, then workspace/.ai-sandbox-private/... (overlays).
_copy_skills_tree() {
  local src="$1"
  local skill_md
  [[ -d "$src" ]] || return 0
  skill_md=$(find "$src" -name 'SKILL.md' -print -quit)
  [[ -n "$skill_md" ]] || return 0
  mkdir -p "$SKILLS_DST"
  cp -a "$src"/. "$SKILLS_DST"/
  echo "Copied skills from ${src} to ${SKILLS_DST}."
}
if [[ -d "$SKILLS_SRC" ]]; then
  _copy_skills_tree "$SKILLS_SRC"
fi
if [[ -d "$SKILLS_PRIVATE" ]]; then
  _copy_skills_tree "$SKILLS_PRIVATE"
fi
