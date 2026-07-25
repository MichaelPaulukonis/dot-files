#!/usr/bin/env bash
# claude-sync: back up custom Claude Code config into version control.
# Spec: docs/specs/2026-07-18-claude-sync-design.md
set -euo pipefail

CLAUDE_DIR="${CLAUDE_SYNC_CLAUDE_DIR:-$HOME/.claude}"
AGENTS_DIR="${CLAUDE_SYNC_AGENTS_DIR:-$HOME/.agents}"
CLAUDE_JSON="${CLAUDE_SYNC_CLAUDE_JSON:-$HOME/.claude.json}"
PUBLIC_REPO="${CLAUDE_SYNC_PUBLIC:-$HOME/projects/dot-files}"
PRIVATE_REPO="${CLAUDE_SYNC_PRIVATE:-$HOME/projects/claude-private}"
# Canonicalize repo roots so classify()'s prefix match works even when the
# caller's path traverses a symlink (e.g. macOS /var -> /private/var, which
# readlink -f resolves away). Safe: both repos must exist for git ops to work.
PUBLIC_REPO=$(readlink -f -- "$PUBLIC_REPO")
PRIVATE_REPO=$(readlink -f -- "$PRIVATE_REPO")
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

log() { printf '%s\n' "$*"; }

is_ignored() { # <repo> <rel>
  grep -qxF "$2" "$1/.sync-ignore" 2>/dev/null
}

ignore_add() { # <repo> <rel>
  echo "$2" >> "$1/.sync-ignore"
  git -C "$1" add .sync-ignore
  log "  ignored forever (recorded in $1/.sync-ignore)"
}

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
  hits=$(grep -rEIni \
    -e 'AKIA[0-9A-Z]{16}' \
    -e '\-\-\-\-\-BEGIN( [A-Z]+)? PRIVATE KEY\-\-\-\-\-' \
    -e 'ghp_[A-Za-z0-9]{36}' \
    -e 'xox[baprs]-[0-9A-Za-z-]{10,}' \
    -e '(api[_-]?key|secret|password|passwd|token)[[:alnum:]_-]*["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?[^"'"'"'[:space:]]{8,}' \
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
  mv "$src" "$dest" || return 1
  if ! ln -s "$dest" "$src"; then
    mv "$dest" "$src"   # rollback: restore original location
    log "  !! adopt failed (couldn't symlink back), left in place"
    return 1
  fi
  git -C "$repo" add "$rel" || log "  !! adopted but 'git add' failed - stage manually"
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
        adopt "$src" "$repo" "$rel" || true
        return 0 ;;
      i) ignore_add "$repo" "$rel"; return 0 ;;
      s) return 0 ;;
      *) log "  please answer a, i, or s" ;;
    esac
  done
}

# classify <path> -> adopted | foreign | dangling | new
classify() {
  local p=$1 target
  if [[ -L $p ]]; then
    # On macOS, `readlink -f` on a dangling symlink exits 1 but still prints
    # the canonicalized (nonexistent) path to stdout; that output is
    # intentionally discarded here via 2>/dev/null + the || fallback, so
    # `-z $target` (not the command's exit status) is the real dangling check.
    target=$(readlink -f -- "$p" 2>/dev/null) || target=""
    if [[ -z $target || ! -e $target ]]; then
      echo dangling; return
    fi
    case "$target" in
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
  case "$(classify "$src")" in
    adopted|foreign) ;;
    dangling) log "WARN: dangling symlink: $src" ;;
    new)
      is_ignored "$repo" "$rel" && return 0
      if (( DRY_RUN )); then
        log "NEW: $src -> $repo/$rel"
      else
        prompt_item "$src" "$repo" "$rel"
      fi
      ;;
  esac
}

scan_memory() {
  local d proj
  for d in "$CLAUDE_DIR"/projects/*/memory; do
    [[ -d $d || -L $d ]] || continue
    proj=$(basename "$(dirname "$d")")
    handle_adopt_item "$d" "$PRIVATE_REPO" "claude/projects/$proj/memory"
  done
}

# scan_adopt_dir <dir> <repo> <relbase>
scan_adopt_dir() {
  local dir=$1 repo=$2 relbase=$3 item name
  [[ -d $dir ]] || return 0
  for item in "$dir"/*; do
    [[ -e $item || -L $item ]] || continue
    name=$(basename "$item")
    handle_adopt_item "$item" "$repo" "$relbase/$name"
  done
}

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
  if ! jq '{mcpServers: (.mcpServers // {})}' "$CLAUDE_JSON" > "$tmp" 2>/dev/null; then
    log "WARN: failed to parse $CLAUDE_JSON, skipping mcpServers extract"
    rm -f "$tmp"
    return 0
  fi
  if [[ ! -s $tmp ]]; then
    log "WARN: $CLAUDE_JSON produced no/empty output, skipping mcpServers extract"
    rm -f "$tmp"
    return 0
  fi
  copy_sync "$tmp" "$PRIVATE_REPO" "claude/mcp-servers.json" "$CLAUDE_JSON (mcpServers only)"
  rm -f "$tmp"
}

finish_repo() { # <repo>
  local repo=$1 ans
  [[ -d $repo/.git ]] || { log "WARN: not a git repo: $repo"; return 0; }
  log ""
  log "=== $repo ==="
  git -C "$repo" status --short
  (( DRY_RUN )) && return 0
  if [[ -n $(git -C "$repo" status --porcelain) ]]; then
    printf '%s' "commit all changes in $repo? [y/N]: " >&2
    read -r ans || return 0
    if [[ $ans == y ]]; then
      git -C "$repo" add -A
      if ! git -C "$repo" commit -m "chore: claude-sync $(date +%Y-%m-%d)"; then
        log "  !! commit failed in $repo - resolve manually"
        return 0
      fi
      printf '%s' "push $repo? [y/N]: " >&2
      read -r ans || return 0
      if [[ $ans == y ]]; then
        git -C "$repo" push || log "  !! push failed in $repo - push manually"
      fi
    fi
  fi
  return 0
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
  scan_memory

  copy_sync "$CLAUDE_DIR/plugins/claude-hud/config.json" "$PUBLIC_REPO"  "claude/plugins/claude-hud/config.json"
  copy_sync "$CLAUDE_DIR/plugins/installed_plugins.json" "$PUBLIC_REPO"  "claude/plugins/installed_plugins.json"
  copy_sync "$CLAUDE_DIR/settings.json"                  "$PRIVATE_REPO" "claude/settings.json"
  copy_sync "$CLAUDE_DIR/settings.local.json"            "$PRIVATE_REPO" "claude/settings.local.json"
  sync_mcp_servers

  finish_repo "$PUBLIC_REPO"
  finish_repo "$PRIVATE_REPO"
}
main
