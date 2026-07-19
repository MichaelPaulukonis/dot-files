# claude-sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `claude-sync`, a discover-prompt-adopt backup tool for custom Claude Code config, per the approved spec at `docs/specs/2026-07-18-claude-sync-design.md`.

**Architecture:** Single bash script (`sync.sh`) with all source roots and repo destinations overridable via env vars, so a sandbox test harness can exercise every behavior in a temp dir. A SKILL.md wrapper makes it invocable from Claude Code. Symlink-adopt for editable content, copy-sync for rename-written files, two destination repos (public dot-files, private claude-private).

**Tech Stack:** bash, git, jq, gitleaks (pre-commit hooks), gh CLI (private repo creation).

**Working directory:** `~/projects/dot-files` on `main` - no worktree. Adopted symlinks must resolve to the canonical repo path; a worktree copy would produce wrong symlink targets.

**Testing approach:** `tests/test-sync.sh` builds a sandbox fixture in `mktemp -d` (fake `.claude`, fake repos), runs `sync.sh` with env overrides and piped answers, asserts outcomes. Each task adds failing asserts first, then implements. Run with: `bash claude/skills/claude-sync/tests/test-sync.sh` - prints `PASS: n FAIL: 0` on success, exits nonzero on failure.

---

### Task 1: Script skeleton, classify(), test harness base

**Files:**
- Create: `claude/skills/claude-sync/scripts/sync.sh`
- Create: `claude/skills/claude-sync/tests/test-sync.sh`

- [ ] **Step 1: Write test harness with classify asserts**

`claude/skills/claude-sync/tests/test-sync.sh`:

```bash
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
```

