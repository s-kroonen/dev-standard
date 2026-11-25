#!/usr/bin/env bash
#
# Update tests: the guarantee that a release reaches projects of the previous release (and of the
# oldest supported release) without conflicts. For stack none, python and node it generates a
# project from an older release, applies typical project edits, updates it to the working tree of
# this repository and checks the result. A second part adopts a repository that did not start from
# the standard.
#
#   tests/update-tests.sh [workdir]      (default: a new temp dir; kept, its path is printed)
#
# Needs uv, git, jq, network (Copier, Spec Kit, PyPI/npm for the stack variants only through the
# template tasks) and the pinned scanners on PATH (gitleaks, trivy, opengrep, vale), like
# tests/template-tests.sh.
#
# Environment:
#   PREVIOUS_TAG   release to start from (default: the newest v* tag that is not the candidate)
#   OLDEST_TAG     oldest supported release (default: v0.1.0; skipped when it is the previous one)
#   TAG_MAP        "v0.1.0=ce35080 v0.2.0=db58a20": tags created in the scratch clone when missing
#                  (a repository without release tags; the real repository gets none)
#   STACKS         stacks for the previous release (default: "none python node")
#   SKIP_PREVIOUS  1: only the update from the oldest release (a quicker run while working on it)
#   SKIP_OLDEST    1: only the update from the previous release
#   RELEASE_RULES_ONLY  1: stop after the release rules (tests/template-tests.sh runs them against a mutated copy)
#
# The candidate version is the top section of CHANGELOG.md (## vX.Y.Z); the working tree is
# committed in a scratch clone and tagged with it there, so this repository stays untouched.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$here/.tools/bin:$PATH"   # pinned tools from scripts/setup (same as CI)
work="${1:-$(mktemp -d)}"; mkdir -p "$work"; work="$(cd "$work" && pwd)"; cd "$work" || exit 1
res="$work/results.txt"; : > "$res"
strip() { sed 's/\x1b\[[0-9;]*m//g'; }
G() { git -c user.name=t -c user.email=t@t "$@"; }
expect() { # <name> <want exit> <command...>
    local name="$1" want="$2"; shift 2
    local out rc; out="$("$@" 2>&1)"; rc=$?; out="$(strip <<<"$out")"
    if [[ "$rc" == "$want" ]]; then echo "ok   $name" | tee -a "$res"
    else echo "FAIL $name (exit $rc, want $want)" | tee -a "$res"; sed 's/^/       /' <<<"$out" | tail -n 14; fi
}
expect_out() { # <name> <regex> <command...>
    local name="$1" re="$2"; shift 2
    local out; out="$("$@" 2>&1 | strip)"
    if grep -qE -- "$re" <<<"$out"; then echo "ok   $name" | tee -a "$res"
    else echo "FAIL $name (no match for: $re)" | tee -a "$res"; sed 's/^/       /' <<<"$out" | tail -n 14; fi
}
commit_all() { (cd "$1" && git add -A && G commit -q --no-verify -m "${2:-init}" && git update-ref refs/remotes/origin/dev HEAD); }
copier_cmd=(uvx --quiet --from copier==9.7.1 copier)
copier() { "${copier_cmd[@]}" "$@"; }
# bash 5.3 treats `cd ""` as an error ("cd: null directory"); bash 5.2 does not. BASH_ENV applies it to every script.
cat > "$work/bash5.3.sh" <<'EOS'
cd() { if [ "$#" -ge 1 ] && [ -z "$1" ]; then echo "${BASH_SOURCE[1]:-bash}: line ${BASH_LINENO[0]}: cd: null directory" >&2; return 1; fi; builtin cd "$@"; }
EOS

# --- the scratch clone: previous releases as tags, the working tree as the candidate -----------------
src="$work/src"
git clone -q "$here" "$src" || exit 1
for pair in ${TAG_MAP:-}; do git -C "$src" rev-parse -q --verify "refs/tags/${pair%%=*}" >/dev/null || git -C "$src" tag "${pair%%=*}" "${pair#*=}"; done
cand="$(sed -n 's/^## \(v[0-9][0-9.]*\).*/\1/p' "$here/CHANGELOG.md" | head -n1)"
[[ -n "$cand" ]] || { echo "FAIL: no '## vX.Y.Z' section at the top of CHANGELOG.md"; exit 1; }
(cd "$here" && git ls-files -z --cached --others --exclude-standard) | while IFS= read -r -d '' f; do [[ -e "$here/$f" ]] && printf '%s\0' "$f"; done > "$work/files.lst"
find "$src" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
(cd "$here" && tar --null -T "$work/files.lst" -cf -) | tar -xf - -C "$src"
git -C "$src" add -A && G -C "$src" commit -q --allow-empty -m "candidate $cand" && git -C "$src" tag -f "$cand" >/dev/null
prev="${PREVIOUS_TAG:-$(git -C "$src" tag --list 'v[0-9]*' | grep -vxF "$cand" | sort -V | tail -n1)}"
oldest="${OLDEST_TAG:-v0.1.0}"
[[ -n "$prev" ]] || { echo "FAIL: no previous release tag (set PREVIOUS_TAG or TAG_MAP)"; exit 1; }
echo "candidate $cand, previous $prev, oldest $oldest (source $src)"

