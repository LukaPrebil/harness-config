#!/bin/bash
# SessionEnd hook: opportunistically prune safely-disposable worktrees in
# the current repo, then converge its main checkout to the latest default
# branch. Conservative - only removes worktrees whose branch is
# upstream-gone, merged into default, or squash-merged, and convergence
# only fast-forwards or stashes-with-note. Always exits 0; never blocks.
# Disable per-session with CLAUDE_DISABLE_WORKTREE_CLEANUP=1.

set -u

if [ "${CLAUDE_DISABLE_WORKTREE_CLEANUP:-0}" = "1" ]; then
  exit 0
fi

SCRIPT="$CLAUDE_PROJECT_DIR/scripts/worktree-prune.sh"
[ -x "$SCRIPT" ] || SCRIPT="$HOME/.claude/scripts/worktree-prune.sh"
[ -x "$SCRIPT" ] || exit 0

# Only run inside a git repo
git -C "$PWD" rev-parse --show-toplevel >/dev/null 2>&1 || exit 0

# Run apply mode silently. The script is conservative; it will skip anything
# uncertain and only remove obviously-safe entries.
"$SCRIPT" --apply >/dev/null 2>&1 || true

# Converge the main checkout to the latest default branch. Same advisory
# posture: failures never block, and session-end output is discarded anyway.
# The stash message is the durable note a later session reads.
CONV="$CLAUDE_PROJECT_DIR/scripts/checkout-converge.sh"
[ -x "$CONV" ] || CONV="$HOME/.claude/scripts/checkout-converge.sh"
[ -x "$CONV" ] && "$CONV" "$PWD" >/dev/null 2>&1 || true
exit 0
