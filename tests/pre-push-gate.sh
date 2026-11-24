#!/bin/bash
# Tests for the pre-push gate.
#
# A fresh worktree has no .env, and a build that validates its env fails
# there for reasons unrelated to the branch. The gate builds such a checkout
# with the committed .env.example, and leaves a checkout with its own env alone.
#
# A repo that declares `verify:fast` runs only that, and a checkout whose
# core.hooksPath directory is missing blocks until the install creates it.
#
# Node checks run through the repo's package manager. Those cases run the gate
# under a PATH of stub managers, so no real npm, pnpm, or yarn runs.

set -u

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(cd "${TMPDIR:-/tmp}" && pwd)
TEST_ROOT=$(cd "$(mktemp -d "$TMP_ROOT/pre-push-gate-test.XXXXXX")" && pwd)
PASSED=0
FAILED=0

cleanup() {
  case "$TEST_ROOT" in
    "$TMP_ROOT"/pre-push-gate-test.*) rm -rf "$TEST_ROOT" ;;
    *) echo "Refusing to clean unexpected test path: $TEST_ROOT" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM

pass() { PASSED=$((PASSED + 1)); echo "ok - $1"; }
fail() { FAILED=$((FAILED + 1)); echo "not ok - $1" >&2; }

# The build passes only when GATE_PROBE carries the template's value.
make_project() {
  local dir="$1"
  mkdir -p "$dir/node_modules"
  git -C "$dir" init -q
  cat > "$dir/package.json" <<'JSON'
{
  "name": "probe",
  "private": true,
  "scripts": {
    "build": "node -e \"process.exit(process.env.GATE_PROBE === 'from-template' ? 0 : 1)\""
  }
}
JSON
  printf '# comment\nGATE_PROBE=from-template\n' > "$dir/.env.example"
}

run_gate() {
  local dir="$1"
  printf '{"cwd":"%s","tool_input":{"command":"git push origin feature/x"}}' "$dir" \
    | (cd "$TEST_ROOT" && CLAUDE_PROJECT_DIR="" SKIP_PUSH_GATE="" bash "$PROJECT_DIR/hooks/pre-push-gate.sh" 2>&1)
}

FRESH="$TEST_ROOT/fresh"
make_project "$FRESH"
OUT=$(run_gate "$FRESH")
case "$OUT" in
  *"build (env from .env.example) FAILED"*) echo "    got: $OUT" >&2; fail "a checkout without .env builds with the template" ;;
  *"build (env from .env.example)..."*) pass "a checkout without .env builds with the template" ;;
  *) echo "    got: $OUT" >&2; fail "a checkout without .env builds with the template" ;;
esac

LOCAL="$TEST_ROOT/local"
make_project "$LOCAL"
printf 'GATE_PROBE=local\n' > "$LOCAL/.env"
OUT=$(run_gate "$LOCAL")
case "$OUT" in
  *".env.example"*) echo "    got: $OUT" >&2; fail "a checkout with .env does not load the template" ;;
  *"build FAILED"*) pass "a checkout with .env does not load the template" ;;
  *) echo "    got: $OUT" >&2; fail "a checkout with .env does not load the template" ;;
esac

run_gate_cmd() {
  local dir="$1" cmd="$2"
  printf '{"cwd":"%s","tool_input":{"command":"%s"}}' "$dir" "$cmd" \
    | (cd "$TEST_ROOT" && CLAUDE_PROJECT_DIR="" SKIP_PUSH_GATE="" bash "$PROJECT_DIR/hooks/pre-push-gate.sh" 2>&1)
}

HOOKED="$TEST_ROOT/hooked"
make_project "$HOOKED"
mkdir -p "$HOOKED/.git/hooks"
printf '#!/bin/sh\nexit 0\n' > "$HOOKED/.git/hooks/pre-push"
chmod +x "$HOOKED/.git/hooks/pre-push"
OUT=$(run_gate_cmd "$HOOKED" "git push origin feature/x")
case "$OUT" in
  *"has its own pre-push hook"*) pass "a repo with its own pre-push hook is not gated twice" ;;
  *) echo "    got: $OUT" >&2; fail "a repo with its own pre-push hook is not gated twice" ;;
esac

OUT=$(run_gate_cmd "$HOOKED" "git push --no-verify origin feature/x")
case "$OUT" in
  *"has its own pre-push hook"*) echo "    got: $OUT" >&2; fail "--no-verify keeps the gate in force" ;;
  *"build (env from .env.example)..."*) pass "--no-verify keeps the gate in force" ;;
  *) echo "    got: $OUT" >&2; fail "--no-verify keeps the gate in force" ;;