All later task asserts get inserted BEFORE the final three summary lines. Use `assert_absent` wherever a pattern must NOT appear (never `assert "x" ! grep ...` - bash won't negate through `"$@"`).

- [ ] **Step 2: Run test, verify it fails**

Run: `bash claude/skills/claude-sync/tests/test-sync.sh`
Expected: FAIL lines (sync.sh does not exist yet), nonzero exit.

- [ ] **Step 3: Write sync.sh skeleton with classify and dry-run scan**

`claude/skills/claude-sync/scripts/sync.sh`:

```bash
#!/usr/bin/env bash
# claude-sync: back up custom Claude Code config into version control.
# Spec: docs/specs/2026-07-18-claude-sync-design.md
set -euo pipefail

CLAUDE_DIR="${CLAUDE_SYNC_CLAUDE_DIR:-$HOME/.claude}"
AGENTS_DIR="${CLAUDE_SYNC_AGENTS_DIR:-$HOME/.agents}"
CLAUDE_JSON="${CLAUDE_SYNC_CLAUDE_JSON:-$HOME/.claude.json}"
PUBLIC_REPO="${CLAUDE_SYNC_PUBLIC:-$HOME/projects/dot-files}"
PRIVATE_REPO="${CLAUDE_SYNC_PRIVATE:-$HOME/projects/claude-private}"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

log() { printf '%s\n' "$*"; }

# classify <path> -> adopted | foreign | dangling | new
classify() {
  local p=$1 target
  if [[ -L $p ]]; then
    target=$(readlink -f -- "$p" 2>/dev/null) || target=""
    if [[ -z $target || ! -e $target ]]; then
      echo dangling; return
    fi
    case $target in
      "$PUBLIC_REPO"/*|"$PRIVATE_REPO"/*) echo adopted ;;
      *) echo foreign ;;
    esac
  else
    echo new
  fi
}

# handle_adopt_item <src> <repo> <rel>
handle_adopt_item() {
  local src=$1 repo=$2 rel=$3
  [[ -e $src || -L $src ]] || return 0
  case $(classify "$src") in
    adopted|foreign) ;;
    dangling) log "WARN: dangling symlink: $src" ;;
    new)
      log "NEW: $src -> $repo/$rel"
      ;;
  esac
}

# scan_adopt_dir <dir> <repo> <relbase>
scan_adopt_dir() {
  local dir=$1 repo=$2 relbase=$3 item name
  [[ -d $dir ]] || return 0
  for item in "$dir"/*; do
    [[ -e $item || -L $item ]] || continue
    name=$(basename "$item")
    [[ $name == .DS_Store ]] && continue
    handle_adopt_item "$item" "$repo" "$relbase/$name"
  done
}

main() {
  scan_adopt_dir "$CLAUDE_DIR/skills"        "$PUBLIC_REPO" "claude/skills"
  scan_adopt_dir "$CLAUDE_DIR/commands"      "$PUBLIC_REPO" "claude/commands"
  scan_adopt_dir "$CLAUDE_DIR/agents"        "$PUBLIC_REPO" "claude/agents"
  scan_adopt_dir "$CLAUDE_DIR/scripts"       "$PUBLIC_REPO" "claude/scripts"
  scan_adopt_dir "$CLAUDE_DIR/local-plugins" "$PUBLIC_REPO" "claude/local-plugins"
  scan_adopt_dir "$AGENTS_DIR/skills"        "$PUBLIC_REPO" "agents/skills"
  handle_adopt_item "$CLAUDE_DIR/CLAUDE.md"  "$PUBLIC_REPO" "claude/CLAUDE.md"
  handle_adopt_item "$CLAUDE_DIR/RTK.md"     "$PUBLIC_REPO" "claude/RTK.md"
}
main
```

`chmod +x claude/skills/claude-sync/scripts/sync.sh`

- [ ] **Step 4: Run test, verify it passes**

Run: `bash claude/skills/claude-sync/tests/test-sync.sh`
Expected: `PASS: 5 FAIL: 0`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add claude/skills/claude-sync
git commit -m "feat(claude-sync): skeleton with classification and dry-run scan"
```

---

### Task 2: Ignore manifest

**Files:**
- Modify: `claude/skills/claude-sync/scripts/sync.sh`
- Modify: `claude/skills/claude-sync/tests/test-sync.sh`

- [ ] **Step 1: Add failing asserts**

Append to test file before the summary lines:

```bash
# --- Task 2: ignore manifest ---
echo "claude/skills/my-skill" >> "$SANDBOX/pub/.sync-ignore"
OUT_FILE="$SANDBOX/out2.txt"
"$SYNC" --dry-run >"$OUT_FILE" 2>&1
assert_absent "ignored item not listed" "my-skill" "$OUT_FILE"
rm "$SANDBOX/pub/.sync-ignore"
```

- [ ] **Step 2: Run test, verify new assert fails**

Run: `bash claude/skills/claude-sync/tests/test-sync.sh`
Expected: `FAIL: ignored item still listed`.

- [ ] **Step 3: Implement is_ignored and ignore_add**

Add to sync.sh after `log()`:

```bash
is_ignored() { # <repo> <rel>
  grep -qxF "$2" "$1/.sync-ignore" 2>/dev/null
}

ignore_add() { # <repo> <rel>
  echo "$2" >> "$1/.sync-ignore"
  git -C "$1" add .sync-ignore
  log "  ignored forever (recorded in $1/.sync-ignore)"
}
```

In `handle_adopt_item`, change the `new)` branch to:

```bash
    new)
      is_ignored "$repo" "$rel" && return 0
      log "NEW: $src -> $repo/$rel"
      ;;
```

- [ ] **Step 4: Run test, verify pass**

Expected: `PASS: 6 FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
git add claude/skills/claude-sync
git commit -m "feat(claude-sync): ignore manifest"
```

---

### Task 3: Preview, secret scan, prompt, adopt

**Files:**
- Modify: `claude/skills/claude-sync/scripts/sync.sh`
- Modify: `claude/skills/claude-sync/tests/test-sync.sh`

- [ ] **Step 1: Add failing asserts**

Append to test file:

```bash
# --- Task 3: adopt flow ---
# my-skill: answer [a]dopt. CLAUDE.md and RTK.md will also prompt: adopt CLAUDE.md, skip RTK.md.
# Prompt order follows main(): skills dir first, then CLAUDE.md, then RTK.md.
printf 'a\na\ns\n' | "$SYNC" >"$SANDBOX/out3.txt" 2>&1
assert "my-skill moved into repo" test -f "$SANDBOX/pub/claude/skills/my-skill/SKILL.md"
assert "my-skill symlinked back"  test -L "$SANDBOX/dotclaude/skills/my-skill"
assert "symlink resolves"        test -e "$SANDBOX/dotclaude/skills/my-skill/SKILL.md"
assert "CLAUDE.md adopted"       test -f "$SANDBOX/pub/claude/CLAUDE.md"
assert "RTK.md skipped"          test ! -L "$SANDBOX/dotclaude/RTK.md"
GIT_STAGED=$(git -C "$SANDBOX/pub" diff --cached --name-only)
assert_grep "my-skill staged" "claude/skills/my-skill/SKILL.md" <(echo "$GIT_STAGED")

