#!/bin/bash
# Pre-push gate: block a `git push` that the repo's checks would fail.
# Runs as a PreToolUse hook on Bash(git push *) and Bash(git -C *).
#
# Order: a repo whose hooks directory is missing blocks, a repo with its own
# pre-push hook gates itself, a repo declaring `verify:fast` runs only that,
# and any other repo gets the guessed lint/typecheck/knip/test/build/audit run.
# Node checks run through the repo's own package manager.
# Exit code 2 blocks the action and sends the error message to Claude.
# Bypass with SKIP_PUSH_GATE=1, in the environment or inline in the command.

# shellcheck source=lib/resolve-repo.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-repo.sh"

# detect_package_manager <dir>
# The packageManager field, then the lockfile, walking up to the git top level
# so a workspace package finds the root's. Prints npm when nothing names one.
detect_package_manager() {
  local dir top field
  dir=$(cd "$1" && pwd -P)
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")
  while :; do
    if [ -f "$dir/package.json" ]; then
      field=$(jq -r '.packageManager // empty' "$dir/package.json" 2>/dev/null)
      case "${field%%@*}" in
        npm|pnpm|yarn) echo "${field%%@*}"; return ;;
      esac
    fi
    if [ -f "$dir/pnpm-lock.yaml" ]; then echo pnpm; return; fi
    if [ -f "$dir/yarn.lock" ]; then echo yarn; return; fi
    if [ -f "$dir/package-lock.json" ]; then echo npm; return; fi
    if [ "$dir" = "$top" ] || [ "$dir" = "/" ]; then break; fi
    dir=$(dirname "$dir")
  done
  echo npm
}

# install_cmd <manager>: the command that creates node_modules.
install_cmd() {
  case "$1" in
    npm) echo "npm ci" ;;
    *) echo "$1 install" ;;
  esac
}

# audit_base: print the merge-base this push builds on, or nothing. The
# branch's upstream is the already-pushed state, so its merge-base is exactly
# the delta this push adds. origin/HEAD, then the usual default branches,
# cover a first push. No base means the pushed dependency diff is unknowable,
# so the audit runs unconditionally.
audit_base() {
  local base mb
  for base in "$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)" \
              "$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" \
              origin/main origin/master; do
    [ -n "$base" ] || continue
    git rev-parse --verify --quiet "${base}^{commit}" >/dev/null 2>&1 || continue
    mb=$(git merge-base HEAD "$base" 2>/dev/null) || continue
    [ -n "$mb" ] && { printf '%s\n' "$mb"; return; }
  done
}

# dependency_files_changed <merge-base>: succeed when the committed diff
# touches a manifest or lockfile anywhere in the tree. A script-only
# package.json edit triggers the audit too; one extra audit is cheaper than
# field-level diffing.
dependency_files_changed() {
  git diff --name-only "$1" HEAD 2>/dev/null | grep -qE \
    '(^|/)(package(-lock)?\.json|npm-shrinkwrap\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb?)$'
}

# baseline_lockfile <merge-base> <manager>: print the lockfile the manager's
# audit reads when one exists in the merge-base tree, else nothing. A branch
# that introduces the lockfile carries only new findings, so no baseline
# comparison applies to it.
baseline_lockfile() {
  local mb="$1" pm="$2" f
  case "$pm" in
    npm) for f in package-lock.json npm-shrinkwrap.json; do
           git cat-file -e "$mb:$f" 2>/dev/null && { printf '%s\n' "$f"; return; }
         done ;;
    bun) for f in bun.lock bun.lockb; do
           git cat-file -e "$mb:$f" 2>/dev/null && { printf '%s\n' "$f"; return; }
         done ;;
    pnpm) git cat-file -e "$mb:pnpm-lock.yaml" 2>/dev/null && printf '%s\n' pnpm-lock.yaml ;;
    yarn) git cat-file -e "$mb:yarn.lock" 2>/dev/null && printf '%s\n' yarn.lock ;;
  esac
}

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only gate on `git push` (and not `git push --help`, etc.)
case "$COMMAND" in
  *"git push --help"*|*"git push -h"*) exit 0 ;;
  *"git push"*|*"git -C "*) ;;
  *) exit 0 ;;
esac

# Honor escape hatch. PreToolUse hooks inherit the Claude Code process env,
# not the tool command's, so an inline SKIP_PUSH_GATE=1 prefix is only
# visible in the command string.
case "$COMMAND" in
  *"SKIP_PUSH_GATE=1"*)
    echo "SKIP_PUSH_GATE=1 - bypassing pre-push gate." >&2
    exit 0 ;;
esac
if [ "$SKIP_PUSH_GATE" = "1" ]; then
  echo "SKIP_PUSH_GATE=1 - bypassing pre-push gate." >&2
  exit 0
fi