esac

HUSKY="$TEST_ROOT/husky"
make_project "$HUSKY"
mkdir -p "$HUSKY/.husky/_"
printf '#!/bin/sh\nexit 0\n' > "$HUSKY/.husky/_/pre-push"
chmod +x "$HUSKY/.husky/_/pre-push"
git -C "$HUSKY" config core.hooksPath .husky/_
OUT=$(run_gate_cmd "$HUSKY" "git push origin feature/x")
case "$OUT" in
  *"has its own pre-push hook"*) pass "a husky hooksPath hook counts as the repo's own gate" ;;
  *) echo "    got: $OUT" >&2; fail "a husky hooksPath hook counts as the repo's own gate" ;;
esac

NOHOOKS="$TEST_ROOT/nohooks"
make_project "$NOHOOKS"
git -C "$NOHOOKS" config core.hooksPath .husky/_
OUT=$(run_gate_cmd "$NOHOOKS" "git push origin feature/x"); STATUS=$?
case "$OUT" in
  *"Run 'npm ci'"*) [ "$STATUS" -eq 2 ] && pass "a missing hooksPath directory blocks the push" \
    || { echo "    exit $STATUS" >&2; fail "a missing hooksPath directory blocks the push"; } ;;
  *) echo "    got: $OUT" >&2; fail "a missing hooksPath directory blocks the push" ;;
esac

# A global hooksPath is not the repo's own setting, and git expands its ~.
GLOBALHOOKS="$TEST_ROOT/globalhooks"
make_project "$GLOBALHOOKS"
printf '[core]\n\thooksPath = ~/.githooks-missing\n' > "$TEST_ROOT/global.gitconfig"
OUT=$(GIT_CONFIG_GLOBAL="$TEST_ROOT/global.gitconfig" run_gate_cmd "$GLOBALHOOKS" "git push origin feature/x")
case "$OUT" in
  *"Run 'npm ci'"*) echo "    got: $OUT" >&2; fail "a global ~ hooksPath does not block the push" ;;
  *) pass "a global ~ hooksPath does not block the push" ;;
esac

# verify:fast fails unless it runs, so a pass proves it ran and nothing else did.
FAST="$TEST_ROOT/fast"
make_project "$FAST"
cat > "$FAST/package.json" <<'JSON'
{
  "name": "probe",
  "private": true,
  "scripts": {
    "verify:fast": "node -e \"require('fs').writeFileSync('ran-fast', '')\"",
    "test": "node -e \"process.exit(1)\""
  }
}
JSON
OUT=$(run_gate_cmd "$FAST" "git push origin feature/x"); STATUS=$?
if [ "$STATUS" -eq 0 ] && [ -f "$FAST/ran-fast" ] && ! printf '%s' "$OUT" | grep -q '\[pre-push-gate\] test'; then
  pass "a repo declaring verify:fast runs only that"
else
  echo "    exit $STATUS, got: $OUT" >&2; fail "a repo declaring verify:fast runs only that"
fi

cat > "$FAST/package.json" <<'JSON'
{ "name": "probe", "private": true, "scripts": { "verify:fast": "node -e \"process.exit(3)\"" } }
JSON
OUT=$(run_gate_cmd "$FAST" "git push origin feature/x"); STATUS=$?
case "$OUT" in
  *"verify:fast FAILED"*) [ "$STATUS" -eq 2 ] && pass "a failing verify:fast blocks the push" \
    || { echo "    exit $STATUS" >&2; fail "a failing verify:fast blocks the push"; } ;;
  *) echo "    got: $OUT" >&2; fail "a failing verify:fast blocks the push" ;;
esac

# A stub bun records its arguments, so a pass proves the audit ran through Bun.
BUNREPO="$TEST_ROOT/bunrepo"
make_project "$BUNREPO"
touch "$BUNREPO/bun.lock"
mkdir -p "$TEST_ROOT/stubbin"
printf '#!/bin/sh\necho "$@" > "%s/bun-args"\n' "$BUNREPO" > "$TEST_ROOT/stubbin/bun"
chmod +x "$TEST_ROOT/stubbin/bun"
OUT=$(PATH="$TEST_ROOT/stubbin:$PATH" run_gate_cmd "$BUNREPO" "git push origin feature/x"); STATUS=$?
if [ "$STATUS" -eq 0 ] && [ "$(cat "$BUNREPO/bun-args" 2>/dev/null)" = "audit --audit-level=critical" ]; then
  pass "a Bun repo audits with bun audit"