# secret scan: plant a fake AWS key, answer adopt then refuse override then skip
mkdir -p "$SANDBOX/dotclaude/skills/leaky"
echo 'aws_key = "AKIAIOSFODNN7EXAMPLE"' > "$SANDBOX/dotclaude/skills/leaky/SKILL.md"
printf 'a\nno\ns\ns\n' | "$SYNC" >"$SANDBOX/out4.txt" 2>&1
assert "leaky not adopted" test ! -L "$SANDBOX/dotclaude/skills/leaky"
assert_grep "secret warning shown" "possible secrets" "$SANDBOX/out4.txt"

# ignore-forever answer
printf 'i\ns\n' | "$SYNC" >"$SANDBOX/out5.txt" 2>&1
assert_grep "leaky in ignore manifest" "claude/skills/leaky" "$SANDBOX/pub/.sync-ignore"
```

For the `assert_grep ... <(echo ...)` line use a temp file instead:

```bash
git -C "$SANDBOX/pub" diff --cached --name-only > "$SANDBOX/staged.txt"
assert_grep "my-skill staged" "claude/skills/my-skill/SKILL.md" "$SANDBOX/staged.txt"
```

Note on answer counts: after adopting my-skill and CLAUDE.md in the first run, later runs only prompt for remaining new items (leaky, RTK.md) - the printf answer sequences above match that order (skills dir scans before CLAUDE.md/RTK.md in main()).

- [ ] **Step 2: Run test, verify new asserts fail**

Expected: FAIL lines for adopt asserts (script only logs NEW, never prompts).

- [ ] **Step 3: Implement preview, secret_scan, prompt_item, adopt**

Add to sync.sh:

```bash
preview() { # <path>
  local p=$1
  if [[ -d $p ]]; then
    find "$p" -not -name .DS_Store | head -15 | sed 's/^/    /'
  else
    head -15 "$p" | sed 's/^/    | /'
  fi
}

# secret_scan <path>: 0 = clean, 1 = suspicious content printed
secret_scan() {
  local p=$1 hits
  hits=$(grep -rEIn \
    -e 'AKIA[0-9A-Z]{16}' \
    -e '\-\-\-\-\-BEGIN( [A-Z]+)? PRIVATE KEY\-\-\-\-\-' \
    -e 'ghp_[A-Za-z0-9]{36}' \
    -e 'xox[baprs]-[0-9A-Za-z-]{10,}' \
    -e '(api[_-]?key|secret|password|passwd|token)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}' \
    -- "$p" 2>/dev/null) || true
  if [[ -n ${hits:-} ]]; then
    log "  !! possible secrets:"
    printf '%s\n' "$hits" | head -10 | sed 's/^/     /'
    return 1
  fi
  return 0
}

adopt() { # <src> <repo> <rel>
  local src=$1 repo=$2 rel=$3 dest="$2/$3"
  mkdir -p "$(dirname "$dest")"
  mv "$src" "$dest"
  ln -s "$dest" "$src"
  git -C "$repo" add "$rel"
  log "  adopted -> $dest"
}

