#!/usr/bin/env bash
# Global SessionStart + UserPromptSubmit hook: surfaces a personal-context check-in
# question, gated to once per calendar day, rotating through: family, career,
# personality, background.
#
# Design: firing the reminder does NOT mark the day done. Only `--mark` does that.
# This means the reminder keeps resurfacing every turn (SessionStart and
# UserPromptSubmit both call this in default/check mode) until Claude actually
# asks-and-resolves it (answered or explicitly declined) and runs `--mark`.
# Previously the day was marked "asked" at fire time, so a single ignored
# reminder silently burned the whole day with no retry.
set -euo pipefail

STATE_DIR="$HOME/.claude/daily-checkin"
STATE_FILE="$STATE_DIR/state.json"
CATEGORIES=("family" "career" "personality" "background")

mkdir -p "$STATE_DIR"
[ -f "$STATE_FILE" ] || echo '{"lastAskedDate":"","categoryIndex":0}' > "$STATE_FILE"

TODAY=$(date +%Y-%m-%d)

if [ "${1:-}" = "--mark" ]; then
  INDEX=$(jq -r '.categoryIndex' "$STATE_FILE")
  NEXT_INDEX=$(( (INDEX + 1) % ${#CATEGORIES[@]} ))
  jq --arg today "$TODAY" --argjson next "$NEXT_INDEX" \
    '.lastAskedDate = $today | .categoryIndex = $next' \
    "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
  exit 0
fi

LAST_ASKED=$(jq -r '.lastAskedDate' "$STATE_FILE")
if [ "$LAST_ASKED" = "$TODAY" ]; then
  exit 0
fi

INDEX=$(jq -r '.categoryIndex' "$STATE_FILE")
CATEGORY="${CATEGORIES[$INDEX]}"

cat <<EOF
Daily personal check-in (today's category: ${CATEGORY}, still PENDING - not yet resolved for today).
This reminder repeats every turn until resolved, so it will not get lost among other session-start context.
Sometime soon, work in ONE natural, low-friction question: check nornicdb and mempalace (wing "personal", room "${CATEGORY}") for what's already known, find a real gap, and ask about it.
- If they answer: store it to both nornicdb and mempalace under wing "personal", room "${CATEGORY}", then run: ~/.claude/scripts/daily-checkin-hook.sh --mark
- If they decline or say not now/not tonight: respect it immediately, don't ask again this session, then run: ~/.claude/scripts/daily-checkin-hook.sh --mark (this silences it for the rest of today; it returns with the next category on a future day)
- Do not run --mark until one of those two things has actually happened.
EOF