else
  echo "    exit $STATUS, got: $OUT" >&2; fail "a Bun repo audits with bun audit"
fi

# A PATH holding only the tools the gate needs leaves bun out.
mkdir -p "$TEST_ROOT/nobun"
for tool in bash sh env cat dirname ls grep tail jq git node npm; do
  ln -s "$(command -v "$tool")" "$TEST_ROOT/nobun/$tool"
done
OUT=$(PATH="$TEST_ROOT/nobun" run_gate_cmd "$BUNREPO" "git push origin feature/x"); STATUS=$?
case "$OUT" in
  *"audit skipped: bun is not installed"*) [ "$STATUS" -eq 0 ] && pass "a Bun repo without bun skips the audit" \
    || { echo "    exit $STATUS" >&2; fail "a Bun repo without bun skips the audit"; } ;;
  *) echo "    got: $OUT" >&2; fail "a Bun repo without bun skips the audit" ;;
esac

echo ""
echo "== package manager =="

# Only the tools the gate needs, plus stub managers that log their argv. A
# stub answers --version with STUB_VERSION and an audit with STUB_AUDIT_EXIT.
BIN="$TEST_ROOT/bin"
STUB_LOG="$TEST_ROOT/stub.log"
mkdir -p "$BIN"
for TOOL in bash cat dirname git grep head jq ls node sed tail mktemp tar rm; do
  TOOL_PATH=$(command -v "$TOOL") || { echo "Missing required tool: $TOOL" >&2; exit 1; }
  ln -s "$TOOL_PATH" "$BIN/$TOOL"
done

make_stub() {
  cat > "$BIN/$1" <<'STUB'
#!/bin/bash
echo "${0##*/} $*" >> "$STUB_LOG"
case " $* " in
  *" --version "*) echo "${STUB_VERSION:-1.0.0}" ;;
  *" audit "*) exit "${STUB_AUDIT_EXIT:-0}" ;;
esac
exit 0
STUB
  chmod +x "$BIN/$1"
}
make_stub npm
make_stub pnpm

PM_MANIFEST='{"scripts":{"lint":"x","build":"x"}}'

# pm_project <name> [package.json]: a repo with node_modules. Prints its path.
pm_project() {
  local dir="$TEST_ROOT/pm-$1"
  mkdir -p "$dir/node_modules"
  git -C "$dir" init -q
  printf '%s\n' "${2:-$PM_MANIFEST}" > "$dir/package.json"
  echo "$dir"
}

# run_pm_gate <dir>: sets OUT and STATUS, and starts STUB_LOG empty.
run_pm_gate() {
  : > "$STUB_LOG"
  OUT=$(printf '{"cwd":"%s","tool_input":{"command":"git push origin feature/x"}}' "$1" \
    | (cd "$TEST_ROOT" && PATH="$BIN" STUB_LOG="$STUB_LOG" CLAUDE_PROJECT_DIR="" SKIP_PUSH_GATE="" \
      bash "$PROJECT_DIR/hooks/pre-push-gate.sh" 2>&1))
  STATUS=$?
}

exited() { [ "$STATUS" -eq "$1" ]; }
says() { case "$OUT" in *"$1"*) return 0 ;; *) return 1 ;; esac; }
logged() { grep -qxF -- "$1" "$STUB_LOG"; }
never_ran() { ! grep -q -- "^$1 " "$STUB_LOG"; }

# check <name> <predicate> [args...]
check() {
  local name="$1"
  shift
  if "$@"; then pass "$name"; else
    echo "    exit $STATUS, got: $OUT" >&2
    echo "    calls: $(paste -sd ';' - < "$STUB_LOG")" >&2
    fail "$name"
  fi
}

REPO=$(pm_project pnpm-field '{"packageManager":"pnpm@10.4.1","scripts":{"lint":"x","build":"x"}}')
run_pm_gate "$REPO"
check "the packageManager field selects pnpm and passes" exited 0
check "scripts run through pnpm with --silent before run" logged "pnpm --silent run lint"
check "the audit uses the pnpm non-JSON form" logged "pnpm audit --audit-level critical"
check "npm never runs in a pnpm repo" never_ran npm