# --- release rules (docs/releasing.md) ------------------------------------------------------------
echo "== release rules: a breaking change ships a migration or an upgrade note"
section="$(awk -v t="$cand" '$0 ~ "^## " t "([[:space:]]|$)" {on=1; next} on && /^## / {exit} on' "$here/CHANGELOG.md")"
notes="$(awk '/^### Upgrade notes/ {on=1; next} on && /^##/ {exit} on' <<<"$section")"
expect "release: CHANGELOG has a section for $cand" 0 test -n "$section"
expect "release: the section has non-empty Upgrade notes (write 'None.' when nothing is to do)" 0 test -n "${notes//[[:space:]]/}"
removed="$(git -C "$src" diff --name-status --diff-filter=DR "$prev" "$cand" -- template | awk '{print $2}' | sed 's|^template/||' | grep -v '^{' || true)"
missing=""
while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    grep -qF -- "$(basename "$p" .jinja)" <<<"$notes" || missing+="$p "
done <<<"$removed"
if [[ -z "$missing" ]]; then echo "ok   release: every removed or renamed standard file is named in the Upgrade notes" | tee -a "$res"
else echo "FAIL release: removed or renamed standard files not named in the Upgrade notes: $missing" | tee -a "$res"; fi
if git -C "$src" diff --quiet "$prev" "$cand" -- template/check.config.jinja; then echo "ok   release: check.config unchanged" | tee -a "$res"
else
    old_vars="$(git -C "$src" show "$prev:template/check.config.jinja" | grep -oE '^[A-Z][A-Z0-9_]*=' | sort -u)"
    # a variable that moved to project.config is not removed
    new_vars="$({ git -C "$src" show "$cand:template/check.config.jinja"; git -C "$src" show "$cand:template/project.config.jinja" 2>/dev/null; } | grep -oE '^[A-Z][A-Z0-9_]*=' | sort -u)"
    gone="$(comm -23 <(echo "$old_vars") <(echo "$new_vars") | tr -d '=' | tr '\n' ' ')"
    bad=""; for v in $gone; do grep -qF "$v" <<<"$notes" || bad+="$v "; done
    if [[ -z "$bad" ]]; then echo "ok   release: every removed check.config variable is named in the Upgrade notes (${gone:-none removed})" | tee -a "$res"
    else echo "FAIL release: removed check.config variables not named in the Upgrade notes: $bad" | tee -a "$res"; fi
fi

if [[ "${RELEASE_RULES_ONLY:-0}" == 1 ]]; then
    failn="$(grep -c '^FAIL' "$res")"; echo "release rules: $failn failed"; [[ "$failn" -eq 0 ]]; exit
fi

# --- a project from <base>, edited like a project, updated to the candidate -------------------------------
has_marker() { grep -q 'project rules: below this line' "$1/CLAUDE.md" 2>/dev/null; }

