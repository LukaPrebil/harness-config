# Upstream backlog

Defects in `domengabrovsek/agent-config` that this fork deliberately does not fix. Each one was found while syncing through `7bb2849`. They stay in his code so the fork keeps its delta at zero and future syncs stay cheap.

Fix them upstream, then take the fix in the next sync. Do not patch them here.

## Security and control

- `hooks/lib/deny-gate.ts` writes the denied subject into its stderr message, and the subject is the command or the path that was denied. A token inside a denied argument, such as a credential in a remote URL, reaches stderr, tool feedback, and transcripts. Report the matched rule and a stable operation identifier instead of the argument.

- `hooks/lib/deny-gate.ts` reads `tool_name` and the other payload fields without validation. A payload whose `tool_name` is not a string throws, and `hooks/lib/dispatch.sh` swallows that ordinary error, so the call is never checked. Validate the fields and bound their lengths.

- `pi/extensions/hook-bridge.ts` and `hooks/lib/dispatch.sh` do not bind a dispatch to the session that started it. A cancelled child's hook group can keep changing files. The owner's death also removes the only timer that would have cleaned it up. Tie the owned process group to the session lifetime.

- `hooks/lib/dispatch.sh` can lose an explicit denial. A hook exits 2. A descendant still holds the captured pipes, so `communicate()` times out. The group is killed, and the branch returns without reading the collected exit code. Keep a collected exit 2 after the cleanup, and leave every other timeout fail-open.

- `hooks/pre-pr-reply-gate.sh` opens the body file named by `gh api -F body=@<path>` with a plain read. The gate can therefore read any file the user can, outside the native Read permissions. Resolve and validate body files against the repository root and the deny list before opening them.

## Parsing

- `hooks/lib/resolve-repo.sh` scans the whole command for `git -C <path>`, including quoted body text. A caller that resolves the repository through it and then fails to change into that directory checks nothing and passes. Ignore quoted regions, and fail closed when the resolved directory is absent.

- `hooks/post-edit-lint.sh` rewrites punctuation inside string literals and JSX text while it is correcting comment punctuation, which changes program data. Restrict the rewrite to comment ranges it can establish.

- `scripts/setup-hosts.sh` treats any command starting with the quoted dispatcher path as its own. A user control appended after `&&` is classified as stale and regenerated away. Require the complete generated command shape and reject anything else as foreign.

## Documentation

- The guides describe enforcement the hooks do not provide. `docs/architecture.md` says the deny list enforces hard limits outside the model. The same page says a check does not depend on the model remembering a rule, while ordinary hook failures and timeouts pass. Say that only an explicit exit 2 blocks a supported pre-action call.

- `CONTEXT.md` has no term for the hook registry, although `hooks/lib/dispatch.sh` and `docs/setup.md` both use the phrase.

## Build

- The workflows in `.github/workflows/` call shared actions at `@main`, so a change in the action repository reaches this repository's CI without review here. Pin the wrappers to a tag or a commit.

## Fork deltas, not upstream defects

These are not his bugs. They are the price of taking his documentation verbatim, recorded here so the next reader is not misled.

- `docs/setup.md`, `docs/decisions.md` and `docs/agents.md` name `pi/settings.json`, `pi/mcp.json` and a single Pi agent dir. This fork runs two Profiles, `pi/settings.work.json` and `pi/settings.personal.json`, with `pi/mcp-adapter.json`. The bootstrap and `pi/settings-parity.test.ts` describe the real layout.
- `docs/decisions.md` says the original ADRs stay in git history. In this fork they are live files under `docs/adr/`.
- `.github/workflows/reviewer.yml` is omitted. The AWS-backed CI reviewer stays deferred until its authority, credentials, and cost are approved.
