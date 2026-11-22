#!/bin/bash
# checkout-converge: keep a repo's main checkout on its latest default branch.
# Branch work belongs in worktrees; a main checkout parked on a stale branch
# drifts, and every session that reads it pays for the drift.
#
# Usage:
#   checkout-converge.sh [--fast] [<repo-dir>]   # default $PWD; a worktree
#                                                # arg resolves to its repo's
#                                                # main checkout
#   --fast: teardown-hook mode; no LLM summarizer and a short fetch cap, so a
#           session shutdown stays bounded. Skills run the full mode.
#
# Order of operations:
#   1. Resolve the default branch: origin/HEAD, else the first of
#      origin/main, origin/master, origin/trunk that exists. No remote
#      default means nothing to converge to; exit 0.
#   2. Fetch the default branch from origin. Offline: converge against the
#      local remote-tracking ref and say so.
#   3. Already on the default branch: fast-forward when behind.
#   4. Clean tree on another branch: check out the default, fast-forward.
#   5. Dirty tree on another branch: stash push -u with an LLM-written
#      message (best effort, timed, deterministic fallback), check out the
#      default, fast-forward, and print where the work went.
#
# The stash is never popped. WIP belongs to its branch, and a conflicted pop
# is worse than the staleness this script fixes. `git stash list` shows the
# message, so a later session finds the work by reading it.
#
# Summarizer: $CHECKOUT_CONVERGE_SUMMARIZER holds a shell command that reads
# a capped working-tree diff on stdin and prints one short line. Unset, the
# script probes claude (haiku), then pi's default model for the active
# profile. Any failure falls back to a diffstat line; convergence never
# waits on the model.
#
# Exit codes: 0 always (advisory, never blocks).

set -u

# --fast: the teardown-hook mode. Session end gets bounded work - no LLM
# summarizer, a short fetch cap - because a blocked shutdown is worse than
# a plainer stash name. Interactive runs from skills use the full path.
FAST=0
if [ "${1:-}" = "--fast" ]; then FAST=1; shift; fi
FETCH_SECONDS=30
[ "$FAST" = 1 ] && FETCH_SECONDS=10
DIR="${1:-$PWD}"

# resolve_main <dir>: print the main checkout dir, or nothing for a bare repo
# or a non-repo. A worktree's --git-common-dir is the main checkout's .git.
resolve_main() {
  local common
  # --path-format=absolute needs git >= 2.31; older git fails here and the
  # script exits 0, so convergence silently no-ops on ancient clients.
  common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 0
  case "$common" in
    */.git) printf '%s\n' "${common%/.git}" ;;
    *) return 0 ;;  # bare repo, or .git file without a worktree
  esac
}

