#!/usr/bin/env bash
#
# Tests of the template itself: generates throwaway projects and checks that the stages of
# scripts/check pass and fail where they should. Needs uv, git, jq, node/npm (docs lint), network
# (PyPI, npm, Copier, Spec Kit) and the pinned scanners on PATH (gitleaks, trivy, opengrep).
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
cd none
expect "none: scripts/check all" 0 scripts/check all
expect "none: scripts/check all with CI=1" 0 env CI=1 scripts/check all
expect_out "none: stack-layer skips without code" "SKIP stack-layer" scripts/check stack-layer
)

echo "== python project with code"
gen py python --data safety_critical=true
(
cd py
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
git checkout -q check.config src
)


echo "== node project: licences (needs npm)"
if command -v npm >/dev/null 2>&1; then
gen node node
(
cd node
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
