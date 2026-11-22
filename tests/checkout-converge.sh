#!/bin/bash
# Tests for checkout-converge.sh.
#
# Convergence keeps a repo's main checkout on its latest default branch:
# fast-forward when behind, check out the default when the tree is clean,
# stash-with-note when it is dirty, and never touch anything when no
# remote default exists or the local default has diverged. Fixtures use a
# local bare origin, so fetches never touch the network.

set -u

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(cd "${TMPDIR:-/tmp}" && pwd)
TEST_ROOT=$(cd "$(mktemp -d "$TMP_ROOT/checkout-converge-test.XXXXXX")" && pwd)
PASSED=0
FAILED=0

cleanup() {
  case "$TEST_ROOT" in
    "$TMP_ROOT"/checkout-converge-test.*) rm -rf "$TEST_ROOT" ;;
    *) echo "Refusing to clean unexpected test path: $TEST_ROOT" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM

pass() { PASSED=$((PASSED + 1)); echo "ok - $1"; }
fail() { FAILED=$((FAILED + 1)); echo "not ok - $1" >&2; }

# make_repo <name>: a repo on main with a bare origin and upstream set.
make_repo() {
  local dir="$TEST_ROOT/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  # CI runners carry no global git identity; without this the commit fails
  # and every later push dies on a missing main refspec.
  git -C "$dir" config user.email t@t
  git -C "$dir" config user.name t
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" config user.email t@t
  git -C "$dir" config user.name t
  echo base > "$dir/file.txt"
  git -C "$dir" add -A
  git -C "$dir" commit -qm base
  git -C "$dir" init -q --bare "$dir-origin.git"
  git -C "$dir" remote add origin "$dir-origin.git"
  git -C "$dir" push -q origin main
  echo "$dir"
}

# advance_origin <dir> <content>: a throwaway clone pushes a commit to
# origin/main, so the repo falls behind its remote.
advance_origin() {
  local dir="$1" content="$2" clone
  clone="$dir-advancer"
  git clone -q "$dir-origin.git" "$clone"
  git -C "$clone" config user.email t@t
  git -C "$clone" config user.name t
  echo "$content" > "$clone/file.txt"
  git -C "$clone" add -A
  git -C "$clone" commit -qm "advance: $content"
  git -C "$clone" push -q origin main
}

SUMMARIZER='echo stub summary'

run_conv() {
  CHECKOUT_CONVERGE_SUMMARIZER="$SUMMARIZER" \
    bash "$PROJECT_DIR/scripts/checkout-converge.sh" "$1" 2>&1
}

says() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
branch_is() { [ "$(git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null)" = "$2" ]; }
head_is() { [ "$(git -C "$1" rev-parse HEAD 2>/dev/null)" = "$(git -C "$1" rev-parse "$2" 2>/dev/null)" ]; }

# A checkout on the default branch fast-forwards to the remote tip.
REPO=$(make_repo ff)
advance_origin "$REPO" second
OUT=$(run_conv "$REPO")
if says "$OUT" "fast-forwarded" && head_is "$REPO" origin/main; then
  pass "a behind default branch fast-forwards"
else
  echo "    got: $OUT" >&2; fail "a behind default branch fast-forwards"
fi

# A current default branch is a silent no-op.
REPO=$(make_repo current)
OUT=$(run_conv "$REPO")
if [ -z "$OUT" ] && branch_is "$REPO" main; then
  pass "a current default branch is a silent no-op"
else
  echo "    got: $OUT" >&2; fail "a current default branch is a silent no-op"
fi

# A clean tree on a feature branch moves to the default and fast-forwards.
REPO=$(make_repo clean-switch)
git -C "$REPO" checkout -qb feature/x
advance_origin "$REPO" second
OUT=$(run_conv "$REPO")
if says "$OUT" "moved from feature/x to main" && branch_is "$REPO" main && head_is "$REPO" origin/main; then
  pass "a clean feature branch converges to the default"
else
  echo "    got: $OUT" >&2; fail "a clean feature branch converges to the default"
fi

# A dirty tree stashes with the summarizer's line, note printed, never popped.
REPO=$(make_repo dirty-switch)
git -C "$REPO" checkout -qb feature/x
echo wip >> "$REPO/file.txt"
echo new > "$REPO/untracked.txt"
advance_origin "$REPO" second
OUT=$(run_conv "$REPO")
STASHES=$(git -C "$REPO" stash list)
if says "$STASHES" "wip(feature/x): stub summary [auto-stashed" \
  && branch_is "$REPO" main && head_is "$REPO" origin/main \
  && says "$OUT" "restore it with:" \
  && [ ! -e "$REPO/untracked.txt" ]; then
  pass "a dirty feature branch stashes with a named message and converges"
else
  echo "    got: $OUT" >&2; echo "    stash: $STASHES" >&2
  fail "a dirty feature branch stashes with a named message and converges"
fi