edit_project() { # <dir>: edits that only touch the project's own parts
    local d="$1"
    (
    cd "$d" || exit 1
    if [[ ! -f .vale.ini ]]; then
        # a base without the writing rule (v0.1.0): the project's own prose is clean, as a project that
        # follows the upgrade notes of v0.2.0 would write it
        printf '# Legacy\n\nThe project keeps a shopping list.\n' > README.md
        printf '# Security exceptions\n\nNone.\n' > docs/security-exceptions.md
    fi
    sed -i 's|^<added once the stack is decided: structure, naming, error handling, how to run it>$|Project rule: modules keep their own error types.|' AGENTS.md
    sed -i 's|^Not decided yet: see `docs/decisions/0002-choose-the-stack.md`. Filled in once that decision is accepted.$|Constraint: runs on Linux only.\nNot decided yet: see `docs/decisions/0002-choose-the-stack.md`.|' CONSTITUTION.md
    sed -i 's|^# \(\^pyproject\\\.toml\$\)|\1|' .guardrails
    [[ -f .vale.ini ]] && printf '\nThe project keeps a shopping list.\n' >> README.md
    printf '| TST-1 | Own item of the project | M | Write it | todo |\n' >> TODO.md
    printf '\nThe product serves one customer.\n' >> docs/product/vision.md
    printf '\nThe project chose its stack on its own terms.\n' >> docs/decisions/0002-choose-the-stack.md
    printf '# 0003 Use a queue\n\nStatus: proposed\n\nThe project decides on a queue.\n' > docs/decisions/0003-use-a-queue.md
    mkdir -p .opengrep/rules/project
    printf 'rules:\n  - id: project-no-eval\n    pattern: eval(...)\n    message: no eval\n    languages: [python]\n    severity: ERROR\n' > .opengrep/rules/project/no-eval.yaml
    if [[ -d .vale ]]; then printf 'Widgetron\n' >> .vale/styles/config/vocabularies/Project/accept.txt; fi
    if has_marker .; then
        printf 'Project hint: run the local script first.\n' >> CLAUDE.md
        printf '*.localnotes\n' >> .gitignore
        printf '/docs/product/   @someone\n' >> CODEOWNERS
        printf '# own hook\n' >> lefthook.yml
        printf '0\tdev\tbash\tgit status\n' >> tests/hooks/project-cases.tsv
        sed -i 's/^COVERAGE_TOTAL_MIN=0 /COVERAGE_TOTAL_MIN=37 /; s/^VALE_EXCLUDE=""/VALE_EXCLUDE="^legacy\/"/; s/^ARCH_CMD=""/ARCH_CMD="none"   # no layers yet/' project.config
    else
        sed -i 's/^COVERAGE_TOTAL_MIN=0 /COVERAGE_TOTAL_MIN=37 /; s/^VALE_EXCLUDE=""/VALE_EXCLUDE="^legacy\/"/; s/^ARCH_CMD=""/ARCH_CMD="none"   # no layers yet/' check.config
    fi
    )
}

# files that must stay byte-identical (project files)
project_files=(README.md docs/security-exceptions.md TODO.md docs/product/vision.md docs/decisions/0002-choose-the-stack.md docs/decisions/0003-use-a-queue.md .opengrep/rules/project/no-eval.yaml .vale/styles/config/vocabularies/Project/accept.txt)

