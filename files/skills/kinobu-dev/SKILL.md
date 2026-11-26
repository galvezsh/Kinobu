---
name: @APP_ID@-dev
description: >
  How to create or change a program on this computer, in any language, from a small script to a
  large app: a spec agreed before the code, git checkpoints, a CONTEXT.md to pick up the work, a
  README and an AGENTS.md, and clean code that can grow. Load it before writing or changing code.
---
<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->

# Developing a program

Unless the user shows they program, assume they do not and will want to extend the app later:
keeping the project safe, easy to pick up again and easy to grow is your job, unasked.

## 1. Specs before code

Never code from a loose request: write down what to build, agree it with the user, then build
exactly that.

- A small fix or a one-file script: list the acceptance criteria in the conversation, get a yes.
- A feature or a new app: a spec in `specs/<feature>/` first. Read [specs.md](specs.md) before
  writing one. Before the user approves a large one, offer in one line to pass it through the
  `@APP_ID@-council` skill.
- Show it to the user in their language and plain words; code only after their yes, task by
  task. A change of behaviour changes the spec first; what it leaves open is asked, never guessed.
- A user who programs: keep their spec, stack and architecture, add only what is missing, ask
  only what is open, and follow their own way of working.
- What is agreed or learned goes into the project's files (the spec, its tasks, `CONTEXT.md`,
  `AGENTS.md`), never only into the chat: a new conversation must carry on from them alone.

## 2. Git checkpoints

- A new project gets `git init` and a `.gitignore` for its language (build output, dependencies,
  `.env` and other secrets).
- Commit a checkpoint each time a piece works (a feature, a fix), with a short message saying
  what changed; not for every small edit. Never commit secrets.
- Before a risky change, commit the last good state. To go back: `git log
  --oneline`, then `git revert` or `git restore`; tell the user before throwing work away.
- Everything stays on this computer: no remote, push or GitHub unless the user asks.
- If the user's instructions say they commit themselves, propose the message instead.

## 3. CONTEXT.md, the project's memory

Conversations end. `CONTEXT.md` in the project's root lets a new one, yours or another agent's,
carry on.

- Read it first when it exists; create it when the project starts.
- It is for agents: English, short and precise, one or two pages. Rewrite it with the current
  state (the history is in git) instead of adding lines. The user does not read it: answer their
  questions about progress from it, in their language.
- What it holds: what the project is · how to run and test it · its state (what works, what does
  not) · decisions and why · traps found · the active spec and next steps, in order.
- Update it, in the same commit, after every change worth telling the user (not a typo), and
  before a long conversation runs out or the user leaves.
- No passwords, keys or personal data in it.

## 4. README.md, AGENTS.md and CLAUDE.md

- `README.md`, for people: what it does and how to install and use it, in plain words.
- `AGENTS.md`, for agents: the layout and architecture, how to build and test, the project's
  conventions and rules. It changes little; the state belongs in `CONTEXT.md`, not here.
- `CLAUDE.md` with two lines, `@AGENTS.md` and `@CONTEXT.md`: Claude Code loads both in every
  conversation in the project.
- A changelog or a roadmap only when the project is published or the user asks.

## 5. Architecture

Build it so that it can grow and a person can change it:

- A well-known architecture that fits the kind of project, chosen at the start and written down
  in `AGENTS.md`: for example hexagonal architecture with DDD for a backend or REST API (the
  domain in the centre, adapters for the database, the web and other services), components with
  separate state and services for a front end, a core module plus a thin command line for a tool.
- Clean Code: clear names, small functions and modules that do one thing, business rules apart from
  framework, database and interface, no duplicated logic.
- Fit the size: a short script stays one tidy file with functions; the structure grows when the
  project does. No layers or patterns that nothing uses yet.

## 6. The code

- No more code than the job needs: the standard library and well-known packages first.
- One short comment over each function saying what it does; more only where it is not obvious.
- Today's versions and APIs, never old ones from memory: before coding against a language,
  library or framework, check the version installed in the project, read today's official docs
  for it with WebFetch and note what matters in the plan ([specs.md](specs.md), "Versions and
  docs").
- Dependencies inside the project (a `venv` or `uv`, local `npm`), never system-wide with sudo.
- Run what you build, test what matters and tell the user what was and was not checked.
