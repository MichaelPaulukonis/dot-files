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