run_update() { # <name> <base tag> <stack>
    local name="$1" base="$2" stack="$3"
    local d="$work/$name" fresh="$work/fresh-$stack"
    echo "== update $name: $base -> $cand ($stack)"
    if [[ ! -d "$fresh" ]]; then
        copier copy --trust --defaults --vcs-ref "$cand" "$src" "$fresh" \
            --data project_name=U --data issue_key=TST --data stack="$stack" --data platform=github >/dev/null 2>&1 \
            || { echo "FAIL fresh render of $cand ($stack)" | tee -a "$res"; return; }
    fi
    if ! copier copy --trust --defaults --vcs-ref "$base" "$src" "$d" \
        --data project_name=U --data issue_key=TST --data stack="$stack" --data platform=github >"$work/$name.gen.log" 2>&1; then
        echo "FAIL $name: generation from $base failed (see $work/$name.gen.log)" | tee -a "$res"; return
    fi
    local marker=false vale=false
    has_marker "$d" && marker=true
    [[ -f "$d/.vale.ini" ]] && vale=true
    edit_project "$d"
    commit_all "$d" "project edits"
    declare -A before=()
    local f files=()
    for f in "${project_files[@]}"; do [[ -f "$d/$f" ]] && { files+=("$f"); before[$f]="$(sha256sum "$d/$f" | cut -d' ' -f1)"; }; done
    local sections_agents sections_const
    sections_agents="$(grep -F 'Project rule: modules keep their own error types.' "$d/AGENTS.md")"
    sections_const="$(grep -F 'Constraint: runs on Linux only.' "$d/CONSTITUTION.md")"
    local out rc
    if [[ -x "$d/scripts/update-standard" ]]; then
        out="$(cd "$d" && PATH="$PATH" scripts/update-standard TST-9 --to "$cand" 2>&1)"; rc=$?
        expect_out "$name: update-standard prints the report" "Report: dev-standard" echo "$out"
        expect_out "$name: update-standard names the commit message" "chore\(TST-9\): update dev-standard to $cand" echo "$out"
        [[ $rc -eq 0 ]] || { echo "   (update-standard exit $rc)"; strip <<<"$out" | tail -n 25 | sed 's/^/       /'; }
        expect "$name: update-standard worked on branch chore/TST-9-update-dev-standard" 0 test "$(git -C "$d" rev-parse --abbrev-ref HEAD)" = "chore/TST-9-update-dev-standard"
    else
        # releases before v0.3.0 have no scripts/update-standard: the first jump is the documented one
        # (README.md, CHANGELOG.md Upgrade notes): copier update --skip-tasks, then scripts/post-update
        if [[ ! -e "$work/plain-update-shown" ]]; then
            : > "$work/plain-update-shown"
            # bash 5.3 (GitHub runners) fails on cd ""; the old scripts/update-rules runs it in Copier's
            # temporary copy without git. bash5.3.sh gives an older bash that behaviour.
            cp -a "$d" "$d-plain"
            out="$(cd "$d-plain" && env BASH_ENV="$work/bash5.3.sh" "${copier_cmd[@]}" update --trust --defaults --conflict inline --vcs-ref "$cand" 2>&1)"; rc=$?
            expect "$name: a plain update from $base fails on bash 5.3 (so the docs name --skip-tasks)" 0 test "$rc" -ne 0
            expect_out "$name: the plain update stops with 'null directory'" "null directory" echo "$out"
            rm -rf "$d-plain"
        fi
        out="$(cd "$d" && env BASH_ENV="$work/bash5.3.sh" "${copier_cmd[@]}" update --trust --defaults --skip-tasks --conflict inline --vcs-ref "$cand" 2>&1)"; rc=$?
        expect "$name: copier update --skip-tasks succeeds (also on bash 5.3)" 0 test "$rc" -eq 0
        [[ $rc -eq 0 ]] || strip <<<"$out" | tail -n 25 | sed 's/^/       /'
        expect "$name: scripts/post-update succeeds" 0 bash -c "cd '$d' && scripts/post-update"
    fi
    (
    cd "$d" || exit 1
    expect "$name: no conflict markers or .rej files" 1 bash -c "{ grep -rIlE '^(<<<<<<<|>>>>>>>) ' --exclude-dir=.git --exclude-dir=.specify --exclude-dir=.opengrep --exclude-dir=.tools . ; find . -name '*.rej' -not -path './.git/*'; } | grep ."
    local f
    for f in "${files[@]}"; do
        expect "$name: project file $f is byte-identical" 0 test "$(sha256sum "$f" | cut -d' ' -f1)" = "${before[$f]}"
    done
    expect "$name: the project section of AGENTS.md is kept" 0 grep -qxF "$sections_agents" AGENTS.md
    expect "$name: the project principles of CONSTITUTION.md are kept" 0 grep -qxF "$sections_const" CONSTITUTION.md
    expect "$name: the .guardrails project line is kept" 0 grep -q '^\^pyproject\\\.toml\$' .guardrails
    if [[ -d .specify ]]; then expect "$name: the constitution copy is in sync" 0 cmp CONSTITUTION.md .specify/memory/constitution.md; fi
    expect "$name: _commit is the candidate" 0 grep -q "^_commit: $cand\$" .copier-answers.yml
    expect "$name: _src_path stays absolute" 0 grep -q "^_src_path: /" .copier-answers.yml
    expect "$name: the project values are in project.config" 0 bash -c "grep -q '^COVERAGE_TOTAL_MIN=37' project.config && { ! $vale || grep -q '^VALE_EXCLUDE=\"^legacy/\"' project.config; } && grep -q '^ARCH_CMD=\"none\"   # no layers yet' project.config"
    expect "$name: check.config holds none of the project's values" 1 grep -qE '^(COVERAGE_TOTAL_MIN=37|VALE_EXCLUDE="\^legacy|ARCH_CMD="none")' check.config
    if $marker; then
        expect "$name: CLAUDE.md, .gitignore, lefthook.yml, CODEOWNERS keep the project's lines below the marker" 0 bash -c "grep -q 'Project hint' CLAUDE.md && grep -qx '\*.localnotes' .gitignore && grep -q '@someone' CODEOWNERS && grep -q '^# own hook' lefthook.yml"
    fi
    # the standard files equal a fresh render of the candidate
    expect "$name: standard files equal a fresh render of $cand" 0 bash -c "cd '$fresh' && for p in scripts .claude/hooks .claude/skills/update-standard .github/workflows check.config .vale/styles/DevStandard .vale.ini tests/hooks/cases.tsv .opengrep/rules/custom docs/process docs/research/README.md tests/security-canary/README.md; do [ -e \"\$p\" ] || continue; diff -r \"\$p\" '$d'/\"\$p\" || exit 1; done"
    commit_all . "update" >/dev/null 2>&1
    if [[ "$stack" == none ]]; then
        expect "$name: scripts/check all is green" 0 scripts/check all
        expect "$name: scripts/check all is green with CI=1" 0 env CI=1 scripts/check all
    else
        # a stack without code and lockfile cannot pass the code gates: the gates that need none do
        local st
        for st in research secrets sast config canary hooks docs; do expect "$name: scripts/check $st is green (CI=1)" 0 env CI=1 scripts/check "$st"; done
        expect "$name: scripts/check stack-layer skips without code" 0 env CI=1 scripts/check stack-layer
    fi
    expect_out "$name: the hooks cases hold (standard and project cases)" "PASS hooks" scripts/check hooks
    )
}

