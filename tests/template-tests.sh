#!/usr/bin/env bash
#
# Tests of the template itself: generates throwaway projects and checks that the stages of
# scripts/check pass and fail where they should. Needs uv, git, jq, node/npm (docs lint), network
# (PyPI, npm, Copier, Spec Kit) and the pinned scanners on PATH (gitleaks, trivy, opengrep, vale); the checks of this
# repository itself run at the end (shellcheck, zizmor via uvx).
#
#   tests/template-tests.sh [workdir]        (default: a new temp dir; kept, its path is printed)
#
# osv.dev is not needed: the malicious-package gate is tested with a stub osv-scanner.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
work="${1:-$(mktemp -d)}"; mkdir -p "$work"; cd "$work" || exit 1
res="$work/results.txt"; : > "$res"
strip() { sed 's/\x1b\[[0-9;]*m//g'; }
G() { git -c user.name=t -c user.email=t@t "$@"; }
# expect <name> <want exit> <command...>  (output of the command is shown only on a mismatch)
expect() {
    local name="$1" want="$2"; shift 2
    local out rc; out="$("$@" 2>&1)"; rc=$?; out="$(strip <<<"$out")"
    if [[ "$rc" == "$want" ]]; then echo "ok   $name" | tee -a "$res"
    else echo "FAIL $name (exit $rc, want $want)" | tee -a "$res"; sed 's/^/       /' <<<"$out" | tail -n 12; fi
}
# expect_out <name> <regex that must appear> <command...>
expect_out() {
    local name="$1" re="$2"; shift 2
    local out; out="$("$@" 2>&1 | strip)"
    if grep -qE -- "$re" <<<"$out"; then echo "ok   $name" | tee -a "$res"
    else echo "FAIL $name (no match for: $re)" | tee -a "$res"; sed 's/^/       /' <<<"$out" | tail -n 12; fi
}
gen() { # dir stack [extra --data ...]
    local d="$1" st="$2"; shift 2
    uvx --from copier==9.7.1 copier copy --trust --defaults --vcs-ref HEAD "$here" "$d" \
        --data project_name=T --data issue_key=TST --data stack="$st" --data platform=github "$@" >/dev/null 2>&1
}
commit_all() { (cd "$1" && git add -A && G commit -q --no-verify -m init && git update-ref refs/remotes/origin/dev HEAD); }

echo "== day 0 (stack none): everything green, also in CI mode"
gen none none; commit_all none
(
cd none || exit 1
expect "none: scripts/check all" 0 scripts/check all
expect "none: scripts/check all with CI=1" 0 env CI=1 scripts/check all
expect_out "none: stack-layer skips without code" "SKIP stack-layer" scripts/check stack-layer
)

echo "== writing rule (Vale), AI attribution, lint-file hook"
(
cd none || exit 1
D() { scripts/check docs-file docs/w.md; }
doc() { printf '# Title\n\n%s\n' "$1" > docs/w.md; }
rule() { # <rule> <bad text> <good text>
    doc "$2"; expect "writing: $1 fails (docs-file)" 1 D
    expect_out "writing: $1 is named in the output" "DevStandard\.$1" D
    doc "$3"; expect "writing: $1 fixed passes" 0 D
}
rule Pronouns "You run the check." "The check runs."
rule History "The check is now stricter." "The check is strict."
rule Filler "This is simply a check." "This is a check."
rule Hedging "The hook should work." "The hook blocks force pushes."
rule Exclamation "The check passes!" "The check passes."
rule Emoji "Ready ✅." "Ready."
rule Watermarks "Co-Authored-By: Claude <noreply@anthropic.com>" "The commit has no trailer."
doc "The hook blocks pushes. We say so. <!-- vale off -->We say so here.<!-- vale on -->"
expect "writing: text outside vale off still fails" 1 D
doc "<!-- vale off -->
We say so.

<!-- vale on -->

The check passes."
expect "writing: <!-- vale off --> works" 0 D
doc "$(printf 'The check reads the file and %.0s' {1..8}) then it prints a long sentence that has more than thirty words in it."
expect "writing: a warning-only doc passes" 0 D
expect_out "writing: ... and the warning is printed" "more than 30 words" D
rm docs/w.md
echo "-- full docs stage"
printf '# Title\n\nYou run it.\n' > docs/w.md; G add -A; expect "docs: a doc with an error rule fails the stage" 1 scripts/check docs
printf '# Title\n\nThe check runs.\n' > docs/w.md; expect "docs: the fixed doc passes the stage" 0 scripts/check docs
echo "-- source comments (Vale reads Python, TypeScript, Rust, Go, C#; not shell or Dart)"
for ext in py ts rs go cs; do
    case $ext in py) c='# we do this';; *) c='// we do this';; esac
    printf '%s\nx = 1\n' "$c" > "w.$ext"; expect "writing: a first-person $ext comment fails" 1 scripts/check docs-file "w.$ext"
    printf '%s\n' "${c/we do this/the check does this}" > "w.$ext"; expect "writing: the fixed $ext comment passes" 0 scripts/check docs-file "w.$ext"