prompt_item() { # <src> <repo> <rel>
  local src=$1 repo=$2 rel=$3 ans ans2 scan_ok=1
  log ""
  log "NEW: $src"
  log "  -> $repo/$rel"
  preview "$src"
  secret_scan "$src" || scan_ok=0
  while true; do
    read -rp "  [a]dopt / [i]gnore forever / [s]kip: " ans || { log "  (no input, skipping)"; return 0; }
    case $ans in
      a)
        if (( ! scan_ok )); then
          read -rp "  possible secrets above - adopt anyway? (yes/no): " ans2 || return 0
          [[ $ans2 == yes ]] || continue
        fi
        adopt "$src" "$repo" "$rel"; return 0 ;;
      i) ignore_add "$repo" "$rel"; return 0 ;;
      s) return 0 ;;
    esac
  done
}
```

In `handle_adopt_item`, change the `new)` branch to:

```bash
    new)
      is_ignored "$repo" "$rel" && return 0
      if (( DRY_RUN )); then
        log "NEW: $src -> $repo/$rel"
      else
        prompt_item "$src" "$repo" "$rel"
      fi
      ;;
```

- [ ] **Step 4: Run test, verify pass**

Expected: `PASS: 15 FAIL: 0` (5 + 1 + 9 new asserts).

- [ ] **Step 5: Commit**

```bash
git add claude/skills/claude-sync
git commit -m "feat(claude-sync): adopt flow with preview, secret scan, prompts"
```

---

### Task 4: copy-sync and mcpServers extract

**Files:**
- Modify: `claude/skills/claude-sync/scripts/sync.sh`
- Modify: `claude/skills/claude-sync/tests/test-sync.sh`

- [ ] **Step 1: Add failing asserts**

```bash
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
```

- [ ] **Step 2: Run test, verify new asserts fail**

Expected: FAIL lines (no copy_sync yet).

- [ ] **Step 3: Implement copy_sync and sync_mcp_servers, wire into main**

Add to sync.sh:

```bash
copy_sync() { # <src> <repo> <rel> [label]
  local src=$1 repo=$2 rel=$3 label="${4:-$1}" dest="$2/$3" ans
  [[ -e $src ]] || return 0
  if [[ ! -e $dest ]]; then
    if (( DRY_RUN )); then log "NEW (copy): $label -> $repo/$rel"; return 0; fi
    log ""
    log "NEW (copy-sync): $label -> $repo/$rel"
    read -rp "  [a]dopt / [s]kip: " ans || return 0
    [[ $ans == a ]] || return 0
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    git -C "$repo" add "$rel"
    log "  copied"
  elif ! cmp -s "$src" "$dest"; then
    log ""
    log "CHANGED: $rel"
    diff -u "$dest" "$src" | head -40 || true
    (( DRY_RUN )) && return 0
    cp "$src" "$dest"
    git -C "$repo" add "$rel"
    log "  updated"
  fi
}

sync_mcp_servers() {
  [[ -f $CLAUDE_JSON ]] || return 0
  command -v jq >/dev/null 2>&1 || { log "WARN: jq not found, skipping mcpServers extract"; return 0; }
  local tmp
  tmp=$(mktemp)
  jq '{mcpServers: (.mcpServers // {})}' "$CLAUDE_JSON" > "$tmp"
  copy_sync "$tmp" "$PRIVATE_REPO" "claude/mcp-servers.json" "$CLAUDE_JSON (mcpServers only)"
  rm -f "$tmp"
}
```

Append to `main()` after the RTK.md line:

```bash
  copy_sync "$CLAUDE_DIR/plugins/claude-hud/config.json" "$PUBLIC_REPO"  "claude/plugins/claude-hud/config.json"
  copy_sync "$CLAUDE_DIR/plugins/installed_plugins.json" "$PUBLIC_REPO"  "claude/plugins/installed_plugins.json"
  copy_sync "$CLAUDE_DIR/settings.json"                  "$PRIVATE_REPO" "claude/settings.json"
  copy_sync "$CLAUDE_DIR/settings.local.json"            "$PRIVATE_REPO" "claude/settings.local.json"
  sync_mcp_servers