run_matrix() {
    local stack
    for stack in ${STACKS:-none python node}; do
        [[ "${SKIP_PREVIOUS:-0}" == 1 ]] && break
        run_update "up-$stack" "$prev" "$stack"
    done
    if [[ "${SKIP_OLDEST:-0}" != 1 && -n "$oldest" && "$oldest" != "$prev" ]] && git -C "$src" rev-parse -q --verify "refs/tags/$oldest" >/dev/null; then
        run_update "up-oldest-none" "$oldest" none
        run_update "up-oldest-python" "$oldest" python
    else echo "skip update from the oldest release ($oldest is missing or the previous release)"; fi
}
run_matrix

# --- the second hop: a project of the candidate updates with scripts/update-standard ---------------------
# A synthetic release after the candidate changes a standard file, a shared file above its marker,
# check.config, the Spec Kit preset and the changelog, in the scratch clone only.
second_hop() {
    local next name="up-hop" d
    next="$(awk -F. '{printf "%s.%s.%d", $1, $2, $3 + 1}' <<<"$cand")"
    echo "== update $name: $cand -> $next with scripts/update-standard"
    d="$work/$name"
    copier copy --trust --defaults --vcs-ref "$cand" "$src" "$d" --data project_name=U --data issue_key=TST --data stack=none --data platform=github >"$work/$name.gen.log" 2>&1 \
        || { echo "FAIL $name: generation from $cand failed" | tee -a "$res"; return; }
    edit_project "$d"; commit_all "$d" "project edits"
    (
    cd "$src" || exit 1
    printf '\nThe synthetic release adds this sentence to the writing rule.\n' >> template/docs/process/writing.md
    sed -i 's|^    checks it: `scripts/check docs`; a PR body is checked with `scripts/check pr-text`.$|&\n12. **Hop rule.** The synthetic release adds this rule.|' template/AGENTS.md.jinja
    sed -i 's/^PR_MAX_LINES=800 /PR_MAX_LINES=900 /' template/check.config.jinja
    printf '\nThe synthetic release changes the preset.\n' >> speckit-preset/commands/speckit.bug.assess.md
    printf '# Changelog\n\n## %s\n\n### Changed\n\n- Synthetic release for the update test.\n\n### Upgrade notes\n\n- Synthetic note: nothing to do.\n' "$next" > CHANGELOG.new
    sed -n "/^## $cand/,\$p" CHANGELOG.md >> CHANGELOG.new; mv CHANGELOG.new CHANGELOG.md
    git add -A && G commit -q -m "synthetic $next" && git tag -f "$next" >/dev/null
    ) || { echo "FAIL $name: cannot build the synthetic release" | tee -a "$res"; return; }
    local before_proj; before_proj="$(cd "$d" && sha256sum project.config README.md | tr '\n' ' ')"
    local out rc
    out="$(cd "$d" && scripts/update-standard TST-10 --to "$next" 2>&1)"; rc=$?
    expect "$name: update-standard exits 0" 0 test "$rc" -eq 0
    [[ $rc -eq 0 ]] || strip <<<"$out" | tail -n 30 | sed 's/^/       /'
    expect_out "$name: the report has the upgrade note of $next" "Synthetic note: nothing to do" echo "$out"
    expect_out "$name: the report says no repo-settings change" "scripts/repo-settings apply is not needed" echo "$out"
    expect_out "$name: the report lists the changed guardrail files" "Changed guardrail files" echo "$out"
    expect_out "$name: the report names the commit message" "chore\(TST-10\): update dev-standard to $next" echo "$out"
    expect_out "$name: the changed Spec Kit preset is installed again" "Spec Kit preset installed again" echo "$out"
    (
    cd "$d" || exit 1
    expect "$name: the branch is chore/TST-10-update-dev-standard" 0 test "$(git rev-parse --abbrev-ref HEAD)" = chore/TST-10-update-dev-standard
    expect "$name: the standard sentence reached docs/process/writing.md" 0 grep -q 'The synthetic release adds this sentence' docs/process/writing.md
    expect "$name: the standard rule reached AGENTS.md above the project section" 0 grep -q 'Hop rule' AGENTS.md
    expect "$name: the project section of AGENTS.md is kept" 0 grep -qxF 'Project rule: modules keep their own error types.' AGENTS.md
    expect "$name: check.config has the new standard value" 0 grep -q '^PR_MAX_LINES=900 ' check.config
    expect "$name: project.config and README.md are byte-identical" 0 test "$(sha256sum project.config README.md | tr '\n' ' ')" = "$before_proj"
    expect "$name: the project's lines below the markers are kept" 0 bash -c "grep -q 'Project hint' CLAUDE.md && grep -qx '\*.localnotes' .gitignore && grep -q '@someone' CODEOWNERS && grep -q '^# own hook' lefthook.yml"
    expect "$name: the constitution copy is in sync" 0 cmp CONSTITUTION.md .specify/memory/constitution.md
    expect "$name: no conflict markers" 1 bash -c "grep -rIlE '^(<<<<<<<|>>>>>>>) ' --exclude-dir=.git --exclude-dir=.specify --exclude-dir=.opengrep --exclude-dir=.tools ."
    expect "$name: _commit is $next" 0 grep -q "^_commit: $next\$" .copier-answers.yml
    expect "$name: update-standard --check says up to date" 0 scripts/update-standard --check
    commit_all . "update" >/dev/null 2>&1
    expect "$name: scripts/check all is green" 0 scripts/check all
    )
    echo "-- the preconditions on the same project"
    (
    cd "$d" || exit 1
    git switch -q dev
    printf 'x\n' > dirty.txt
    expect "$name: a dirty tree is refused (exit 2)" 2 scripts/update-standard TST-11 --to "$next"
    rm -f dirty.txt
    git branch -q -m dev main
    expect "$name: main is refused (exit 2)" 2 scripts/update-standard TST-11 --to "$next"
    )
}
second_hop