done
printf 'x = "we do this"\n' > w.py; expect "writing: a string literal is not read" 0 scripts/check docs-file w.py
printf '# TODO: fix this\n' > w.py; expect "writing: TODO without a key fails" 1 scripts/check docs-file w.py
printf '# TODO(TST-12): fix this\n' > w.py; expect "writing: TODO(KEY-n) passes" 0 scripts/check docs-file w.py
printf '# we do this\n' > w.sh; expect "writing: shell comments are not read (documented)" 0 scripts/check docs-file w.sh
rm -f w.* docs/w.md
echo "-- pr-text"
expect "pr-text: a body with 'you' fails" 1 env PR_BODY="Please check that you agree." scripts/check pr-text
expect "pr-text: a watermark fails" 1 env PR_BODY=$'Fixes the bug.\n\nCo-Authored-By: Claude <noreply@anthropic.com>' scripts/check pr-text
expect "pr-text: a session link fails" 1 env PR_BODY="See https://claude.ai/code/session_01AbCdEf for the run." scripts/check pr-text
expect "pr-text: a clean body passes" 0 env PR_BODY=$'## What and why\n\nThe check reads the body and fails on a watermark.' scripts/check pr-text
expect "pr-text: an empty body is skipped" 0 env PR_BODY="" scripts/check pr-text
echo "-- commit-msg and pr-title"
m() { printf '%s\n' "$1" > "$work/msg"; scripts/check commit-msg "$work/msg"; }
expect "commit-msg: a Co-Authored-By Claude trailer is rejected" 1 m $'feat(TST-1): add a thing\n\nCo-Authored-By: Claude <noreply@anthropic.com>'
expect "commit-msg: a Claude-Session line is rejected" 1 m $'fix(TST-2): stop a crash\n\nClaude-Session: https://claude.ai/code/session_01AbCdEf'
expect "commit-msg: a Generated with line is rejected" 1 m $'docs: explain it\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)'
expect "commit-msg: a human Co-Authored-By trailer is accepted" 0 m $'feat(TST-3): add a thing\n\nCo-Authored-By: Pat Doe <pat@example.org>'
expect "commit-msg: a plain message is accepted" 0 m "feat(TST-4): add a thing"
expect "pr-title: a watermark fails" 1 scripts/check pr-title "feat(TST-5): add a thing 🤖"
echo "-- settings and hooks"
expect "settings.json has the empty attribution" 0 jq -e '.attribution == {"commit": "", "pr": "", "sessionUrl": false}' .claude/settings.json
expect "settings.json denies writes to .vale.ini and .vale" 0 jq -e '.sandbox.filesystem.denyWrite | (index("./.vale.ini") and index("./.vale"))' .claude/settings.json
expect ".guardrails lists the Vale files" 0 grep -q '^\^\\.vale/' .guardrails
printf '# Title\n\nYou run it.\n' > docs/w.md
hook() { echo "{\"tool_input\":{\"file_path\":\"$PWD/$1\"}}" | CLAUDE_PROJECT_DIR=$PWD bash .claude/hooks/format-file.sh; }
expect "lint-file hook: a Markdown error exits 2" 2 hook docs/w.md
expect_out "lint-file hook: ... and reports the rule on stderr" "DevStandard.Pronouns" hook docs/w.md
printf '# Title\n\nThe check runs.\n' > docs/w.md
out="$(hook docs/w.md 2>&1)"; rc=$?
if [[ $rc -eq 0 && -z "$out" ]]; then echo "ok   lint-file hook: a clean file is silent (exit 0)" | tee -a "$res"; else echo "FAIL lint-file hook: a clean file is silent (exit $rc: $out)" | tee -a "$res"; fi
expect "lint-file hook: a file outside the project is ignored" 0 bash -c 'echo "{\"tool_input\":{\"file_path\":\"/etc/hostname\"}}" | CLAUDE_PROJECT_DIR=$PWD bash .claude/hooks/format-file.sh'
rm -f docs/w.md; G reset -q; G checkout -q -- . 2>/dev/null; true
echo "-- installer: one tool"
expect_out "install-tools vale installs the pinned version" "vale +vale version 3\.26\.0" scripts/install-tools vale
)

