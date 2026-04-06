#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FP="$ROOT/config/first-project-name.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export SANDBOX="$tmp"
mkdir -p "$tmp/workspace"

out=$("$FP")
[[ "$out" == "default" ]] || fail "empty workspace: want default got '$out'"

mkdir -p "$tmp/workspace/zebra" "$tmp/workspace/alpha"
out=$("$FP")
[[ "$out" == "alpha" ]] || fail "alpha+zebra: want alpha got '$out'"

rm -rf "$tmp/workspace/alpha" "$tmp/workspace/zebra"
mkdir -p "$tmp/workspace/solo"
out=$("$FP")
[[ "$out" == "solo" ]] || fail "solo: want solo got '$out'"

echo "  first-project-name: ok"
