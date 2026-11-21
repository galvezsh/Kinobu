---
name: @APP_ID@-dev
description: >
  How to create or change a program on this computer, in any language, from a small script to a
  large app: git checkpoints, a CONTEXT.md that lets a new conversation pick up the work, a
  README and an AGENTS.md, and clean, scalable code that people can maintain. Load it before
  writing or changing code.
---
<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->

# Developing a program

Assume the user does not program and only asks for an app, and that they will want to extend it
later: keeping the project safe, easy to pick up again and easy to grow is your job, without
being asked.

## 1. Git checkpoints

- A new project gets `git init` and a `.gitignore` for its language (build output, dependencies,
  `.env` and other secrets).
- Commit a checkpoint each time a piece works (a feature, a fix), with a short message saying
  what changed; not for every small edit. Never commit secrets.
- Before a risky change, make sure the last good state is committed. To go back: `git log
  --oneline`, then `git revert` or `git restore`; tell the user before throwing work away.
- Everything stays on this computer: no remote, push or GitHub unless the user asks.
- If the user's instructions say they commit themselves, propose the message instead.

## 2. CONTEXT.md, the project's memory

Conversations end, and a new one starts knowing nothing. `CONTEXT.md` in the project's root lets
you, or any other agent, carry on.

- Read it first when it exists; create it when the project starts.
- It is for agents, so write it in English, short and precise: one or two pages. Rewrite it with
  the current state (the history is in git), do not keep adding lines. The user does not read it:
  when they ask how the project is going or what is left, answer from it in their language.
- What it holds: what the project is · how to run and test it · its state (what works, what does
  not) · decisions and why · traps found · next steps, in order.
- Update it after every change worth telling the user (a feature, a fix, a decision), with the
  same commit; not for a typo. Before a long conversation runs out, or when the user leaves,
  bring it up to date.
- No passwords, keys or personal data in it.

## 3. README.md, AGENTS.md and CLAUDE.md

- `README.md`, for people: what it does and how to install and use it, in plain words.
- `AGENTS.md`, for agents: the layout and architecture, how to build and test, the project's
  conventions and rules. It changes little; the state belongs in `CONTEXT.md`, not here.
- `CLAUDE.md` with two lines, `@AGENTS.md` and `@CONTEXT.md`: Claude Code then loads both at the
  start of every conversation in the project.
- A changelog or a roadmap only when the project is published or the user asks.

## 4. Architecture

Build it so that it can grow and so that a person can understand and change it:

- A well-known architecture that fits the kind of project, chosen at the start and written down
  in `AGENTS.md`: for example hexagonal architecture with DDD for a backend or REST API (the
  domain in the centre, adapters for the database, the web and other services), components with
  separate state and services for a front end, a core module plus a thin command line for a tool.
- Clean Code: clear names, small functions and modules that do one thing, the business rules apart
  from the framework, the database and the user interface, no duplicated logic.
- Fit the size: a short script stays one tidy file with functions; the structure grows when the
  project does. No layers or patterns that nothing uses yet.

## 5. The code

- No more code than the job needs: the standard library and well-known packages first.
- One short comment over each function saying what it does; more only where something is not
  obvious.
- Today's practices for the language: check the installed versions (`python3 --version`,
  `node --version`…) and the official documentation when unsure, instead of assuming old APIs.
- Dependencies inside the project (a `venv` or `uv`, local `npm`), never system-wide with sudo.
- Run what you build and test the parts that matter; tell the user what was and was not checked.