echo "== agent workflow and CI files of generated projects"
gen agent none --data github_agent=true --data network_api=true --data safety_critical=true
gen gl none --data platform=gitlab
(
cd agent || exit 1
expect "agent: workflows have no zizmor findings" 0 uvx zizmor@1.33.1 --offline --min-severity medium .github/workflows/
expect "agent: claude-agent.yml labels the PR" 0 grep -q 'gh pr edit "\$pr" --add-label agent' .github/workflows/claude-agent.yml
expect "agent: claude-agent.yml allows gh pr create and the label edit" 0 grep -q 'Bash(gh pr create:\*),Bash(gh pr edit --add-label agent:\*)' .github/workflows/claude-agent.yml
expect "agent: checks.yml runs pr-text on the PR body through env" 0 grep -q 'PR_BODY: \${{ github.event.pull_request.body }}' .github/workflows/checks.yml
expect "agent: no AI-use checkbox in the PR template" 1 grep -q 'AI use' .github/pull_request_template.md
expect "agent: the PR template has the agent checklist" 0 grep -q 'PRs labelled `agent`' .github/pull_request_template.md
)
(
cd gl || exit 1
expect "gitlab: the CI file parses" 0 uvx --from pyyaml==6.0.4 python -I -c 'import yaml; d = yaml.safe_load(open(".gitlab-ci.yml")); assert "PR_BODY" in d["mr-rules"]["variables"] and "docs" in d'
expect "gitlab: no AI-use checkbox in the MR template" 1 grep -q 'AI use' .gitlab/merge_request_templates/Default.md
)

echo "== this repository: its own checks, hooks and files"
expect "repo: scripts/lint passes" 0 bash -c "cd '$here' && scripts/lint"
expect "repo: scripts/check docs passes (writing rule on README, TODO, PLAN, preset, stacks, template docs)" 0 bash -c "cd '$here' && scripts/check docs"
expect_out "repo: scripts/check hooks passes" "PASS hooks" bash -c "cd '$here' && scripts/check hooks"
expect "repo: workflows have no zizmor findings" 0 uvx zizmor@1.33.1 --offline --min-severity medium "$here/.github/workflows/"
expect "repo: commit-msg uses the key STD" 1 bash -c "cd '$here' && printf 'feat(APP-1): x\n' > '$work/m' && scripts/check commit-msg '$work/m'"
expect "repo: commit-msg accepts STD" 0 bash -c "cd '$here' && printf 'feat(STD-81): x\n' > '$work/m' && scripts/check commit-msg '$work/m'"
for f in format-file lint-file parse-input protect-paths run-checks git-policy; do
    expect "repo: .claude/hooks/$f.sh equals the rendered template hook" 0 cmp "$here/.claude/hooks/$f.sh" "none/.claude/hooks/$f.sh"
done
expect "repo: .claude/settings.json equals the template's except denyWrite" 0 bash -c "diff <(jq -S 'del(.sandbox.filesystem.denyWrite)' '$here/.claude/settings.json') <(jq -S 'del(.sandbox.filesystem.denyWrite)' none/.claude/settings.json)"
expect "repo: .vale.ini sections equal the template's" 0 bash -c "diff <(sed -n '/^\[\*\.md\]/,\$p' '$here/.vale.ini') <(sed -n '/^\[\*\.md\]/,\$p' '$here/template/.vale.ini')"
expect "repo: the Vale pins of check.config come from the template" 0 bash -c "cd '$here' && source ./check.config && [[ -n \$VALE_VERSION && \$VALE_SHA256 == \$(grep -oP '^VALE_SHA256=\"\K[0-9a-f]+' template/check.config.jinja) ]]"

