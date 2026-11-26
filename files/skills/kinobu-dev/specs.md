# Specs: what to build, written before the code

Code built from a loose request is guesswork, and a chat ends or gets summarised. A written spec
gives you the user's intent, small tasks that can each be checked, and a way for a new
conversation to carry on from `CONTEXT.md` and the active spec without rereading the code.

## How much to write

| Change | What to write |
|---|---|
| A typo, a small fix, a one-file script | The acceptance criteria in the conversation, then the user's yes |
| A feature | `spec.md` and `tasks.md`; `plan.md` only if it adds modules, data or dependencies |
| A new app, a large feature, a change of architecture | All three |

When the user brings their own spec, plan or format, keep it: fill only the gaps it leaves and
never reword what they wrote.

## The files

One folder per feature, `specs/NNN-short-name/` (`001-login`), kept in git, in English like
`CONTEXT.md`. Short: lists and tables, no prose, no code.

`spec.md`, what and why, with no technology in it:

```markdown
# <Feature>
Status: draft | approved | done
## Goal
Who needs it and why, in one or two lines.
## User stories
- As <someone>, I want <action>, so that <benefit>.
## Acceptance criteria
- AC1: When <trigger>, the app <response>.
- AC2: If <unwanted case>, the app <response>.
## Out of scope
## Open questions
```

Each criterion is one behaviour that a test or a command can show; a criterion nobody can check
is rewritten. An open question is asked to the user, never answered by guessing.

`plan.md`, how: the architecture (or a pointer to `AGENTS.md`), the modules and files it
touches, the data, the interfaces (commands, endpoints, screens, function signatures), each new
dependency and why, the risks, and "Versions and docs" (below). Decisions that last go to
`AGENTS.md` too.

`tasks.md`, the steps in order:

```markdown
- [ ] T1: <one change in a few files> (AC1). Check: <test or command>
```

A task is done in one go, leaves the program working, names the criteria it meets and how it is
checked. Its tests come with it, not at the end.

## Versions and docs

Before planning code against a language, library or framework, bring what you know up to date:

1. The version installed in the project: `python3 --version`, `uv pip show NAME`, `npm ls NAME`,
   `NAME --version`. For a new dependency, the latest stable release.
2. Its official docs: find the page with WebSearch if needed; try the site's `/llms.txt` first.
3. Read them with WebFetch and a precise question, for example "the API for <task> in version
   <X>, and what changed or was deprecated since <Y>": WebFetch returns the answer, not the page.
   Official sources only (the project's site, its repository and changelog).
4. Note the result in `plan.md` under "Versions and docs": each version, the few API facts the
   tasks rely on, the links. It is done once per feature and again only when a dependency is
   added or upgraded; a later conversation reads it instead of fetching again.
5. A page that cannot be read: use the installed package's own docs or source, and say what
   could not be checked.

## The loop

1. Ask until no open question is left, then write `spec.md`. Tell the user in their language and
   plain words what the app will and will not do, and wait for their yes: `Status: approved`.
2. Write `plan.md` and `tasks.md`. For a new app, the architecture goes into `AGENTS.md`.
3. One task at a time. Read only the spec, that task and the files it names. Run its check,
   tick it, and commit when a group of tasks works. `CONTEXT.md` names the active spec and the
   next task.
4. When something new or different comes up, stop: change the spec (and ask the user if it
   changes what they agreed), then the tasks, then the code. Nothing is built beyond the spec.
5. When every criterion is checked: `Status: done`, and tell the user what was and was not
   checked.

## Apps with an AI model inside

The spec also says what the model may do (its tools), what it must never do, what waits for the
user's approval, its limits (cost, time, steps) and the data it sees. Add `evals.md` or a test
file: example inputs, each with the expected answer or the rule it must follow. Run them after
every change to the prompts, the tools or the model.
