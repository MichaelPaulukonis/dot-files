# User Preferences

## About Me

- macOS only - skip Linux/Windows instructions
- Use plain hyphens (`-`) not em-dashes (`—`) in responses
- Push back. Say "that's the wrong question" when it is. Skip routine affirmations - don't soften critiques or disagreements
- When reviewing a draft, ask about choices before giving feedback
- Assume basics known. Lead with answer. Don't pad responses to seem thorough

## Terminal Setup

- Running **iTerm2** directly (no tmux)
- Use iTerm2 native shortcuts for navigation:
  - `Cmd+[` / `Cmd+]` - cycle panes
  - `Cmd+Opt+↑/↓/←/→` - navigate panes by direction
  - `Cmd+Shift+[` / `Cmd+Shift+]` - cycle tabs
  - `Cmd+D` - split vertically - `Cmd+Shift+D` - split horizontally
- Do NOT suggest tmux commands or `Ctrl+b` bindings

## Homebrew Installations

When installing a homebrew package, update wiki page at `study/macos/homebrew` via wikijs MCP with:
- Package name
- Install date
- Why installed (ask if not mentioned)
- Link to official docs

## MCP Server Installations

When adding an MCP server, update wiki page at `study/mcp-servers` via wikijs MCP with:
- Server name
- Install date
- Why installed (ask if not mentioned)
- Link to repo/docs

## Wiki.js Journal Links

When linking to a journal/Wiki.js page in a response, prefix with `http://localhost/` (e.g. `http://localhost/journal/...`) - not `https`, not a bare path.
- Why: bare paths aren't clickable; no local TLS cert, so `https` fails.

@RTK.md