echo "== python project with code"
gen py python --data safety_critical=true
(
cd py || exit 1
cat > pyproject.toml <<'EOF'
[project]
name = "t"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = []

[dependency-groups]
dev = ["ruff", "mypy", "pytest", "pytest-cov"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/t"]

[tool.pytest.ini_options]
pythonpath = ["src"]
markers = ["safety: safety tests"]
EOF
mkdir -p src/t tests; printf '"""t."""\n' > src/t/__init__.py; touch tests/__init__.py
printf '"""Calc."""\n\n\ndef add(a: int, b: int) -> int:\n    """Add."""\n    return a + b\n' > src/t/calc.py
printf 'import pytest\n\nfrom t.calc import add\n\n\ndef test_add() -> None:\n    assert add(1, 2) == 3\n\n\n@pytest.mark.safety\ndef test_safety_limit() -> None:\n    assert add(0, 0) == 0\n' > tests/test_calc.py
(uv lock && uv sync --frozen) >/dev/null 2>&1
commit_all .

echo "-- stack-layer"
expect "stack-layer: empty variables WARN locally (exit 0)" 0 scripts/check stack-layer
expect_out "stack-layer: ... and say so" "WARN stack-layer: 8 undecided" scripts/check stack-layer
expect "stack-layer: empty variables FAIL in CI" 1 env CI=1 scripts/check stack-layer
for v in ARCH COMPLEXITY PERF E2E CONTRACT SECURITY_NATIVE FUZZ DAST; do sed -i "s/^${v}_CMD=\"\"\$/${v}_CMD=\"none\"/" check.config; done
expect "stack-layer: none without a reason FAILs in CI" 1 env CI=1 scripts/check stack-layer
for v in ARCH COMPLEXITY PERF E2E CONTRACT SECURITY_NATIVE FUZZ DAST; do sed -i "s/^${v}_CMD=\"none\"\$/${v}_CMD=\"none\"   # test: not applicable/" check.config; done
expect "stack-layer: none with a reason PASSes in CI" 0 env CI=1 scripts/check stack-layer
sed -i 's/^COMPLEXITY_CMD=.*/COMPLEXITY_CMD="uv run ruff check --select C901 --config '"'"'lint.mccabe.max-complexity=10'"'"' src"/' check.config
expect "complexity: simple code passes" 0 scripts/check complexity
python3 -c "print('def f(x: int) -> int:\n' + ''.join(f'    if x == {i}:\n        return {i}\n' for i in range(15)) + '    return 0')" > src/t/complex.py
expect "complexity: a 16-branch function fails" 1 scripts/check complexity
rm src/t/complex.py
git checkout -q check.config

echo "-- research"
mkdir -p docs/research
note() { cat > docs/research/stack-timing.md <<EOF
# Stack research: timing

- **Date**: ${1:-2026-11-24}
- **Question**: Can runtime X hit 23 ms frames?
- **Time-box**: 2 days
- **Status**: ${2:-open}
- **Sources**:
  - https://example.org/a (read 2026-11-24)
- **Verified**: requests 2.34.2 Apache-2.0 (scripts/verify-package pypi requests)
- **Re-check by**: ${3:-2027-02-01}
EOF
}
R() { CHECK_TODAY="$1" scripts/check research; }
note; expect "research: complete note passes" 0 R 2026-11-24
sed -i '/Sources/,+1d' docs/research/stack-timing.md; expect "research: missing Sources fails" 1 R 2026-11-24
note 2026-11-24 maybe; expect "research: bad Status fails" 1 R 2026-11-24
note 2026-11-24 open 2027-06-01; expect "research: Re-check by > 90 days after Date fails" 1 R 2026-11-24
note; expect_out "research: open past its time-box warns" "WARN stack-timing.md: open past its time-box" R 2026-12-10
printf '# 0002\n\n- **Status**: proposed\n\n- [t](../research/stack-timing.md)\n' > docs/decisions/0002-choose-the-stack.md
expect "research: proposed decision links a stale note: fails" 1 R 2027-02-10
note 2027-02-10 answered 2027-04-30; expect "research: after the re-check: passes" 0 R 2027-02-10
printf '# 0003\n\n- **Status**: accepted\n' > docs/decisions/0003-x.md
expect "research: accepted decision without evidence fails" 1 R 2027-02-10
printf '# 0003\n\n- **Status**: accepted\n\n- [t](../research/stack-timing.md)\n' > docs/decisions/0003-x.md
expect "research: accepted decision with evidence passes" 0 R 2027-02-10
git checkout -q docs; git clean -fdq docs

echo "-- pr-size on fix/ branches"
G checkout -q -b fix/TST-1-small; echo "# n" >> src/t/calc.py; G commit -qam "fix(TST-1): a" --no-verify
expect "pr-size: small fix passes" 0 scripts/check pr-size origin/dev
python3 -c "print('\n'.join(f'x{i} = {i}' for i in range(250)))" > src/t/big.py; G add -A; G commit -qm "fix(TST-1): big" --no-verify
expect "pr-size: fix over FIX_MAX_LINES fails" 1 scripts/check pr-size origin/dev
G checkout -q -b claude/big; expect "pr-size: same size on an agent branch is under PR_MAX_LINES" 0 scripts/check pr-size origin/dev
G checkout -q fix/TST-1-small; G reset -q --hard HEAD~1; mkdir -p src/t/auth; echo "x = 1" > src/t/auth/login.py; G add -A; G commit -qm "fix(TST-1): auth" --no-verify
expect "pr-size: fix touching SENSITIVE_PATHS fails" 1 scripts/check pr-size origin/dev

echo "-- proof and scope"
G checkout -q -f -b feat/TST-2-thing dev 2>/dev/null || G checkout -q -b feat/TST-2-thing origin/dev; mkdir -p specs/001-thing
spec() { printf '# Spec\n\n**Issue**: %s\n\n## Requirements\n\n- **FR-001**: add.\n- **FR-002**: subtract.\n\n## Proof\n\n| ID | How it is proven | Kind |\n|----|----|----|\n%b\n' "$1" "$2" > specs/001-thing/spec.md; G add -A; G commit -qm wip --no-verify; }
spec TST-2 "| FR-001 | test_add | test |\n| FR-002 | press the button | manual |"; expect "proof: good spec passes" 0 scripts/check proof origin/dev
spec TST-9 "| FR-001 | test_add | test |\n| FR-002 | x | manual |"; expect "proof: Issue differs from the branch key fails" 1 scripts/check proof origin/dev
spec TST-2 "| FR-001 | TODO | test |\n| FR-002 | x | manual |"; expect "proof: TODO cell fails" 1 scripts/check proof origin/dev
spec TST-2 "| FR-001 | test_add | test |"; expect "proof: FR without a row fails" 1 scripts/check proof origin/dev
spec TST-2 "| FR-001 | test_add | test |\n| FR-002 | x | whatever |"; expect "proof: bad kind fails" 1 scripts/check proof origin/dev
spec "[KEY-n]" "| FR-001 | t | test |\n| FR-002 | t | test |"; expect "proof: unfilled Issue fails" 1 scripts/check proof origin/dev
printf '# Plan\n\nsrc/t/calc.py\n' > specs/001-thing/plan.md; mkdir -p tools; echo "x = 1" > tools/other.py; G add -A; G commit -qm s --no-verify
expect_out "scope: file outside the plan warns (exit 0)" "WARN scope" scripts/check scope origin/dev
expect "scope: never fails" 0 scripts/check scope origin/dev

echo "-- tracked .env, docs"
G checkout -q fix/TST-1-small; printf 'K=1\n' > .env.production; G add -f .env.production
expect "env-files: a tracked .env.production fails" 1 scripts/check secrets
G rm -q --cached .env.production; rm -f .env.production
expect "env-files: removed: passes" 0 scripts/check secrets
printf '# X\n\nSee [gone](docs/nothere.md) and [web](https://example.org).\n\n```text\n[in code](docs/fake.md)\n```\n' > docs/x.md
expect_out "docs: broken relative link is found (and code blocks are skipped)" "broken link: docs/x.md -> docs/nothere.md" scripts/check docs
printf '# X\n## Y\n' > docs/x.md; expect "docs: markdownlint error fails" 1 scripts/check docs
rm docs/x.md

echo "-- malicious-package gate with a stub osv-scanner"
stub="$work/stub"; mkdir -p "$stub"; cat > "$stub/osv-scanner" <<'EOF'
#!/usr/bin/env bash
case "${STUB_MODE:-mal}" in
  mal) echo '{"results":[{"source":{"path":"/x/uv.lock"},"packages":[{"package":{"name":"evil","version":"1","ecosystem":"PyPI"},"vulnerabilities":[{"id":"MAL-2026-1"},{"id":"GHSA-aaaa-bbbb-cccc"}]}]}]}'; exit 1 ;;
  canary) echo '{"results":[{"source":{"path":"/x/tests/quality-canary/python/uv.lock"},"packages":[{"package":{"name":"evil","version":"1","ecosystem":"PyPI"},"vulnerabilities":[{"id":"MAL-2026-1"}]}]}]}'; exit 1 ;;
  other) echo '{"results":[{"source":{"path":"/x/uv.lock"},"packages":[{"package":{"name":"old","version":"1","ecosystem":"PyPI"},"vulnerabilities":[{"id":"GHSA-aaaa-bbbb-cccc"}]}]}]}'; exit 1 ;;
  unreachable) echo "failed to reach osv.dev" >&2; exit 127 ;;