# A failed summarizer falls back to the diffstat, still converges.
REPO=$(make_repo dirty-fallback)
git -C "$REPO" checkout -qb feature/x
echo wip >> "$REPO/file.txt"
SUMMARIZER='exit 1'
advance_origin "$REPO" second
OUT=$(run_conv "$REPO")
STASHES=$(git -C "$REPO" stash list)
SUMMARIZER='echo stub summary'
if says "$STASHES" "wip(feature/x): 1 file changed" && branch_is "$REPO" main; then
  pass "a failed summarizer falls back to the diffstat"
else
  echo "    got: $OUT" >&2; echo "    stash: $STASHES" >&2
  fail "a failed summarizer falls back to the diffstat"
fi

# --fast skips the summarizer entirely and names the stash from the diffstat.
REPO=$(make_repo fast-mode)
git -C "$REPO" checkout -qb feature/x
echo wip >> "$REPO/file.txt"
advance_origin "$REPO" second
OUT=$(CHECKOUT_CONVERGE_SUMMARIZER="$SUMMARIZER" \
  bash "$PROJECT_DIR/scripts/checkout-converge.sh" --fast "$REPO" 2>&1)
STASHES=$(git -C "$REPO" stash list)
if says "$STASHES" "wip(feature/x): 1 file changed" \
  && ! says "$STASHES" "stub summary" && branch_is "$REPO" main; then
  pass "--fast skips the summarizer and uses the diffstat name"
else
  echo "    got: $OUT" >&2; echo "    stash: $STASHES" >&2
  fail "--fast skips the summarizer and uses the diffstat name"
fi

# A broken remote URL still converges against the local tracking ref.
REPO=$(make_repo offline)
advance_origin "$REPO" second
git -C "$REPO" fetch -q origin
git -C "$REPO" remote set-url origin "$TEST_ROOT/nonexistent.git"
OUT=$(run_conv "$REPO")
if says "$OUT" "fetch failed" && head_is "$REPO" origin/main; then
  pass "an offline fetch converges against the local tracking ref"
else
  echo "    got: $OUT" >&2; fail "an offline fetch converges against the local tracking ref"
fi

# No remote default means nothing to converge to.
REPO="$TEST_ROOT/no-remote"
mkdir -p "$REPO"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.email t@t
git -C "$REPO" config user.name t
echo base > "$REPO/file.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -qm base
OUT=$(run_conv "$REPO")
if [ -z "$OUT" ] && branch_is "$REPO" main; then
  pass "a repo with no remote is left alone"
else
  echo "    got: $OUT" >&2; fail "a repo with no remote is left alone"
fi

# A diverged local default is never force-moved.
REPO=$(make_repo diverged)
echo local > "$REPO/local.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -qm "local-only commit"
LOCAL_SHA=$(git -C "$REPO" rev-parse HEAD)
advance_origin "$REPO" second
OUT=$(run_conv "$REPO")
if [ "$(git -C "$REPO" rev-parse HEAD)" = "$LOCAL_SHA" ] && branch_is "$REPO" main; then
  pass "a diverged local default stays where it is"
else
  echo "    got: $OUT" >&2; fail "a diverged local default stays where it is"
fi

# A worktree argument converges the main checkout, not the worktree.
REPO=$(make_repo from-worktree)
git -C "$REPO" checkout -qb feature/wt
echo wip >> "$REPO/file.txt"
WT="$REPO-wt"
git -C "$REPO" worktree add -q "$WT" -b feature/other main
OUT=$(run_conv "$WT")
STASHES=$(git -C "$REPO" stash list)
if says "$STASHES" "wip(feature/wt): stub summary" && branch_is "$REPO" main \
  && branch_is "$WT" feature/other; then
  pass "a worktree argument converges the main checkout"
else
  echo "    got: $OUT" >&2; echo "    stash: $STASHES" >&2
  fail "a worktree argument converges the main checkout"
fi

# A detached HEAD is pinned to a named branch before the checkout moves.
REPO=$(make_repo detached)
git -C "$REPO" checkout -qb feature/x
echo detach > "$REPO/detached.txt"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "feat: detached work"
DETACHED_SHA=$(git -C "$REPO" rev-parse --short HEAD)
git -C "$REPO" checkout -q --detach
OUT=$(run_conv "$REPO")
if says "$OUT" "preserved on branch converge-detached/" && branch_is "$REPO" main \
  && git -C "$REPO" rev-parse --verify --quiet "converge-detached/${DETACHED_SHA}" >/dev/null 2>&1; then
  pass "a detached checkout is pinned to a branch before converging"
else
  echo "    got: $OUT" >&2
  fail "a detached checkout is pinned to a branch before converging"
fi

# origin/HEAD resolution takes the primary documented path when set.
REPO=$(make_repo origin-head)
git -C "$REPO" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git -C "$REPO" checkout -qb feature/x
advance_origin "$REPO" second
OUT=$(run_conv "$REPO")
if branch_is "$REPO" main && head_is "$REPO" origin/main; then
  pass "an origin/HEAD fixture converges through the primary path"
else
  echo "    got: $OUT" >&2; fail "an origin/HEAD fixture converges through the primary path"
fi

echo ""
echo "$PASSED passed; $FAILED failed"
[ "$FAILED" -eq 0 ]