# --- adopting a repository that did not start from the standard ------------------------------------------
echo "== adopt: a repository with a README, a CI file and a package.json"
ad="$work/adopt"; rm -rf "$ad"; mkdir -p "$ad/.github/workflows"
(
cd "$ad" || exit 1
git init -q -b main
printf '# Legacy app\n\nOwn words of the project.\n' > README.md
printf 'name: legacy-ci\non: [push]\njobs:\n  build:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo legacy\n' > .github/workflows/legacy.yml
printf '{\n  "name": "legacy",\n  "version": "1.0.0"\n}\n' > package.json
G add -A; G commit -q -m "feat: the legacy app"
sums="$(sha256sum README.md .github/workflows/legacy.yml package.json)"
copier copy --trust --defaults --overwrite --vcs-ref "$cand" "$src" . --data project_name=Legacy --data issue_key=LEG --data stack=none --data platform=github >"$work/adopt.log" 2>&1
expect "adopt: copier copy into the repository succeeds" 0 test -f .copier-answers.yml
expect "adopt: README.md is untouched" 0 grep -qx 'Own words of the project.' README.md
expect "adopt: the checksums of README, CI file and package.json are unchanged" 0 bash -c "[ \"\$(sha256sum README.md .github/workflows/legacy.yml package.json)\" = '$sums' ]"
expect "adopt: the existing CI file stays next to the standard's" 0 bash -c "test -f .github/workflows/legacy.yml && test -f .github/workflows/checks.yml"
expect "adopt: project.config exists" 0 test -f project.config
G add -A; G commit -q --no-verify -m "chore(LEG-1): adopt dev-standard"; git update-ref refs/remotes/origin/dev HEAD
expect_out "adopt: scripts/check fast runs" "PASS constitution" scripts/check fast
)

echo
pass="$(grep -c '^ok ' "$res")"; failn="$(grep -c '^FAIL' "$res")"
echo "update tests: $pass passed, $failn failed (results: $res)"
[[ "$failn" -eq 0 ]]