REPO=$(pm_project pnpm-lock)
: > "$REPO/pnpm-lock.yaml"
run_pm_gate "$REPO"
check "pnpm-lock.yaml selects pnpm" logged "pnpm --silent run build"

REPO=$(pm_project field-wins '{"packageManager":"pnpm@10.4.1","scripts":{}}')
: > "$REPO/package-lock.json"
run_pm_gate "$REPO"
check "the packageManager field beats a stray package-lock.json" \
  logged "pnpm audit --audit-level critical"

REPO=$(pm_project workspace)
: > "$REPO/pnpm-lock.yaml"
mkdir -p "$REPO/apps/web/node_modules"
echo '{"scripts":{"build":"x"}}' > "$REPO/apps/web/package.json"
run_pm_gate "$REPO/apps/web"
check "a push from a workspace package finds the root lockfile" logged "pnpm --silent run build"

REPO=$(pm_project pnpm-critical)
: > "$REPO/pnpm-lock.yaml"
STUB_AUDIT_EXIT=1 run_pm_gate "$REPO"
check "a failing pnpm audit blocks" exited 2
check "the block names the audit step" says "audit FAILED"

REPO=$(pm_project pnpm-fast '{"packageManager":"pnpm@10.4.1","scripts":{"verify:fast":"x"}}')
run_pm_gate "$REPO"
check "verify:fast runs through the repo's manager" logged "pnpm run verify:fast"

REPO=$(pm_project npm-lock)
: > "$REPO/package-lock.json"
run_pm_gate "$REPO"
check "package-lock.json passes" exited 0
check "scripts run through npm" logged "npm --silent run lint"
check "the audit uses npm" logged "npm audit --audit-level=critical"

REPO=$(pm_project no-lock)
run_pm_gate "$REPO"
check "no field and no lockfile falls back to npm" logged "npm audit --audit-level=critical"

rm "$BIN/pnpm"
REPO=$(pm_project pnpm-missing)
: > "$REPO/pnpm-lock.yaml"
run_pm_gate "$REPO"
check "a missing package manager blocks" exited 2
check "the block names the missing manager" says "uses pnpm, which is not on PATH"
make_stub pnpm

REPO=$(pm_project no-modules)
: > "$REPO/pnpm-lock.yaml"
rmdir "$REPO/node_modules"
run_pm_gate "$REPO"
check "a missing node_modules blocks" exited 2
check "the block names the pnpm install" says "run 'pnpm install' there first"

REPO=$(pm_project pnpm-husky)
: > "$REPO/pnpm-lock.yaml"
git -C "$REPO" config core.hooksPath .husky/_
run_pm_gate "$REPO"
check "a missing hooksPath directory names the pnpm install" says "Run 'pnpm install' in"

make_stub yarn

REPO=$(pm_project yarn-classic)
: > "$REPO/yarn.lock"
STUB_VERSION=1.22.22 run_pm_gate "$REPO"
check "yarn.lock with Yarn Classic passes" exited 0
check "scripts run through yarn run" logged "yarn run lint"
check "Yarn Classic audits with yarn audit" logged "yarn audit --level critical"

STUB_VERSION=1.22.22 STUB_AUDIT_EXIT=12 run_pm_gate "$REPO"
check "Yarn Classic high and moderate findings (mask 12) pass" exited 0

STUB_VERSION=1.22.22 STUB_AUDIT_EXIT=17 run_pm_gate "$REPO"
check "Yarn Classic critical findings (mask 17) block" exited 2

REPO=$(pm_project yarn-berry '{"packageManager":"yarn@4.5.0","scripts":{"build":"x"}}')
STUB_VERSION=4.5.0 run_pm_gate "$REPO"
check "the packageManager field selects Yarn Berry and passes" exited 0
check "Yarn Berry audits every workspace and transitive dep" \
  logged "yarn npm audit --all --recursive --severity critical"

STUB_VERSION=4.5.0 STUB_AUDIT_EXIT=1 run_pm_gate "$REPO"
check "a failing Yarn Berry audit blocks" exited 2

echo ""
echo "== .nvmrc Node =="

