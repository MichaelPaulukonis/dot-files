#!/usr/bin/env bash
# Sandbox test harness for claude-sync. No network, no real $HOME touched.
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SYNC="$SCRIPT_DIR/../scripts/sync.sh"
SANDBOX=$(mktemp -d)
SANDBOX=$(readlink -f -- "$SANDBOX")
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
           "$SANDBOX/dotagents/skills" \
           "$SANDBOX/dotclaude/commands" "$SANDBOX/dotclaude/agents" \
           "$SANDBOX/dotclaude/scripts" "$SANDBOX/dotclaude/local-plugins"
  echo "custom skill" > "$SANDBOX/dotclaude/skills/my-skill/SKILL.md"
  ln -s "$SANDBOX/dotclaude/plugins/cache/some-marketplace/vendor-skill" \
        "$SANDBOX/dotclaude/skills/vendor-skill"
  ln -s "$SANDBOX/nowhere-missing" "$SANDBOX/dotclaude/skills/dangler"
  echo "global instructions" > "$SANDBOX/dotclaude/CLAUDE.md"
  echo "rtk stuff" > "$SANDBOX/dotclaude/RTK.md"
  echo '{"model":"x"}' > "$SANDBOX/dotclaude/settings.json"
  echo '{"mcpServers":{"wiki":{"command":"npx"}},"other":"junk"}' > "$SANDBOX/claude.json"
  make_repo "$SANDBOX/pub"
  make_repo "$SANDBOX/priv"
  # pre-adopted skill: lives in pub, symlinked back
  mkdir -p "$SANDBOX/pub/claude/skills/already-adopted"
  echo done > "$SANDBOX/pub/claude/skills/already-adopted/SKILL.md"
  ln -s "$SANDBOX/pub/claude/skills/already-adopted" "$SANDBOX/dotclaude/skills/already-adopted"
}

