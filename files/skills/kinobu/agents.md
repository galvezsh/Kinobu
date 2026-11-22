<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->
# AI tools

Check what is installed with `command -v claude ollama`. The default agent (Super+Shift+Enter) is
the path in `~/.config/kinobu/agent`.

| Tool | Binary | Config | Global instructions | Update |
|---|---|---|---|---|
| Claude Code | `~/.local/bin/claude` | `~/.claude/` | `~/.claude/CLAUDE.md` | automatic, or `claude update` |

- Skills: `~/.claude/skills/`. @APP_NAME@'s skills (`kinobu`, `kinobu-dev`) are links to
  `@SYSTEM_DIR@/skills/`; add the user's own as normal folders next to them.
- The global instructions hold @APP_NAME@'s short note between `<!-- kinobu:begin -->` and
  `<!-- kinobu:end -->`, rewritten on every update; everything outside it is the user's.
- @APP_NAME@ never changes the agents' own permission settings.

## Kinobu Agent, the read-only investigator

A subagent (`~/.claude/agents/kinobu-agent.md`) that runs the many commands a diagnosis needs in
its own context and returns a short report: Cause, Fix, Check, If it still fails, Needs sudo. It
never changes anything. For one quick command, run it yourself. Otherwise:

1. Delegate the question to `kinobu-agent`.
2. Show the user the Fix and wait for their go-ahead, then apply it yourself.
3. Run the Check yourself (one to three short commands).
4. If it fails, send the subagent what you applied and what the check printed: it continues
   from there.
5. After two failed rounds, investigate yourself, even if it costs context.

When the report lists **Needs sudo**, ask the user to run those read-only commands (in Claude Code:
`! sudo …`) and pass the output back.

## Notifications

@APP_NAME@'s hooks in `~/.claude/settings.json` (next to other tools' entries, which are kept) show a
desktop notice when a task finished (20 s or more), the agent waits for the user (also an MCP
server asking for input or a background agent) or stops on an error; a click brings back the
agent's terminal. After a compaction, Claude Code is told to reread the project's CONTEXT.md. Permission requests open Gate (Allow, In
terminal, Deny); no answer leaves the decision to the terminal. The notifier is `@NOTIFIER@`.
To notify the user yourself (once per event, in their language, no personal data):

```bash
notify-send --app-name="Claude Code" --icon=utilities-terminal "✅ <project folder>" "<short text>"
```

## Local models and MCP servers

- Ollama: `ollama.service`, API on `127.0.0.1:11434`; change its settings with
  `sudo systemctl edit ollama` (a `[Service]` header), then restart it. LM Studio updates itself.
- MCP servers run with `npx -y <package>` (Node.js) or `uvx <package>` (uv).

## Willow, the voice assistant

Willow (Super+Shift+Space) runs the default agent headless with a small model and a prompt of its
own (none of the agent's settings, hooks, skills or memory). It reads the system with read-only
commands, searches the web, opens apps, pages and folders, takes the safe actions of `kinobu-do`
(`kinobu-do help`), looks at the screen when asked and hands real work to the agent in a terminal.
It keeps nothing about the user. Settings: `~/.config/kinobu/voice.json` (`power`: quick, smart or
strong; `persona`) or its settings window. Voices and models: `~/.local/share/kinobu/voice/`. If it
stays silent, check the voice engine in its settings and the sound mute.