esac
EOF
chmod +x "$stub/osv-scanner"
expect "malicious: a MAL- advisory fails" 1 env STUB_MODE=mal PATH="$stub:$PATH" scripts/check deps
expect "malicious: MAL- only inside the canary folders is ignored" 0 env STUB_MODE=canary PATH="$stub:$PATH" scripts/check deps
expect "malicious: other advisories do not fail this gate" 0 env STUB_MODE=other PATH="$stub:$PATH" scripts/check deps
expect "malicious: osv.dev unreachable only warns locally" 0 env STUB_MODE=unreachable PATH="$stub:$PATH" scripts/check deps
expect "malicious: osv.dev unreachable fails in CI" 1 env CI=1 STUB_MODE=unreachable PATH="$stub:$PATH" scripts/check deps

echo "-- canary notices a removed gitleaks rule"
cp .gitleaks.toml /tmp/gl.bak.$$
python3 - <<'EOF'
s = open('.gitleaks.toml').read()
i = s.index('[[rules]]\nid = "discord-webhook-url"'); j = s.index('[[rules]]\nid = "typed-secret-constant"')
open('.gitleaks.toml', 'w').write(s[:i] + s[j:])
EOF
expect_out "canary: removing the discord rule is noticed" "not detected: gitleaks:discord-webhook-url" scripts/check canary
cp /tmp/gl.bak.$$ .gitleaks.toml; rm /tmp/gl.bak.$$
expect "canary: restored passes" 0 scripts/check canary