# Memory dir fixture is built separately from build_fixture() and only right
# before the Task 5 block below. Creating it up front (inside build_fixture)
# would make it prompt-visible during Tasks 1-4's interactive runs too, since
# scan_memory() (wired into main() as of Task 5) treats it as a "new" item on
# every $SYNC invocation -- silently shifting those tasks' already-committed
# printf answer sequences. Task 5's own comment ("no memory dir has been
# scanned yet") only holds if the dir doesn't exist before Task 5 runs.
build_memory_fixture() {
  mkdir -p "$SANDBOX/dotclaude/projects/-Users-me-projA/memory"
  echo "a memory" > "$SANDBOX/dotclaude/projects/-Users-me-projA/memory/fact.md"
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

# The scan log above is silent for both adopted and foreign items, so it
# can't distinguish a misclassification between the two. Assert classify()'s
# actual return value for the pre-adopted fixture directly: this is what
# catches classify() failing to canonicalize $PUBLIC_REPO/$PRIVATE_REPO
# before comparing against a readlink -f'd (fully canonical) target -- e.g.
# macOS mktemp -d paths traverse /var -> /private/var.
CLASSIFY_OUT="$SANDBOX/classify-adopted.txt"
bash -c '
  source "$1" >/dev/null 2>&1
  classify "$2"
' _ "$SYNC" "$SANDBOX/dotclaude/skills/already-adopted" >"$CLASSIFY_OUT" 2>&1
assert_grep "already-adopted classifies as adopted" "^adopted$" "$CLASSIFY_OUT"

# --- Task 2: ignore manifest ---
echo "claude/skills/my-skill" >> "$SANDBOX/pub/.sync-ignore"
OUT_FILE="$SANDBOX/out2.txt"
"$SYNC" --dry-run >"$OUT_FILE" 2>&1
assert_absent "ignored item not listed" "my-skill" "$OUT_FILE"
rm "$SANDBOX/pub/.sync-ignore"

# --- Task 3: adopt flow ---
# my-skill: answer [a]dopt. CLAUDE.md and RTK.md will also prompt: adopt CLAUDE.md, skip RTK.md.
# Prompt order follows main(): skills dir first, then CLAUDE.md, then RTK.md.
printf 'a\na\ns\n' | "$SYNC" >"$SANDBOX/out3.txt" 2>&1
assert "my-skill moved into repo" test -f "$SANDBOX/pub/claude/skills/my-skill/SKILL.md"
assert "my-skill symlinked back"  test -L "$SANDBOX/dotclaude/skills/my-skill"
assert "symlink resolves"        test -e "$SANDBOX/dotclaude/skills/my-skill/SKILL.md"
assert "CLAUDE.md adopted"       test -f "$SANDBOX/pub/claude/CLAUDE.md"
assert "RTK.md skipped"          test ! -L "$SANDBOX/dotclaude/RTK.md"
git -C "$SANDBOX/pub" diff --cached --name-only > "$SANDBOX/staged.txt"
assert_grep "my-skill staged" "claude/skills/my-skill/SKILL.md" "$SANDBOX/staged.txt"

# secret scan: plant a fake AWS key, answer adopt then refuse override then skip
mkdir -p "$SANDBOX/dotclaude/skills/leaky"
echo 'aws_key = "AKIAIOSFODNN7EXAMPLE"' > "$SANDBOX/dotclaude/skills/leaky/SKILL.md"
printf 'a\nno\ns\ns\n' | "$SYNC" >"$SANDBOX/out4.txt" 2>&1
assert "leaky not adopted" test ! -L "$SANDBOX/dotclaude/skills/leaky"
assert_grep "secret warning shown" "possible secrets" "$SANDBOX/out4.txt"

# ignore-forever answer
printf 'i\ns\n' | "$SYNC" >"$SANDBOX/out5.txt" 2>&1
assert_grep "leaky in ignore manifest" "claude/skills/leaky" "$SANDBOX/pub/.sync-ignore"

# --- Task 3 fix: adopt() rollback safety ---
# Unit-test adopt() directly (same pattern as the classify() unit test above)
# with a fake `ln` shadowing the real one on PATH so the symlink-back step
# fails after the mv has already succeeded. Proves the mv is rolled back
# instead of leaving the item stranded, untracked, inside the repo.
mkdir -p "$SANDBOX/dotclaude/skills/rollback-test"
echo "rollback me" > "$SANDBOX/dotclaude/skills/rollback-test/SKILL.md"
FAKEBIN="$SANDBOX/fakebin"
mkdir -p "$FAKEBIN"
printf '#!/usr/bin/env bash\nexit 1\n' > "$FAKEBIN/ln"
chmod +x "$FAKEBIN/ln"
ROLLBACK_OUT="$SANDBOX/rollback.txt"
PATH="$FAKEBIN:$PATH" bash -c '
  source "$1" >/dev/null 2>&1
  adopt "$2" "$3" "$4"
' _ "$SYNC" "$SANDBOX/dotclaude/skills/rollback-test" "$SANDBOX/pub" "claude/skills/rollback-test" \
  </dev/null >"$ROLLBACK_OUT" 2>&1
RC=$?
assert "adopt() rollback restores source item" test -f "$SANDBOX/dotclaude/skills/rollback-test/SKILL.md"
assert "adopt() rollback leaves nothing in repo" test ! -e "$SANDBOX/pub/claude/skills/rollback-test"
assert "adopt() reports failure on rollback" test "$RC" -ne 0
assert_grep "adopt() rollback warning shown" "adopt failed" "$ROLLBACK_OUT"

# rollback-test above was created directly under dotclaude/skills and only
# exercised via adopt() called directly (not through $SYNC), so it was never
# adopted, ignored, or removed. Left in place it's a real, unadopted,
# non-ignored item that later $SYNC subprocess runs would classify as fresh
# "new" -- silently shifting every subsequent interactive prompt by one and
# drifting later tasks' plan-assumed printf sequences. Clean it up so the
# sandbox matches what later tasks assume.
rm -rf "$SANDBOX/dotclaude/skills/rollback-test"

# --- Important fix: broadened secret regex ---
# Unit-test secret_scan() directly against the case the reviewer flagged as
# missed: an uppercase, unquoted .env-style assignment.
echo 'API_KEY=abcdefgh12345678' > "$SANDBOX/envsecret-src.txt"
ENVSECRET_OUT="$SANDBOX/envsecret.txt"
bash -c '
  source "$1" >/dev/null 2>&1
  secret_scan "$2"
' _ "$SYNC" "$SANDBOX/envsecret-src.txt" </dev/null >"$ENVSECRET_OUT" 2>&1
RC=$?
assert "uppercase unquoted API_KEY caught" test "$RC" -eq 1
assert_grep "uppercase unquoted API_KEY warned" "possible secrets" "$ENVSECRET_OUT"


# --- Task 4: copy-sync ---
# Remaining prompts at this point: leaky is ignored, RTK.md still new.
# Answers: s (RTK.md), a (settings.json first copy), a (mcp extract first copy)
printf 's\na\na\n' | "$SYNC" >"$SANDBOX/out6.txt" 2>&1
assert "settings copied"  test -f "$SANDBOX/priv/claude/settings.json"
assert "settings not symlink at source" test ! -L "$SANDBOX/dotclaude/settings.json"
assert "mcp extract exists" test -f "$SANDBOX/priv/claude/mcp-servers.json"
assert_absent "mcp extract drops other keys" '"other"' "$SANDBOX/priv/claude/mcp-servers.json"
assert_grep "mcp extract has servers" '"wiki"' "$SANDBOX/priv/claude/mcp-servers.json"

# change source, re-run: should show diff and update without prompting
echo '{"model":"y"}' > "$SANDBOX/dotclaude/settings.json"
printf 's\n' | "$SYNC" >"$SANDBOX/out7.txt" 2>&1
assert_grep "diff shown" "CHANGED: claude/settings.json" "$SANDBOX/out7.txt"
assert_grep "copy updated" '"y"' "$SANDBOX/priv/claude/settings.json"

# --- Task 4 fix: sync_mcp_servers must not clobber the tracked extract when
# claude.json is empty (e.g. crash mid-write). jq's documented behavior on
# empty input is "no output, exit 0" -- not a parse error -- so this can't
# rely on `set -e`; it needs an explicit empty-output guard. RTK.md is still
# the only remaining interactive item, hence the single 's' answer.
cp "$SANDBOX/priv/claude/mcp-servers.json" "$SANDBOX/mcp-servers-before.json"
: > "$SANDBOX/claude.json"
printf 's\n' | "$SYNC" >"$SANDBOX/out8.txt" 2>&1
assert_grep "empty claude.json warned" "produced no/empty output" "$SANDBOX/out8.txt"
assert "mcp extract untouched on empty input" cmp -s "$SANDBOX/mcp-servers-before.json" "$SANDBOX/priv/claude/mcp-servers.json"

# --- Task 5: memory dirs ---
# Remaining prompts: RTK.md (s), memory dir (a)
build_memory_fixture
printf 's\na\n' | "$SYNC" >"$SANDBOX/out9.txt" 2>&1
assert "memory moved to private" test -f "$SANDBOX/priv/claude/projects/-Users-me-projA/memory/fact.md"
assert "memory symlinked back"   test -L "$SANDBOX/dotclaude/projects/-Users-me-projA/memory"
assert "memory writes flow through" bash -c "echo new > '$SANDBOX/dotclaude/projects/-Users-me-projA/memory/new.md' && test -f '$SANDBOX/priv/claude/projects/-Users-me-projA/memory/new.md'"

# --- Task 6: finish + idempotence ---
# Adopt RTK.md (last new item), then answer n to both commit prompts
printf 'a\nn\nn\n' | "$SYNC" >"$SANDBOX/out10.txt" 2>&1
assert_grep "status header pub"  "=== $SANDBOX/pub ===" "$SANDBOX/out10.txt"
assert_grep "status header priv" "=== $SANDBOX/priv ===" "$SANDBOX/out10.txt"
assert_grep "commit offered" "commit all changes" "$SANDBOX/out10.txt"

# everything adopted or ignored: a fresh run must make NO prompts (stdin closed)
"$SYNC" </dev/null >"$SANDBOX/out11.txt" 2>&1; RC=$?
assert "idempotent run exits 0" test "$RC" -eq 0
assert_absent "idempotent run finds no NEW" "^NEW" "$SANDBOX/out11.txt"

# --- Task 6 fix: a commit failure in one repo must not abort finish_repo for
# the other. Simulate a hook rejection (e.g. the not-yet-built gitleaks hook
# from Task 9, whose entire purpose is to make some commits fail) via a
# pre-commit hook that always exits 1, dropped into pub/.git/hooks -- same
# fake-binary spirit as the adopt() rollback test above. pub and priv both
# still have uncommitted changes staged from the "n\nn" decline above.
mkdir -p "$SANDBOX/pub/.git/hooks"
printf '#!/usr/bin/env bash\nexit 1\n' > "$SANDBOX/pub/.git/hooks/pre-commit"
chmod +x "$SANDBOX/pub/.git/hooks/pre-commit"
printf 'y\nn\n' | "$SYNC" >"$SANDBOX/out12.txt" 2>&1; RC=$?
assert "script survives a commit failure" test "$RC" -eq 0
assert_grep "commit failure logged" "commit failed in $SANDBOX/pub" "$SANDBOX/out12.txt"
assert_grep "priv finish still ran after pub commit failure" "=== $SANDBOX/priv ===" "$SANDBOX/out12.txt"
rm -f "$SANDBOX/pub/.git/hooks/pre-commit"

echo ""
echo "PASS: $PASS FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