```

- [ ] **Step 4: Run test, verify pass**

Expected: `PASS: 22 FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
git add claude/skills/claude-sync
git commit -m "feat(claude-sync): copy-sync and mcpServers extract"
```

---

### Task 5: Memory dir scan

**Files:**
- Modify: `claude/skills/claude-sync/scripts/sync.sh`
- Modify: `claude/skills/claude-sync/tests/test-sync.sh`

- [ ] **Step 1: Add failing asserts**

```bash
# --- Task 5: memory dirs ---
# Remaining prompts: RTK.md (s), memory dir (a)
printf 's\na\n' | "$SYNC" >"$SANDBOX/out8.txt" 2>&1
assert "memory moved to private" test -f "$SANDBOX/priv/claude/projects/-Users-me-projA/memory/fact.md"
assert "memory symlinked back"   test -L "$SANDBOX/dotclaude/projects/-Users-me-projA/memory"
assert "memory writes flow through" bash -c "echo new > '$SANDBOX/dotclaude/projects/-Users-me-projA/memory/new.md' && test -f '$SANDBOX/priv/claude/projects/-Users-me-projA/memory/new.md'"
```

- [ ] **Step 2: Run test, verify new asserts fail**

Expected: FAIL (memory never scanned).

- [ ] **Step 3: Implement scan_memory, wire into main**

Add to sync.sh:

```bash
scan_memory() {
  local d proj
  for d in "$CLAUDE_DIR"/projects/*/memory; do
    [[ -d $d || -L $d ]] || continue
    proj=$(basename "$(dirname "$d")")
    handle_adopt_item "$d" "$PRIVATE_REPO" "claude/projects/$proj/memory"
  done
}
```

Call it in `main()` after the RTK.md line (before the copy_sync block):

```bash
  scan_memory
```

- [ ] **Step 4: Run test, verify pass**

Expected: `PASS: 25 FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
git add claude/skills/claude-sync
git commit -m "feat(claude-sync): memory dir adoption"
```

---

### Task 6: Finish step - git status, commit/push offer, idempotence

**Files:**
- Modify: `claude/skills/claude-sync/scripts/sync.sh`
- Modify: `claude/skills/claude-sync/tests/test-sync.sh`

- [ ] **Step 1: Add failing asserts**

```bash
# --- Task 6: finish + idempotence ---
# Adopt RTK.md (last new item), then answer n to both commit prompts
printf 'a\nn\nn\n' | "$SYNC" >"$SANDBOX/out9.txt" 2>&1
assert_grep "status header pub"  "=== $SANDBOX/pub ===" "$SANDBOX/out9.txt"
assert_grep "status header priv" "=== $SANDBOX/priv ===" "$SANDBOX/out9.txt"
assert_grep "commit offered" "commit all changes" "$SANDBOX/out9.txt"

# everything adopted or ignored: a fresh run must make NO prompts (stdin closed)
"$SYNC" </dev/null >"$SANDBOX/out10.txt" 2>&1; RC=$?
assert "idempotent run exits 0" test "$RC" -eq 0
assert_absent "idempotent run finds no NEW" "^NEW" "$SANDBOX/out10.txt"
```

Note: with stdin at `/dev/null`, any unexpected prompt makes `read` fail; prompt_item and copy_sync handle that by skipping, and finish_repo's commit prompt only fires when there are staged/unstaged changes - after the `n\nn` run above there are still uncommitted changes staged, so the idempotent run will offer commit again and `read` will fail-skip. That is fine: the assert only checks for NEW prompts and exit 0.

- [ ] **Step 2: Run test, verify new asserts fail**

Expected: FAIL (no finish output).

- [ ] **Step 3: Implement finish_repo**

Add to sync.sh:

```bash
finish_repo() { # <repo>
  local repo=$1 ans
  [[ -d $repo/.git ]] || { log "WARN: not a git repo: $repo"; return 0; }
  log ""
  log "=== $repo ==="
  git -C "$repo" status --short
  (( DRY_RUN )) && return 0
  if [[ -n $(git -C "$repo" status --porcelain) ]]; then
    read -rp "commit all changes in $repo? [y/N]: " ans || return 0
    if [[ $ans == y ]]; then
      git -C "$repo" add -A
      git -C "$repo" commit -m "chore: claude-sync $(date +%Y-%m-%d)"
      read -rp "push $repo? [y/N]: " ans || return 0
      [[ $ans == y ]] && git -C "$repo" push
    fi
  fi
  return 0
}
```

Append to `main()` at the end:

```bash
  finish_repo "$PUBLIC_REPO"
  finish_repo "$PRIVATE_REPO"
```

Note: `set -e` + `read` failing at EOF - every `read` already has `|| return 0` / `|| { ...; }` guards. Keep that pattern for any new `read`.

- [ ] **Step 4: Run test, verify pass**

Expected: `PASS: 30 FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
git add claude/skills/claude-sync
git commit -m "feat(claude-sync): finish step with commit/push offer"
```

---

### Task 7: SKILL.md wrapper

**Files:**
- Create: `claude/skills/claude-sync/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

```markdown
---
name: claude-sync
description: Back up custom Claude Code config (skills, commands, agents, scripts, instructions, memory, settings) into version control. Use when user says "backup claude files", "sync claude config", "adopt this skill into dot-files", or after creating a new custom skill/command.
---

# claude-sync

Discover-prompt-adopt backup for custom Claude Code configuration.
Spec: `docs/specs/2026-07-18-claude-sync-design.md` in the dot-files repo.

## Destinations

- **Public** `~/projects/dot-files`: skills, commands, agents, scripts, local-plugins (from `~/.claude` and `~/.agents`), CLAUDE.md, RTK.md, claude-hud config, installed_plugins.json
- **Private** `~/projects/claude-private`: per-project memory dirs, settings.json, settings.local.json, mcpServers extract from `~/.claude.json`

Symlink-adopted items live in the repo with a symlink at the original path - edits land in the repo working tree immediately. Copy-synced files (settings, plugin configs) are re-copied on each run because Claude Code rewrites them via atomic rename, which would break symlinks.

## Usage

Preview what would change (no prompts, no writes):

    bash ~/projects/dot-files/claude/skills/claude-sync/scripts/sync.sh --dry-run

Interactive run (prompts [a]dopt / [i]gnore forever / [s]kip per new item, offers commit+push per repo at the end):

    bash ~/projects/dot-files/claude/skills/claude-sync/scripts/sync.sh

Run the interactive version in the foreground and relay each prompt to the user - adoption decisions are theirs. Never answer the adopt/ignore prompts autonomously.

"Ignore forever" decisions are stored in `.sync-ignore` at each repo root; edit that file to un-ignore.

## Safety

- Adopt-time secret grep blocks adoption unless the user types `yes`
- Both repos have gitleaks pre-commit hooks - if a commit is rejected, show the gitleaks output to the user and do not bypass with --no-verify
- The public repo is PUBLIC on GitHub: anything personal belongs in claude-private

## Tests

    bash ~/projects/dot-files/claude/skills/claude-sync/tests/test-sync.sh

Sandbox-only (temp dir), safe to run anytime. Expect `FAIL: 0`.
```

- [ ] **Step 2: Commit**

```bash
git add claude/skills/claude-sync/SKILL.md
git commit -m "feat(claude-sync): skill wrapper"
```

---

### Task 8: Create private repo

**Files:**
- Create: `~/projects/claude-private` (new repo, outside dot-files)

- [ ] **Step 1: Create private GitHub repo and local clone**

```bash
gh repo create MichaelPaulukonis/claude-private --private \
  --description "Private Claude Code config backup (memory, settings)" \
  --clone --add-readme=false 2>/dev/null \
  || gh repo create MichaelPaulukonis/claude-private --private --clone
```

If `--clone` lands it in the current dir, run from `~/projects`. If the repo already exists, just `git clone git@github.com:MichaelPaulukonis/claude-private.git ~/projects/claude-private`.

- [ ] **Step 2: Seed repo**

```bash
cd ~/projects/claude-private
printf '# claude-private\n\nPrivate backup of Claude Code memory and settings. Managed by claude-sync\n(see dot-files/claude/skills/claude-sync).\n' > README.md
touch .sync-ignore
git add README.md .sync-ignore
git commit -m "chore: seed claude-private"
git push -u origin main
```

- [ ] **Step 3: Verify visibility**

Run: `gh repo view MichaelPaulukonis/claude-private --json visibility -q .visibility`
Expected: `PRIVATE`. If not, stop and fix before any sync run.

---

### Task 9: gitleaks pre-commit hooks

**Files:**
- Create: `~/projects/dot-files/.git/hooks/pre-commit`
- Create: `~/projects/claude-private/.git/hooks/pre-commit`

- [ ] **Step 1: Install gitleaks**

```bash
command -v gitleaks || brew install gitleaks
gitleaks version
```

- [ ] **Step 2: Per user's global CLAUDE.md preference, record the brew install**

Update wiki page `study/macos/homebrew` (wikijs skill): package `gitleaks`, install date (today), why: "pre-commit secret scanning for dot-files and claude-private repos (claude-sync)", docs link `https://github.com/gitleaks/gitleaks`. Skip if gitleaks was already installed.

- [ ] **Step 3: Write identical hook into both repos**

```bash
for repo in ~/projects/dot-files ~/projects/claude-private; do
  cat > "$repo/.git/hooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
# Block commits containing secrets (installed by claude-sync setup)
exec gitleaks protect --staged --redact -v
EOF
  chmod +x "$repo/.git/hooks/pre-commit"
done
```

If `gitleaks protect` is not a valid subcommand in the installed version (v8.19+ renamed it), use `exec gitleaks git --pre-commit --staged -v --redact` instead - check with `gitleaks protect --help`.

- [ ] **Step 4: Verify hook blocks a secret**

```bash
cd ~/projects/dot-files
echo 'aws_secret = "AKIAIOSFODNN7EXAMPLE"' > /tmp/nothing-here && cp /tmp/nothing-here leak-test.txt
git add leak-test.txt
git commit -m "test" ; echo "exit: $?"
git reset leak-test.txt && rm leak-test.txt
```

Expected: commit fails (nonzero exit, gitleaks finding printed). Clean up as shown.

- [ ] **Step 5: Note hook limitation**

`.git/hooks` is not versioned. Add a line to dot-files README:

```markdown
## Setup on a new machine
- `brew install gitleaks`, then re-create pre-commit hooks per docs/specs/2026-07-18-claude-sync-design.md (Secret scanning section)
```

```bash
cd ~/projects/dot-files
git add README.md
git commit -m "docs: note gitleaks hook setup"
```

---

### Task 10: Self-adopt and first real run

**Files:**
- Modify: live `~/.claude` (symlinks), both repos

- [ ] **Step 1: Push pending dot-files commits**

```bash
cd ~/projects/dot-files && git push
```

- [ ] **Step 2: Dry-run against real home**

```bash
bash ~/projects/dot-files/claude/skills/claude-sync/scripts/sync.sh --dry-run
```

Expected NEW items include: skills gtasks-cli, image-frames-to-video, wiki-blog-conventions, writing-style; the 7 `~/.agents/skills` entries (find-skills + specstory family - note: `~/.claude/skills` symlinks pointing at `~/.agents/skills` classify as foreign and are skipped there; the real dirs are discovered via the `~/.agents/skills` scan); CLAUDE.md; RTK.md; local-plugins entries; 9 memory dirs; copy-sync items. `wikijs` and `journal-entry` classify as adopted - not listed. Review the report with the user before proceeding.

- [ ] **Step 3: Interactive run with the user**

Run `sync.sh` in foreground, relay every prompt - the user decides adopt/ignore/skip per item. Do not answer prompts autonomously.

- [ ] **Step 4: Verify a Claude-written memory flows to private repo**

After memory adoption: `ls -la ~/.claude/projects/-Users-michaelpaulukonis-projects-research/memory` shows symlink; `git -C ~/projects/claude-private status --short` shows adopted files staged.

- [ ] **Step 5: Commit + push both repos via the script's finish step, then re-run**

```bash
bash ~/projects/dot-files/claude/skills/claude-sync/scripts/sync.sh --dry-run
```

Expected: no NEW lines (idempotent), only possible CHANGED copy-sync noise.

- [ ] **Step 6: Restart check**

Ask user to confirm in a fresh Claude Code session that skills still load (claude-sync, wikijs, adopted skills) and memory recall still works. Symlinks are transparent, but verify once.