# `git -C <path> push` never contains the literal "git push", so a command
# without either is not ours to gate.
case "$COMMAND" in
  *"git push"*) ;;
  *) printf '%s\n' "$COMMAND" | grep -q 'git -C  *[^ ]*  *push' || exit 0 ;;
esac

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
DIR=$(resolve_repo_dir "$COMMAND" "$CWD" push)

# Husky points the repo-local core.hooksPath at a directory the install creates.
# A checkout that never ran it has the setting but not the directory, and git
# then skips every repo hook without a word, so the push would go out ungated.
# --type=path expands a leading ~ the way git does.
HOOKS_PATH=$(git -C "$DIR" config --local --type=path --get core.hooksPath 2>/dev/null)
if [ -n "$HOOKS_PATH" ]; then
  TOP=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)
  case "$HOOKS_PATH" in
    /*) HOOKS_DIR="$HOOKS_PATH" ;;
    *) HOOKS_DIR="$TOP/$HOOKS_PATH" ;;
  esac
  if [ -n "$TOP" ] && [ ! -d "$HOOKS_DIR" ]; then
    INSTALL=$(install_cmd "$(detect_package_manager "$TOP")")
    echo "[pre-push-gate] core.hooksPath is $HOOKS_PATH, but $HOOKS_DIR does not exist, so the repo's own hooks would not run. Run '$INSTALL' in $TOP, then push again." >&2
    exit 2
  fi
fi

# Find project root: walk up looking for package.json or *.tf
PROJECT_ROOT=""
PROJECT_TYPE=""
while [ "$DIR" != "/" ] && [ -n "$DIR" ]; do
  if [ -f "$DIR/package.json" ]; then
    PROJECT_ROOT="$DIR"
    PROJECT_TYPE="node"
    break
  fi
  if ls "$DIR"/*.tf >/dev/null 2>&1; then
    PROJECT_ROOT="$DIR"
    PROJECT_TYPE="terraform"
    break
  fi
  DIR=$(dirname "$DIR")
done

# No matching project - skip silently (Claude config repo, dotfiles, docs-only)
[ -z "$PROJECT_ROOT" ] && exit 0

cd "$PROJECT_ROOT" || exit 0

# A repo with its own pre-push hook runs its own full gate on this push, so
# running ours as well repeats every check. `--no-verify` skips the repo hook,
# so ours stays in force then.
case "$COMMAND" in
  *"--no-verify"*) ;;
  *)
    REPO_HOOK=$(git -C "$PROJECT_ROOT" rev-parse --path-format=absolute --git-path hooks/pre-push 2>/dev/null)
    if [ -n "$REPO_HOOK" ] && [ -x "$REPO_HOOK" ]; then
      echo "[pre-push-gate] $PROJECT_ROOT has its own pre-push hook, which gates this push." >&2
      exit 0
    fi
    ;;
esac

run_step() {
  local label="$1"
  local cmd="$2"
  echo "[pre-push-gate] $label..." >&2
  OUT=$(bash -c "$cmd" 2>&1)
  STATUS=$?
  if [ $STATUS -ne 0 ]; then
    echo "[pre-push-gate] $label FAILED. Fix before pushing (or set SKIP_PUSH_GATE=1 to bypass):" >&2
    echo "$OUT" | tail -40 >&2
    exit 2
  fi
}

if [ "$PROJECT_TYPE" = "node" ]; then
  PM=$(detect_package_manager "$PROJECT_ROOT")
  if ! command -v "$PM" >/dev/null 2>&1; then
    echo "[pre-push-gate] $PROJECT_ROOT uses $PM, which is not on PATH. Install it or enable corepack (or bypass with SKIP_PUSH_GATE=1)." >&2
    exit 2
  fi
  # A fresh worktree has no node_modules; the checks below would fail with
  # noise unrelated to the branch. Fail with the actionable step instead.
  if [ ! -d "$PROJECT_ROOT/node_modules" ]; then
    echo "[pre-push-gate] $PROJECT_ROOT has no node_modules - run '$(install_cmd "$PM")' there first (or bypass with SKIP_PUSH_GATE=1)." >&2
    exit 2
  fi
  # pnpm hands flags after the script name to the script, so --silent goes
  # before `run`. Yarn Berry has no --silent.
  case "$PM" in
    yarn) RUN="yarn run" ;;
    *) RUN="$PM --silent run" ;;
  esac
  has_script() {
    node -e "const p=require('./package.json'); process.exit(p.scripts?.['$1'] ? 0 : 1)" 2>/dev/null
  }
  # A repo that declares its fast gate owns the push checks.
  if has_script "verify:fast"; then
    run_step "verify:fast" "$PM run verify:fast"
    echo "[pre-push-gate] verify:fast passed." >&2
    exit 0
  fi
  has_script lint && run_step "lint" "CI=true $RUN lint"
  has_script typecheck && run_step "typecheck" "CI=true $RUN typecheck"
  has_script knip && run_step "knip" "CI=true $RUN knip"
  has_script test && run_step "test" "CI=true $RUN test"
  # A checkout with no local env, such as a fresh worktree, builds with the
  # committed template. CI builds with throwaway values the same way. The
  # template stays scoped to the build: test runners read env too.
  if [ ! -f .env ] && [ ! -f .env.local ] && [ -f .env.example ]; then
    has_script build && run_step "build (env from .env.example)" \
      "set -a && . ./.env.example && set +a && CI=true $RUN build"
  else
    has_script build && run_step "build" "CI=true $RUN build"
  fi
  # Only critical advisories block, and only when the pushed diff changes a
  # dependency file: pre-existing high/moderate transitive CVEs are
  # Dependabot's job, not a push gate's, and an unchanged dependency set
  # cannot grow a new critical finding. A failing branch audit is then
  # compared against its merge-base, audited from the committed tree with
  # no install: a base that fails the same way carries an inherited finding,
  # so the push passes with a notice; a base that passes means the finding
  # is new, so the push blocks. The comparison reads exit codes only, so a
  # dependency change that swaps one inherited critical for a different
  # critical still passes; catching that needs a human or CI.
  # npm audit needs package-lock.json, so a Bun repo audits its bun.lock with Bun.
  AUDIT_CMD=""
  AUDIT_PM="$PM"
  if [ -f bun.lock ] || [ -f bun.lockb ]; then
    AUDIT_PM=bun
    if command -v bun >/dev/null 2>&1; then
      AUDIT_CMD="bun audit --audit-level=critical"
    else
      echo "[pre-push-gate] audit skipped: bun is not installed." >&2
    fi
  else
    case "$PM" in
      npm) AUDIT_CMD="npm audit --audit-level=critical" ;;
      # Not --json: that form exits 1 on a finding of any severity.
      pnpm) AUDIT_CMD="pnpm audit --audit-level critical" ;;
      # Yarn Classic ignores --level for its exit code, a severity bitmask where
      # 16 is critical. Without --all --recursive, Yarn Berry audits only the
      # current workspace's direct deps.
      yarn)
        case "$(yarn --version 2>/dev/null)" in
          1.*) AUDIT_CMD='yarn audit --level critical; [ $(( $? & 16 )) -eq 0 ]' ;;
          *) AUDIT_CMD="yarn npm audit --all --recursive --severity critical" ;;
        esac
        ;;
    esac
  fi
  if [ -n "$AUDIT_CMD" ]; then
    MB=$(audit_base)
    if [ -z "$MB" ]; then
      RUN_AUDIT=1
    elif dependency_files_changed "$MB"; then
      RUN_AUDIT=1
    else
      RUN_AUDIT=0
      echo "[pre-push-gate] audit skipped: no dependency file changed since the merge-base." >&2
    fi
    if [ "$RUN_AUDIT" = 1 ]; then
      echo "[pre-push-gate] audit..." >&2
      AUDIT_OUT=$(bash -c "$AUDIT_CMD" 2>&1)
      AUDIT_STATUS=$?
      if [ "$AUDIT_STATUS" -ne 0 ]; then
        if [ -z "$MB" ]; then
          echo "[pre-push-gate] audit FAILED and no merge-base is available to compare against. Fix before pushing (or set SKIP_PUSH_GATE=1):" >&2
          echo "$AUDIT_OUT" | tail -40 >&2
          exit 2
        fi
        if [ -z "$(baseline_lockfile "$MB" "$AUDIT_PM")" ]; then
          echo "[pre-push-gate] audit FAILED and the merge-base lacks the $AUDIT_PM lockfile, so the finding is new. Fix before pushing (or set SKIP_PUSH_GATE=1):" >&2
          echo "$AUDIT_OUT" | tail -40 >&2
          exit 2
        fi
        BASE_TMP=$(mktemp -d "${TMPDIR:-/tmp}/pre-push-audit-base.XXXXXX")
        git archive "$MB" | tar -x -C "$BASE_TMP"
        if (cd "$BASE_TMP" && bash -c "$AUDIT_CMD") >/dev/null 2>&1; then
          rm -rf "${BASE_TMP:?}"
          echo "[pre-push-gate] audit FAILED with a critical finding the merge-base does not carry. Fix before pushing (or set SKIP_PUSH_GATE=1):" >&2
          echo "$AUDIT_OUT" | tail -40 >&2
          exit 2
        fi
        rm -rf "${BASE_TMP:?}"
        echo "[pre-push-gate] audit FAILED, but the merge-base fails the same audit, so the critical is inherited, not new. Pushing; fix the inherited finding soon." >&2
      fi
    fi
  fi
fi

if [ "$PROJECT_TYPE" = "terraform" ]; then
  command -v terraform >/dev/null 2>&1 || exit 0
  run_step "terraform fmt" "terraform fmt -check -recursive"
  run_step "terraform validate" "terraform validate"
fi

echo "[pre-push-gate] All checks passed." >&2
exit 0