echo "-- hooks: format-file and Stop hook"
G checkout -q -f dev; G clean -fdq
printf 'x   =   {  "a":1 }\n' > src/t/messy.py
for p in jq python sed; do printf 'x   =   {  "a":1 }\n' > src/t/messy.py
  echo "{\"tool_input\":{\"file_path\":\"$PWD/src/t/messy.py\"}}" | HOOK_PARSER=$p CLAUDE_PROJECT_DIR=$PWD bash .claude/hooks/format-file.sh
  expect "format-file hook formats ($p parser)" 0 grep -qx 'x = {"a": 1}' src/t/messy.py; done
rm src/t/messy.py
printf '\n\nX = 1\n' >> src/t/calc.py
stop() { rm -rf .git/agent-checks; CLAUDE_PROJECT_DIR=$PWD bash .claude/hooks/run-checks.sh >/dev/null 2>&1; }
expect "stop hook: passes when fast, test and build pass" 0 stop
sed -i 's|^BUILD_CMD=.*|BUILD_CMD="false"|' check.config
expect "stop hook: blocks (exit 2) when the build fails" 2 stop
sed -i 's|^STOP_STAGES=.*|STOP_STAGES="fast test"|' check.config
expect "stop hook: STOP_STAGES without build ignores the build" 0 stop

