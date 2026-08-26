#!/usr/bin/env bash
# Global SessionStart hook: gates a personal-context check-in question to once per calendar day.
# Silent (no output) if already asked today - fires on every session start, but only "activates" once/day.
set -euo pipefail

STATE_DIR="$HOME/.claude/daily-checkin"
STATE_FILE="$STATE_DIR/state.json"
CATEGORIES=("family" "career" "personality" "background")

mkdir -p "$STATE_DIR"
[ -f "$STATE_FILE" ] || echo '{"lastAskedDate":"","categoryIndex":0}' > "$STATE_FILE"

TODAY=$(date +%Y-%m-%d)
LAST_ASKED=$(jq -r '.lastAskedDate' "$STATE_FILE")

if [ "$LAST_ASKED" = "$TODAY" ]; then
  exit 0
fi

INDEX=$(jq -r '.categoryIndex' "$STATE_FILE")
CATEGORY="${CATEGORIES[$INDEX]}"
NEXT_INDEX=$(( (INDEX + 1) % ${#CATEGORIES[@]} ))

jq --arg today "$TODAY" --argjson next "$NEXT_INDEX" \
  '.lastAskedDate = $today | .categoryIndex = $next' \
  "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

cat <<EOF
Daily personal check-in (once/day, today's category: ${CATEGORY}).
Sometime in this session - doesn't need to be the first line - check nornicdb and mempalace (wing "personal", room "${CATEGORY}") for what's already known about the user in this category, find a real gap, and ask ONE natural question to fill it. Keep it low-friction: one question, easy to skip or defer. If they answer, store it to both nornicdb and mempalace under wing "personal", room "${CATEGORY}". If they decline or the moment doesn't fit, don't force it - the daily gate already advanced, so it won't ask again until tomorrow.
EOF
