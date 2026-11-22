---
name: review-pr
description: "Reviews a pull request with a vetted multi-stage protocol: parallel reviewers, a skeptic pass that tries to disprove each finding against the code, standalone severity-calibrated drafts, and posting only after approval. Use when asked to review a PR, code-review a diff, or given a PR/MR number or URL."
---

Review the pull request: $ARGUMENTS

**why-no-hook:** review workflow guidance; each step requires reading the PR and judging code quality, evidence, and wording.

## Stage 0: fetch and understand

1. **Pick the platform CLI**: `gh` for GitHub, `glab` for GitLab. Judge from the PR URL or the repo's remote. `(review-time: see section note)`
2. **Fetch PR details**: title, body, files, commits, additions, deletions, base and head refs. `(review-time: see section note)`
3. **Read the full diff.** `(review-time: see section note)`
4. **Understand intent**: read the PR description, linked issues, and commit messages before judging any line. When a spec exists - issue refs in the commits, a linked issue, or a spec under `.claude/state/specs/` - check the diff against it for three things: requirements asked for but missing or partial, behavior nobody asked for, and requirements implemented wrong. Quote the spec line for each. `(review-time: see section note)`

## Stage 1: reviewers

1. **Brief every subagent for bounded output**: at most 40 bullets in the form `claim - file:line, doc link, or command output that proves it`, ending with `END OF REPORT`. A report without the marker is incomplete: ask that teammate for the remainder before using it. `(review-time: truncated subagent reports were a recurring failure in the usage data)`
1. **Spawn the matching experts** for the changed files (see `~/.agents/rules/agent-routing.md`), and the `Spec Verifier` when the spec has checked criteria. Work the checklist in [checklist.md](checklist.md) yourself in parallel; your own findings enter the same skeptic pass. `(review-time: see section note)`

## Stage 2: the skeptic

1. **Refute before you report.** Hand every finding, from subagents and from your own checklist pass, to one skeptic teammate: an advisory persona for a domain-weighted review, this session for a small one. The skeptic tries to disprove each finding against the code, the repo's existing patterns, and upstream references such as vendor docs and official templates. A finding dies when `(review-time: the drop decision is a judgment the user audits via the dropped list)`

- the code already handles it, or the reviewer misread it;
- its evidence is an unsourced number, a memory of a document, or a "should probably" instead of a citation;
- it proposes a speculative extra component that no reference or existing pattern requires;
- its severity was inflated: unless it is a confirmed correctness or security issue, BLOCKER is the wrong bucket.

The skeptic returns two lists: surviving findings with their verified evidence, and dropped findings with a one-line reason each.

## Stage 3: drafts

1. **Write each comment to stand alone.** The MR author never saw this session, so no chat references, no internal shorthand, no "as discussed". Name the file, the behavior, and the consequence, then suggest a fix. `(review-time: wording discipline, not mechanically checkable)`
2. **Calibrate severity**: BLOCKER only for confirmed correctness or security issues. Everything else is ISSUE, SUGGESTION, or NIT. `(review-time: see section note)`

## Stage 4: approval and posting

1. **Show the drafts and wait.** Present the full review - verdict, findings, the dropped-findings list with reasons - and stop for approval. Never post a review, a comment, or a thread reply beyond exactly what was approved. Replies to reviewer comments later follow the `pr-comments` skill. `(review-time: an outward action; the approval is the point)`
2. **Post once, after approval**: a single review with inline comments where the platform CLI supports it, otherwise one summary comment carrying the per-file findings. `(review-time: see section note)`

## Output format (shown for approval)

```markdown
## Summary

<1-2 sentence overall assessment>

## Verdict: APPROVE / REQUEST_CHANGES / NEEDS_DISCUSSION

<reason>

## Findings

### BLOCKER (must fix before merge)

- **[file:line]** - Description. Why it matters. Suggested fix.

### ISSUE (should fix, may approve with commitment to follow-up)

- **[file:line]** - Description. Recommendation.

### SUGGESTION (take it or leave it)

- **[file:line]** - Description. Alternative approach.

### NIT (style/preference, non-blocking)

- **[file:line]** - Description.

### PRAISE (good patterns worth highlighting)

- **[file:line]** - What is done well and why.

## Dropped by the skeptic (not reported to the author)

- **[file:line]** - The finding. Why it died.
```

If no `$ARGUMENTS` is provided, review changes in the current branch against the base branch using `git diff main...HEAD`; the protocol still applies, with `main` as the author to write for.