# A fake nvm whose resolver knows one installed version. Its node logs a
# marker and runs the real node, so a logged marker proves the gate put the
# pinned Node first on PATH.
FAKE_NVM="$TEST_ROOT/nvm"
REAL_NODE=$(command -v node)
mkdir -p "$FAKE_NVM/versions/node/v24.1.0/bin"
cat > "$FAKE_NVM/nvm.sh" <<'NVM'
nvm_version() {
  case "$1" in
    24|v24.1.0) echo v24.1.0 ;;
    *) echo N/A; return 3 ;;
  esac
}
NVM
printf '#!/bin/bash\necho "nvm-node" >> "$STUB_LOG"\nexec "%s" "$@"\n' "$REAL_NODE" \
  > "$FAKE_NVM/versions/node/v24.1.0/bin/node"
chmod +x "$FAKE_NVM/versions/node/v24.1.0/bin/node"
used_nvm_node() { grep -qx nvm-node "$STUB_LOG"; }
skipped_nvm_node() { ! used_nvm_node; }

REPO=$(pm_project nvmrc-installed)
: > "$REPO/package-lock.json"
printf '24 # pinned\n' > "$REPO/.nvmrc"
NVM_DIR="$FAKE_NVM" run_pm_gate "$REPO"
check "an installed .nvmrc version passes" exited 0
check "the checks run on the .nvmrc Node" used_nvm_node

mkdir -p "$REPO/packages/app/node_modules"
echo '{"scripts":{"build":"x"}}' > "$REPO/packages/app/package.json"
NVM_DIR="$FAKE_NVM" run_pm_gate "$REPO/packages/app"
check "a workspace package finds the root .nvmrc" used_nvm_node

REPO=$(pm_project nvmrc-missing)
: > "$REPO/package-lock.json"
echo 22 > "$REPO/.nvmrc"
NVM_DIR="$FAKE_NVM" run_pm_gate "$REPO"
check "an uninstalled .nvmrc version blocks" exited 2
check "the block names the nvm install" says "Run 'nvm install 22'"
check "no check runs before the install" never_ran npm

REPO=$(pm_project nvmrc-no-nvm)
: > "$REPO/package-lock.json"
echo 24 > "$REPO/.nvmrc"
NVM_DIR="$TEST_ROOT/no-nvm" run_pm_gate "$REPO"
check "an .nvmrc without nvm keeps the PATH Node" exited 0
check "no nvm means no nvm Node" skipped_nvm_node

REPO=$(pm_project no-nvmrc)
: > "$REPO/package-lock.json"
NVM_DIR="$FAKE_NVM" run_pm_gate "$REPO"
check "a repo without .nvmrc keeps the PATH Node" skipped_nvm_node

echo ""
echo "== dependency audit =="

# These cases need commits and a merge-base, so each repo gets a bare origin,
# a base commit on main, and a feature branch. The stub audit fails only
# where the tree carries an audit-fail marker, so a tree's audit result
# follows its committed content.
make_audit_stub() {
  cat > "$BIN/npm" <<'STUB'
#!/bin/bash
echo "npm $*" >> "$STUB_LOG"
case " $* " in
  *" --version "*) echo "1.0.0" ;;
  *" audit "*)
    [ -f audit-fail ] && exit 1
    [ -f audit-loud ] && { echo "3 vulnerabilities (1 critical) found"; exit 1; }
    ;;
esac
exit 0
STUB
  chmod +x "$BIN/npm"
}
make_audit_stub

seed_audit_repo() {
  local dir="$1"
  mkdir -p "$dir/node_modules"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email t@t
  git -C "$dir" config user.name t
  git -C "$dir" config commit.gpgsign false
  printf '%s\n' '{"scripts":{"build":"x"}}' > "$dir/package.json"
  : > "$dir/package-lock.json"
  git -C "$dir" add -A
  git -C "$dir" commit -qm base
  git -C "$dir" init -q --bare "$dir-origin.git"
  git -C "$dir" remote add origin "$dir-origin.git"
  echo "$dir"
}

push_base_and_branch() {
  git -C "$1" push -q origin main
  git -C "$1" checkout -qb feature/x
}

never_ran_audit() { ! grep -q -- '^npm audit' "$STUB_LOG"; }
audit_runs() { [ "$(grep -c -- '^npm audit' "$STUB_LOG")" = "$1" ]; }
tmp_audit_dirs() { ls -d "${TMPDIR:-/tmp}"/pre-push-audit.* 2>/dev/null | wc -l | tr -d ' '; }

REPO=$(seed_audit_repo "$TEST_ROOT/audit-unchanged")
push_base_and_branch "$REPO"
echo x > "$REPO/src.ts"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "feat: src only"
run_pm_gate "$REPO"
check "an unchanged dependency set skips the audit" exited 0
check "the skip says so" says "audit skipped: no dependency file changed"
check "no audit ran" never_ran_audit