echo "-- hook: LINT_FILE_CMD (ruff) reports a problem to the agent"
printf 'import os\n' > src/t/unused.py
lintin() { echo "{\"tool_input\":{\"file_path\":\"$PWD/src/t/unused.py\"}}" | CLAUDE_PROJECT_DIR=$PWD bash .claude/hooks/format-file.sh; }
expect "lint-file hook: an unused import exits 2 (ruff check)" 2 lintin
expect_out "lint-file hook: ... and names the file" "unused.py" lintin
printf '"""Unused."""\n' > src/t/unused.py
expect "lint-file hook: a clean python file exits 0" 0 lintin
rm -f src/t/unused.py
git checkout -q check.config src
)


echo "== node project: licences (needs npm)"
if command -v npm >/dev/null 2>&1; then
gen node node
(
cd node || exit 1
printf '{"name":"t","version":"0.1.0","private":true,"type":"module","scripts":{"build":"tsc --noEmit"}}\n' > package.json
mkdir -p src; printf 'export function add(a: number, b: number): number {\n  return a + b;\n}\n' > src/calc.ts
printf 'import { expect, test } from "vitest";\nimport { add } from "./calc";\n\ntest("add", () => {\n  expect(add(1, 2)).toBe(3);\n});\n' > src/calc.test.ts
printf '{"compilerOptions":{"strict":true,"noEmit":true,"target":"es2022","module":"esnext","moduleResolution":"bundler","skipLibCheck":true},"include":["src"]}\n' > tsconfig.json
printf 'import tseslint from "typescript-eslint";\n\nexport default tseslint.config(...tseslint.configs.recommended);\n' > eslint.config.mjs
echo 20 > .nvmrc
npm install -D prettier eslint typescript-eslint typescript vitest @vitest/coverage-v8 >/dev/null 2>&1
npx prettier --write src package.json tsconfig.json eslint.config.mjs >/dev/null
commit_all .
expect "node: scripts/check all passes (also with coverage/ and node_modules/ present)" 0 scripts/check all
expect "node: licenses pass on MIT/Apache dependencies" 0 scripts/check licenses
pk="$work/gplpkg"; mkdir -p "$pk"; echo '{"name":"gpl-local","version":"1.0.0","license":"GPL-3.0-only","main":"i.js"}' > "$pk/package.json"; echo "module.exports=1" > "$pk/i.js"
(cd "$pk" && npm pack >/dev/null 2>&1)
npm install --save "$pk/gpl-local-1.0.0.tgz" >/dev/null 2>&1
expect "node: a GPL-3.0 production dependency fails licenses" 1 scripts/check licenses
printf 'vulnerabilities: []\nmisconfigurations: []\nlicenses:\n  - id: GPL-3.0-only\n    paths: [package-lock.json]\n    statement: "separate tool, reviewed"\n    expired_at: 2099-01-01\n' > .trivyignore.yaml
expect "node: ... passes with a licence exception" 0 scripts/check licenses
sed -i 's/2099-01-01/2026-01-01/' .trivyignore.yaml
expect "node: ... fails again when the exception expired" 1 scripts/check licenses
)
else echo "skip node tests (no npm)"; fi

echo "== hooks cases (jq, python3 and sed parsers)"
(cd py && expect_out "hooks: all parsers" "PASS hooks \([0-9]+ cases x 3 parsers: sed python jq\)" scripts/check hooks)

echo "== verify-package (network)"
v="$here/template/scripts/verify-package"
expect "verify-package: pypi requests exists" 0 "$v" pypi requests
expect "verify-package: pypi unknown package -> exit 1" 1 "$v" pypi dev-standard-no-such-package-zz
expect "verify-package: npm left-pad 1.3.0" 0 "$v" npm left-pad 1.3.0
expect "verify-package: npm missing version -> exit 1" 1 "$v" npm left-pad 99.0.0
expect "verify-package: crates serde" 0 "$v" crates serde
expect "verify-package: nuget Newtonsoft.Json" 0 "$v" nuget Newtonsoft.Json
expect "verify-package: pub http" 0 "$v" pub http
expect "verify-package: usage error -> exit 2" 2 "$v" cobol x

pass="$(grep -c '^ok ' "$res")"; failn="$(grep -c '^FAIL ' "$res")"
echo; echo "passed: $pass  failed: $failn  (work dir: $work)"
[[ $failn -eq 0 ]]
