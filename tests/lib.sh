#!/bin/bash
# Tiny helpers for tests/*.sh (bash only; no external test framework).
set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_exists() {
  [[ -f "$1" ]] || fail "missing file: $1"
}

assert_file_missing() {
  [[ ! -e "$1" ]] || fail "expected missing: $1"
}
