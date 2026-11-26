# Cheatsheet

Intent → skill. Claude Code accepts the `/name` notation shown below. In Codex or Pi, invoke the same shared skill by name; host-specific notation in a skill maps to the equivalent available capability.

For every skill with its kind and how it loads, see [skills](docs/skills.md). For the full text of one, see its `skills/<name>/SKILL.md`.

## "I want to..."

Each skill runs on its own. Pick the ones a task needs, in the order that fits it.

| Intent | Tool |
| --- | --- |
| Understand an unfamiliar code area | `/research <topic>` |
| Define formal requirements before planning | `/spec <topic>` |
| Turn an approved spec into vertical slices | `/plan` |
| Hand over a whole feature: approve the spec, get a green PR | `/deliver <goal>` |
| Stress-test a plan / reach alignment before code | `/grill-with-docs <topic>` |
| Build the agreed plan | `/build` |
| Write tests for code (TDD or prove-it) | `/build <target>` (test-writing mode) |
| Investigate a prod incident with evidence-first hypothesis ranking | `/debug <error>` |
| Review someone's PR | `/review-pr 567` |
| Verify everything before pushing | `/verify-done` |
| Open a PR/MR (reuses a verify pass at HEAD or runs `/verify-done`, then checks commit format and the title) | `/mr` |
| Watch CI on the current branch | `/ci` |
| Address reviewer comments on a PR (bots answered, humans drafted) | `/pr-comments` |
| Make a diagram (drawio) | `/diagram <topic>` |
| Save the session's work as a diary entry | `/summarize` |
| Refresh a library's API docs (React, Prisma, Next.js, etc.) | mention the library by name; `rules/context7.md` sends the agent to the `ctx7` CLI. Claude Code loads that rule in every session, and Codex and Pi load it through `rulebook` |
| Write or edit a skill | `/write-a-skill` |
| Work on a task in its own worktree | `/worktree <slug>` |
| Clean up a worktree after its branch merged | `/worktree-merge` |
| Prune dead worktrees in this repo | `/worktrees [--apply]` |
| Audit worktrees across all repos under `~/dev/` | `/worktrees --all [--apply]` |
| Drive several PRs to done in parallel | `/drive-fleet` |
| Plan an effort too big for one session | `/wayfinder` |
| Hand this session to a fresh one | `/handoff` |
| Review code for over-engineering only | `/prune` |

## When the slash IS the value

Some skills enforce a discipline plain English would skip. Use the slash when you want the structure:

- `/grill-with-docs` - the decision-tree walk is the point
- `/debug` - evidence-first hypothesis ranking before any code change
- `/build` - quality gates per task; its TESTING.md owns standalone test writing
- `/spec` - stakeholder-framed requirements doc
- `/verify-done` - the repo's `npm run verify` when declared, otherwise every CI step in CI's exact order
- `/mr` - verify pass at HEAD + commit-format + title-regex gates before opening
- `/review-pr` - vetted review: reviewers, skeptic, standalone drafts, posting after approval

## Skills that fire on their own

Every skill except `/deliver`, `/wayfinder`, and `/wait-what` can start on its own when your request matches its description. Those three start only when you type them. These four fire most often without being named:

- `rulebook` - loads the detailed standards a task needs from `rules/`
- `write-plain` - fires on prose work: docs, ADRs, specs, PR bodies
- `jira` - fires on a Jira key, ticket mention, or an atlassian.net URL
- `sentry-issue` - fires on a Sentry short ID or a sentry.io URL

## When plain English is fine

Lightweight helpers; structure is minimal:

- `/diagram`, plus the Claude Code built-ins `/loop` and `/schedule`

## Hand over a whole feature

`/deliver <goal>` chains skills for a whole feature. You approve the spec, and it runs research, planning, tests-first building, verification, the PR, CI, and bot comments. It ends when the PR is open, CI is green, and every bot comment has a reply. [Skills](docs/skills.md#how-deliver-runs) lists when it stops for you and shows its flow.

## Other intents

These cover work outside a feature change:

- `/debug` for incidents
- `/review-pr` for reviewing others' code
- `/document` for engineering docs
- `/diagram` for architecture or sequence diagrams
- `/resolve-conflicts` for an in-progress merge or rebase conflict
- `/wizard` for human-only setup steps (credentials, CI secrets, dashboards)
- `/wait-what` when the last reply did not land

## Agents

In Claude Code, `rules/agent-routing.md` maps each specialized domain to a persona, and the session spawns that persona through the Agent tool, with the persona as `subagent_type`, when a task touches the domain. You can also ask for a persona by name. Pi spawns the same personas as child sessions through the `pi-subagents` package, including background runs and worktree-isolated lanes. Codex maps `Agent` and `SendMessage` to its own teammate mechanisms when available, and follows the workflow locally otherwise. [Personas](docs/personas.md) lists every persona and its domain. See [ADR 0008](docs/adr/0008-share-agent-config-across-hosts.md) for the shared boundary and [ADR 0009](docs/adr/0009-pi-adapter-vendored-settings-and-extensions.md) for the Pi adapter.
