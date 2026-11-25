# PLAN — fixes from the first CI run (PR #1)

The first run of `ci.yml` on GitHub (run 45634911818) failed in 11 of 13 jobs. The causes, in
fix order. Each fix lands as its own commit on `ccr-44b516ef-bl8xmk`; the push re-runs CI on
PR #1.

## Rules for the build

The rules of `AGENTS.md` hold: verified versions only, a failing and a passing case per check,
the writing rule for all text, no AI watermark in commits. Commit messages pass
`scripts/check commit-msg`. Guardrail files of this repository may change for these fixes (the
owner asked for them); the report lists each one.

## 1. Update from v0.1.0 and v0.2.0 aborts (update-test, 34 failures)

Cause: a plain `copier update` from v0.1.0 or v0.2.0 runs the old template's tasks in Copier's
temporary copy, which is not a git repository; the old `scripts/update-rules` exits with
"not a git repository" and Copier stops. Everything after it fails as a result (constitution
copy, `_commit`, `project.config`, the fresh-render comparison, `scripts/check all`).

The same test passes in this development container. That difference is a finding in itself.

1. Find why it passes here and fails on GitHub (environment, git config, temporary directory,
   Copier behaviour). Reproduce the GitHub failure locally, for example with a clean environment
   (`env -i HOME=… PATH=…`). Record the cause in the report and in `docs/releasing.md` if it
   affects how updates are tested.
2. The supported first jump from v0.1.0/v0.2.0: `copier update --trust --defaults --skip-tasks
   --conflict inline --vcs-ref <tag>`, then `scripts/post-update` (which exists after the jump).
   Put it in the v0.3.0 Upgrade notes of `CHANGELOG.md` and in the update docs.
3. `tests/update-tests.sh` uses exactly that documented path for old releases, and keeps one
   negative case that shows a plain update from v0.2.0 fails in a clean environment (so the
   docs stay true).
4. `template/scripts/update-rules` (and any task script) works outside a git repository, so a
   future version's tasks never abort an update the same way.

## 2. guardrails job fails when the base branch has no `.guardrails` (guardrails job)

Cause: `main` is v0.1.0 and has no root `.guardrails`; `git show "$BASE:.guardrails"` fails.
Adoption of an existing repository meets the same case.

1. In `.github/workflows/ci.yml` and the template's `guardrails.yml` (and the GitLab job): no
   list on the base branch means "no guardrails yet": pass with a notice that names the files the
   PR adds as guardrails. A list on the base branch keeps the current strict behaviour.
2. A test for both cases (in `tests/template-tests.sh` or a script the job calls).

## 3. Render step has a quoting error and a check that cannot fail (render, 5 jobs)

Cause: `ci.yml` step "No Jinja left, YAML parses" misses a closing quote (`'./.opengrep/*`);
bash stops before the check runs. The first line `! grep … | grep .` never fails under
`bash -e`.

1. Fix the quote; rewrite the Jinja check as `if grep …; then …; exit 1; fi`.
2. Add actionlint (pinned, checksum, at least 14 days old) to `scripts/install-tools` and
   `scripts/lint`; it runs shellcheck on every `run:` block of this repository's workflows and of
   rendered template workflows. A planted broken `run:` block fails `scripts/lint`.
3. Look for other `! cmd` lines under `bash -e` in workflows and scripts; fix them the same way.

## 4. Tests pick up the CI environment (template-tests, 7 failures)

Cause: GitHub sets `CI=true` and `GITHUB_HEAD_REF`/`GITHUB_BASE_REF`; `scripts/check` reads
them, so the "local mode" cases run in CI mode and branch-based cases (pr-size on `fix/`,
the proof issue key) see the PR branch.

1. `tests/template-tests.sh` and `tests/update-tests.sh` unset `CI`, `GITHUB_ACTIONS`,
   `GITHUB_HEAD_REF`, `GITHUB_BASE_REF`, `GITLAB_CI` and the `CI_MERGE_REQUEST_*` variables at
   the start; cases that test CI mode set `CI=1` themselves (they already do).
2. Prove it: run both suites locally with `CI=true GITHUB_HEAD_REF=ccr-x GITHUB_BASE_REF=main`
   exported; they pass.

## 5. PR body watermark (pr-rules)

The GitHub tool that opened PR #1 appended a footer line that names the AI tool.
The check worked. The PR body is edited outside this build (not a file in the repository).

## 6. Finish

- Run `scripts/lint`, `scripts/check docs`, `tests/template-tests.sh`, and
  `tests/update-tests.sh` (with the CI variables exported, see 4.2) before each push.
- `TODO.md`: one `STD-?` row per cause, status done or open.
- Push to `ccr-44b516ef-bl8xmk`; then read the new CI run of PR #1 and report each job's result.