REPO=$(seed_audit_repo "$TEST_ROOT/audit-inherited")
: > "$REPO/audit-loud"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "chore: marker on main"
push_base_and_branch "$REPO"
echo x >> "$REPO/package-lock.json"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "chore: bump dep"
BEFORE_TMP=$(tmp_audit_dirs)
run_pm_gate "$REPO"
check "an inherited critical passes the gate" exited 0
check "the inherited notice names the merge-base" says "inherited, not new"
check "both the branch and the merge-base were audited" audit_runs 2
check "no extraction temp dirs leaked" test "$(tmp_audit_dirs)" = "$BEFORE_TMP"

REPO=$(seed_audit_repo "$TEST_ROOT/audit-new-finding")
push_base_and_branch "$REPO"
: > "$REPO/audit-loud"
echo x >> "$REPO/package-lock.json"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "chore: bump dep, add marker"
BEFORE_TMP=$(tmp_audit_dirs)
run_pm_gate "$REPO"
check "a critical the merge-base lacks blocks" exited 2
check "the block names the new finding" says "the merge-base does not carry"
check "both the branch and the merge-base were audited" audit_runs 2
check "a blocking run leaks no extraction temp dirs" test "$(tmp_audit_dirs)" = "$BEFORE_TMP"

REPO=$(seed_audit_repo "$TEST_ROOT/audit-new-lockfile")
rm "$REPO/package-lock.json"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "chore: drop lockfile"
push_base_and_branch "$REPO"
: > "$REPO/package-lock.json"
: > "$REPO/audit-loud"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "chore: add lockfile"
run_pm_gate "$REPO"
check "a newly introduced lockfile has no baseline" exited 2
check "the block names the missing lockfile" says "merge-base lacks the npm lockfile"
check "only the branch was audited" audit_runs 1

REPO=$(seed_audit_repo "$TEST_ROOT/audit-nested-manifest")
push_base_and_branch "$REPO"
mkdir -p "$REPO/packages/foo"
printf '%s\n' '{"name":"foo"}' > "$REPO/packages/foo/package.json"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "feat: workspace manifest"
run_pm_gate "$REPO"
check "a nested workspace manifest triggers the audit" exited 0
check "the audit ran once" audit_runs 1

REPO=$(seed_audit_repo "$TEST_ROOT/audit-branch-inconclusive")
push_base_and_branch "$REPO"
: > "$REPO/audit-fail"
echo x >> "$REPO/package-lock.json"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "chore: silent audit failure"
run_pm_gate "$REPO"
check "a failed audit without a findings report blocks" exited 2
check "the block says the comparison cannot run" says "without a findings report"
check "the merge-base was never audited" audit_runs 1

REPO=$(seed_audit_repo "$TEST_ROOT/audit-base-inconclusive")
: > "$REPO/audit-fail"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "chore: silent failure on main"
push_base_and_branch "$REPO"
rm "$REPO/audit-fail"
: > "$REPO/audit-loud"
echo x >> "$REPO/package-lock.json"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "chore: loud failure, dep change"
run_pm_gate "$REPO"
check "a baseline without a findings report blocks" exited 2
check "the block says the comparison is inconclusive" says "inconclusive"
check "both trees were audited" audit_runs 2

REPO=$(seed_audit_repo "$TEST_ROOT/audit-no-base")
push_base_and_branch "$REPO"
: > "$REPO/audit-loud"
echo x >> "$REPO/package-lock.json"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "chore: dep change"
rm -rf "$REPO-origin.git"
git -C "$REPO" remote remove origin
run_pm_gate "$REPO"
check "no merge base falls back to a plain block" exited 2
check "the block names the missing merge-base" says "no merge-base is available"
check "only the branch was audited" audit_runs 1

REPO=$(seed_audit_repo "$TEST_ROOT/audit-extraction-fails")
push_base_and_branch "$REPO"
: > "$REPO/audit-loud"
echo x >> "$REPO/package-lock.json"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "chore: dep change"
rm "$BIN/tar"
run_pm_gate "$REPO"
check "a failed extraction blocks the push" exited 2
check "the block names the extraction failure" says "could not be extracted"
check "no audit ran" never_ran_audit
ln -s "$(command -v tar)" "$BIN/tar"

echo ""
echo "$PASSED passed; $FAILED failed"
[ "$FAILED" -eq 0 ]
