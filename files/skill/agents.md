<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->
# AI tools

Check which ones are installed with `command -v claude codex agy ollama`.
The default agent (Super+Shift+Enter, like Super+Enter for the terminal) is the path stored in `~/.config/kinobu/agent`.

| Tool | Binary | Config | Global instructions | Update |
|---|---|---|---|---|
| Claude Code | `~/.local/bin/claude` | `~/.claude/` | `~/.claude/CLAUDE.md` | automatic, or `claude update` |
| Codex | `~/.local/bin/codex` | `~/.codex/config.toml` | `~/.codex/AGENTS.md` | re-run its installer |
| Antigravity CLI | `~/.local/bin/agy` | `~/.gemini/` | `~/.gemini/GEMINI.md` | automatic |

Skills: `~/.agents/skills/` (Codex), `~/.claude/skills/` (Claude Code) and
`~/.gemini/config/skills/` (Antigravity). This skill is a symlink
there; add your own skills as normal folders next to it.

Each agent's global instructions file holds a short Kinobu note (this system, how to work with
the user, saving tokens) between `<!-- kinobu:begin -->` and `<!-- kinobu:end -->`. Kinobu
rewrites that block on every run; anything outside it is the user's. Kinobu does not change the
agents' own permission settings: each tool keeps its defaults.

## The kinobu-system subagent

A read-only investigator of this computer, installed for Claude Code (`~/.claude/agents/`),
Codex (`~/.codex/agents/`) and Antigravity (`~/.gemini/config/agents/`). It runs the many commands a diagnosis needs in its own context and returns a
short report (Cause, Fix, Check, If it still fails, Needs sudo), so your conversation keeps only
the summary. It never changes anything and never runs `sudo`.

Use it for system questions or problems that need many commands or long outputs (why something
fails, hardware and drivers, logs, disk usage); for one quick command, just run it. Then:

1. Delegate the question to `kinobu-system`.
2. Show the user the Fix and wait for their go-ahead.
3. Apply it yourself.
4. Run the Check yourself (one to three short commands).
5. If the check fails, send the subagent what you applied and what the check printed: it
   continues from there instead of starting over.
6. After two failed rounds, take over and investigate yourself, even if it costs more context:
   the goal is to fix it. Changes still need the user's go-ahead.

If the report lists **Needs sudo**, ask the user to run those read-only commands (in Claude Code
with `! sudo …`) and pass the output back to the subagent.

## Local models

- **Ollama**: `ollama.service`, API on `127.0.0.1:11434`, default settings. Change them with
  `sudo systemctl edit ollama` (a drop-in always needs a `[Service]` header), then
  `sudo systemctl restart ollama`. Models: `ollama pull|run|ps|list`.
- **LM Studio**: desktop app (package `lm-studio`), updates itself.

## Notifications

Kinobu adds its own entries to every agent's hooks (next to other tools' hooks), so the
desktop shows a notification, with a short sound, when a task finished (only when it took 20 s
or more by default), the agent waits for the user, or a Claude Code turn stops on an error
("usage limit reached" for rate limits). The header names the agent, the title is the project
folder, and a click brings back the agent's terminal. When Claude Code or Codex needs an approval,
Kinobu's window asks with Allow, "In terminal" and Deny; closing it, "In terminal" or no answer in 45 s
(default) leaves the decision to the agent's own prompt in the terminal. The notifier is
`@NOTIFIER@`; entries that run it are rewritten on every Kinobu run, other
tools' entries are kept. Files: `~/.claude/settings.json`, `~/.codex/hooks.json` (Codex runs
them once trusted with `/hooks`) and `~/.gemini/config/hooks.json`.

You can also notify the user yourself, for example when a long job ends or you need them while
they may be away from the terminal (once per event, never in loops):

```bash
notify-send --app-name="<your name, e.g. Claude Code>" --icon=utilities-terminal "✅ <project folder>" "<short text>"
canberra-gtk-play --id=complete     # optional sound: complete, message-new-instant, dialog-warning
```

Write the text in the user's language. Never put personal data (e-mail, tokens) in it.

## MCP servers

Node.js (`npx -y <package>`) and uv (`uvx <package>`) are available for MCP servers.

## Zen, the voice assistant

Zen (Super+Shift+Space) runs the default agent headless with a small, cheap model and a tiny
prompt of its own: none of the agent's settings, hooks, MCP servers, skills or memory. For now
only Claude Code (`claude -p --model haiku`); other agents are planned. It may read the system
with an allow-list of read-only commands, search the web and open apps, pages or folders; for
real work it shows a card that opens this agent in a terminal with the task already written.
