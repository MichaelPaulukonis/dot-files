#!/usr/bin/env bash
# Sandbox test harness for claude-sync. No network, no real $HOME touched.
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SYNC="$SCRIPT_DIR/../scripts/sync.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
PASS=0; FAIL=0

assert() { # assert <label> <command...>
  local label=$1; shift
  if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $label"; fi
}
assert_grep() { # assert_grep <label> <pattern> <file>
  local label=$1 pattern=$2 file=$3
  if grep -qE "$pattern" "$file" 2>/dev/null; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $label"; fi
}

export CLAUDE_SYNC_CLAUDE_DIR="$SANDBOX/dotclaude"
export CLAUDE_SYNC_AGENTS_DIR="$SANDBOX/dotagents"
export CLAUDE_SYNC_CLAUDE_JSON="$SANDBOX/claude.json"
export CLAUDE_SYNC_PUBLIC="$SANDBOX/pub"
export CLAUDE_SYNC_PRIVATE="$SANDBOX/priv"

make_repo() {
  git init -q "$1"
  git -C "$1" config user.name test
  git -C "$1" config user.email test@test
  git -C "$1" commit -q --allow-empty -m init
}

build_fixture() {
  mkdir -p "$SANDBOX/dotclaude/skills/my-skill" \
           "$SANDBOX/dotclaude/plugins/cache/some-marketplace/vendor-skill" \
           "$SANDBOX/dotclaude/projects/-Users-me-projA/memory" \
           "$SANDBOX/dotagents/skills" \
           "$SANDBOX/dotclaude/commands" "$SANDBOX/dotclaude/agents" \
           "$SANDBOX/dotclaude/scripts" "$SANDBOX/dotclaude/local-plugins"
  echo "custom skill" > "$SANDBOX/dotclaude/skills/my-skill/SKILL.md"
  ln -s "$SANDBOX/dotclaude/plugins/cache/some-marketplace/vendor-skill" \
        "$SANDBOX/dotclaude/skills/vendor-skill"
  ln -s "$SANDBOX/nowhere-missing" "$SANDBOX/dotclaude/skills/dangler"
  echo "global instructions" > "$SANDBOX/dotclaude/CLAUDE.md"
  echo "rtk stuff" > "$SANDBOX/dotclaude/RTK.md"
  echo "a memory" > "$SANDBOX/dotclaude/projects/-Users-me-projA/memory/fact.md"
  echo '{"model":"x"}' > "$SANDBOX/dotclaude/settings.json"
  echo '{"mcpServers":{"wiki":{"command":"npx"}},"other":"junk"}' > "$SANDBOX/claude.json"
  make_repo "$SANDBOX/pub"
  make_repo "$SANDBOX/priv"
  # pre-adopted skill: lives in pub, symlinked back
  mkdir -p "$SANDBOX/pub/claude/skills/already-adopted"
  echo done > "$SANDBOX/pub/claude/skills/already-adopted/SKILL.md"
  ln -s "$SANDBOX/pub/claude/skills/already-adopted" "$SANDBOX/dotclaude/skills/already-adopted"
}

build_fixture

# --- Task 1: dry-run classification ---
# assert_absent <label> <pattern> <file>: passes when pattern NOT in file
assert_absent() {
  local label=$1 pattern=$2 file=$3
  if grep -qE "$pattern" "$file" 2>/dev/null; then FAIL=$((FAIL+1)); echo "FAIL: $label"; else PASS=$((PASS+1)); fi
}

OUT_FILE="$SANDBOX/out1.txt"
"$SYNC" --dry-run >"$OUT_FILE" 2>&1; RC=$?
assert "dry-run exits 0" test "$RC" -eq 0
assert_grep   "new skill listed"      "NEW: .*my-skill"    "$OUT_FILE"
assert_absent "vendor not listed"     "vendor-skill"       "$OUT_FILE"
assert_absent "adopted not listed"    "already-adopted"    "$OUT_FILE"
assert_grep   "dangling warned"       "WARN: dangling"     "$OUT_FILE"

echo ""
echo "PASS: $PASS FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