# default_branch <main>: print origin's default branch name, or nothing.
default_branch() {
  local d
  d=$(git -C "$1" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
  if [ -n "$d" ] \
    && git -C "$1" rev-parse --verify --quiet "refs/remotes/origin/$d" >/dev/null 2>&1; then
    printf '%s\n' "${d#origin/}"; return
  fi
  for cand in main master trunk; do
    git -C "$1" rev-parse --verify --quiet "refs/remotes/origin/$cand" >/dev/null 2>&1 \
      && { printf '%s\n' "$cand"; return; }
  done
}

# timeout_run <secs> <cmd...>: run with a timeout everywhere. Stock macOS
# ships neither timeout nor gtimeout, so a background watchdog enforces the
# cap there; the command is killed and the non-zero status surfaces to the
# caller's fallback.
timeout_run() {
  local secs="$1" pid dog status
  shift
  if command -v timeout >/dev/null 2>&1; then timeout "$secs" "$@"; return; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@"; return; fi
  "$@" &
  pid=$!
  ( sleep "$secs"; kill "$pid" 2>/dev/null ) &
  dog=$!
  wait "$pid" 2>/dev/null
  status=$?
  kill "$dog" 2>/dev/null
  wait "$dog" 2>/dev/null
  return "$status"
}

# summarize <main>: print one line describing the working tree, or nothing.
summarize() {
  local main="$1" input summary
  input=$( { git -C "$main" diff HEAD | head -c 10240; printf '\n-- untracked --\n'; git -C "$main" status --porcelain; } 2>/dev/null )
  [ -n "$input" ] || return 0
  if [ -n "${CHECKOUT_CONVERGE_SUMMARIZER:-}" ]; then
    summary=$(printf '%s' "$input" | timeout_run 20 bash -c "$CHECKOUT_CONVERGE_SUMMARIZER" 2>/dev/null | head -1)
  elif command -v claude >/dev/null 2>&1; then
    summary=$(printf '%s' "$input" | timeout_run 20 claude -p --model haiku \
      "Summarize this working-tree diff in at most 12 words. Reply with the summary only." 2>/dev/null | head -1)
  elif command -v pi >/dev/null 2>&1; then
    summary=$(printf '%s' "$input" | timeout_run 20 pi --print \
      "Summarize this working-tree diff in at most 12 words. Reply with the summary only." 2>/dev/null | head -1)
  fi
  summary=$(printf '%s' "$summary" | tr -d '\r\n"' | cut -c1-100)
  [ -n "$summary" ] && printf '%s' "$summary"
}

# stash_message <main> <branch>: print the message for the auto-stash.
stash_message() {
  local main="$1" branch="$2" summary shortstat
  if [ "$FAST" != 1 ]; then
    summary=$(summarize "$main")
  fi
  if [ -z "${summary:-}" ]; then
    shortstat=$(git -C "$main" diff HEAD --shortstat 2>/dev/null | tr -d '\n')
    summary=${shortstat:-"uncommitted changes"}
  fi
  printf 'wip(%s): %s [auto-stashed %s]' "$branch" "$summary" "$(date +%F)"
}

# fast_forward <main> <default>: move the default branch to origin's tip.
fast_forward() {
  local main="$1" default="$2" before
  before=$(git -C "$main" rev-parse HEAD 2>/dev/null)
  if git -C "$main" merge --ff-only "origin/$default" --quiet >/dev/null 2>&1 \
    && [ "$(git -C "$main" rev-parse HEAD 2>/dev/null)" != "$before" ]; then
    printf '[checkout-converge] %s fast-forwarded to origin/%s.\n' "$main" "$default"
  fi
  return 0
}

MAIN=$(resolve_main "$DIR")
[ -n "$MAIN" ] || exit 0
DEFAULT=$(default_branch "$MAIN")
[ -n "$DEFAULT" ] || exit 0

if ! timeout_run "${FETCH_SECONDS}" git -C "$MAIN" fetch --quiet origin "$DEFAULT" 2>/dev/null; then
  printf '[checkout-converge] fetch failed for %s; converging against the local origin/%s ref.\n' "$MAIN" "$DEFAULT" >&2
fi

BRANCH=$(git -C "$MAIN" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)

# A detached HEAD is not a branch to move away from; its commit is reachable
# only through the reflog, so before anything else the commit is pinned to a
# named branch (found in review: converging away from a detached HEAD left
# committed work with no durable trace).
STASH_BRANCH="$BRANCH"
if [ "$BRANCH" = "HEAD" ]; then
  STASH_BRANCH="converge-detached/$(git -C "$MAIN" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  git -C "$MAIN" branch "$STASH_BRANCH" >/dev/null 2>&1
  printf '[checkout-converge] %s was detached; its commit is preserved on branch %s.\n' "$MAIN" "$STASH_BRANCH" >&2
fi

DIRTY=$(git -C "$MAIN" status --porcelain 2>/dev/null)

if [ "$BRANCH" = "$DEFAULT" ]; then
  fast_forward "$MAIN" "$DEFAULT"
  exit 0
fi

if [ -n "$DIRTY" ]; then
  MSG=$(stash_message "$MAIN" "$STASH_BRANCH")
  if ! git -C "$MAIN" stash push -u -m "$MSG" >/dev/null 2>&1; then
    printf '[checkout-converge] %s is dirty on %s and the stash failed; leaving it alone.\n' "$MAIN" "$BRANCH" >&2
    exit 0
  fi
  printf '[checkout-converge] %s was dirty on %s. WIP stashed as: %s\n' "$MAIN" "$STASH_BRANCH" "$MSG" >&2
  printf '[checkout-converge] restore it with: git -C %s stash pop\n' "$MAIN" >&2
fi

if ! git -C "$MAIN" checkout --quiet "$DEFAULT" 2>/dev/null; then
  printf '[checkout-converge] could not check out %s in %s; leaving it alone.\n' "$DEFAULT" "$MAIN" >&2
  exit 0
fi
printf '[checkout-converge] %s moved from %s to %s.\n' "$MAIN" "$BRANCH" "$DEFAULT"
fast_forward "$MAIN" "$DEFAULT"
exit 0
