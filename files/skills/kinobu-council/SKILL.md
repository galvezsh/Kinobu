---
name: @APP_ID@-council
description: >
  A council of independent advisors that pressure-tests an idea, plan or decision and gives an
  honest verdict. Use it when the user asks to debate, council, pressure-test or stress-test
  something, or asks whether a choice with real stakes is a good one ("is this a good idea?",
  "should I do X or Y?"). Not for facts with one answer or for writing tasks.
---
<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->

# The council

An AI that helps the user tends to agree with them, and a long conversation pulls it further.
The council asks independent advisors, each from a fixed angle, who see only a neutral brief
and never the conversation, then a chair who weighs them by evidence and says what to do.

## When

- The user asks for a debate or a council, or asks whether an idea or a choice with real stakes
  is a good one ("I want to build an app that does X: is it a good idea?"): run the quick
  council at once, and end by saying in one line that a thorough one is there if they want it.
- A decision costly to undo that the user did not ask about (the spec of a new app, an
  architecture, spending money, deleting things, a change of direction): offer it in one line,
  never run it unasked.
- Not for a question with one right answer, a lookup, or a writing or summarising task: answer it.

## Levels

| Level | When | Advisors | Review | Subagents |
|---|---|---|---|---|
| Quick (default) | Most questions | For, Against, The problem | None | 4 |
| Thorough | The user asks for it ("thorough", "in depth") | All five | Two anonymous reviewers | 8 |

## 1. The brief

- Read the little that gives context: `CONTEXT.md`, `AGENTS.md`, the active spec, the files the
  user named, an earlier `debate.md` on the same topic.
- Write a neutral brief in English, 150 to 300 words: the decision and its options, the goal, the
  context and constraints, what is known (with numbers), what is at stake. No opinion of yours
  and no leaning: it must read the same to whoever wants a yes or a no.
- If the question is too vague to brief, ask the user one question, then go on.

## 2. The advisors

Start them all at once, in one message, as subagents (Claude Code: the Agent tool, general
purpose, model `sonnet`). Each gets its angle, the brief and the rules below, nothing else.

- **For**: the strongest honest case for it, and what would make it work even better than hoped.
- **Against**: assume it has a fatal flaw and find it: what fails, what it costs that nobody
  counted, what is taken for granted.
- **The problem**: what is really being solved? Strip the assumptions; say so if the question
  is the wrong one, and name the simplest way to reach the goal.
- **The outsider** (thorough): reads the brief as a newcomer to the field: what is unclear, what
  only insiders would believe, how it looks to the people it is for.
- **The doer** (thorough): can it be done with these people, money and time? The first concrete
  step, and what would block it.

Rules for every advisor, written into its prompt:

- Lean fully into your angle and do not balance: the others cover the rest.
- Check at most two facts that decide something (the project's files, an official page with
  WebFetch). Mark each claim `[checked]` or `[assumed]`; never make up numbers.
- 150 to 250 words, no preamble.

## 3. The review (thorough only)

Shuffle the answers, label them A to E without their angles, and start two reviewers at once
(model `sonnet`), each with the brief and the labelled answers: which answer is strongest and
why, which has the biggest blind spot, what all of them missed. Under 200 words each.

## 4. The chair

One more subagent on your own model (no model given). It gets the brief, the answers with their
angles and the reviews, and these instructions:

- Weigh reasoning and evidence, not how many agree: it may side with one advisor against all
  the others, saying why.
- An `[assumed]` claim the verdict depends on becomes a check to do first.
- Answer in this order: the verdict in one line (go, go with changes, not yet, or no) · where
  they agree · where they clash, both sides and why · blind spots (thorough) · what would change
  the verdict · the one thing to do first.

## 5. Tell the user

- In their language and plain words, short, in the chair's order. When the verdict goes against
  what the user hoped, say it plainly: softening it to please defeats the council.
- Add your own view only where you disagree with the chair, marked as yours.
- When it shapes a project, keep it: the brief and the chair's verdict (not the advisors' full
  text) in `specs/<feature>/debate.md`, or `docs/decisions/<date>-<topic>.md` outside a feature,
  so a new conversation knows what was decided and why. Otherwise offer to keep it.
