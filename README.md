# dev-standard

Start every project with the same AI rules, commit rules, docs and checks, on day 0, before there
is code or a stack. Built on [GitHub Spec Kit](https://github.github.com/spec-kit/) for the
spec-driven process, with our own layer for what Spec Kit doesn't do: enforcement.

| Part | What | Status |
|---|---|---|
| `copier.yml` + `template/` | [Copier](https://copier.readthedocs.io/) template: the baseline, optionally with a stack profile (python, node, rust, dotnet, flutter) | v0.3, tested (see Verified) |
| `speckit-preset/` | Spec Kit preset `dev-standard`: constitution in `CONSTITUTION.md`, Proof + Security in specs, Guardrails gate + Departures in plans, escalation check in bug assessments, extra research hosts | v0.2, tested |
| `tests/template-tests.sh` | Generates throwaway projects and checks that the stages pass and fail where they should (62 cases) | tested |
| `stacks/` | Source and test notes for the stack profiles; the profiles themselves are in the template (`stack` question) | reference |

## Contents

- [What a new project gets](#what-a-new-project-gets)
- [Requirements](#requirements)
- [Create a project](#create-a-project)
- [After creating](#after-creating)
- [Questions](#questions)
- [Spec Kit and our additions](#spec-kit-and-our-additions)
- [Updating projects](#updating-projects)
- [Verified](#verified)

## What a new project gets

| Area | Files |
|---|---|
| Principles | `CONSTITUTION.md`: six standard principles + room for project ones; works with and without Spec Kit (Spec Kit reads a synced copy) |
| How we work | `AGENTS.md`: work types (feature, bug, release, chore) with an AI level each, hard rules, Definition of Done; `CLAUDE.md` imports both |
| Tracker | `TODO.md` with `<KEY>-<n>` items (or GitHub Issues / Jira) |
| Commits | Conventional Commits with the issue as scope, `feat(APP-12): …`; checked by the commit-msg hook and in CI |
| Releases | `scripts/next-version` computes the version from the commits; `/release` skill prepares branch + changelog; a person merges and tags |
| Docs | product vision, research (dated notes, templates, retrospective), decision records with Evidence and Reversibility (MADR: 0001, 0002 choose the stack), workflow, **stack-layer playbook** (what to do after the first code), handover template, security exceptions |
| Claude Code | hooks: git rules per work type (`git-policy.sh`), protected files (`protect-paths.sh`), format the edited file (`format-file.sh`), checks before finishing (`run-checks.sh`, stages in `STOP_STAGES`), cloud setup; input parsed with jq, python3 or sed (`parse-input.sh`); no automatic MCP servers, web fetches ask; read-only `quality-reviewer` subagent; skills: Spec Kit's `/speckit-*` + `/release`, `/handover`, `/stack-layer`, `/quality-review`, `/stack-*` |
| Spec Kit | SDD process, idea assessment (no code needed), bug process, with the `dev-standard` preset |
| Checks | `scripts/check`: constitution sync, no code without gates, stack decided before plans, spikes only on spike branches, research notes dated and verified (decisions cite evidence, stale evidence fails), format/lint/typecheck, tests (0 tests fails), coverage of changed lines, safety tests, test integrity (deleted tests, skips, fewer asserts), **stack layer** (`stack-layer` + `architecture`, `complexity`, `perf`, `e2e`, `contract`, `security-native`, `fuzz`, `dast`: each decided once code exists), spec proof and scope (`proof`, `scope`), secrets (gitleaks incl. URL credentials, Discord webhooks, typed constants; no tracked `.env`), lockfiles + deps (trivy) + known malicious packages (osv-scanner `MAL-`), licences (trivy), SAST (opengrep + own rules), config (trivy), docs (markdownlint + links), security canary and quality canary of planted problems, hook tests with three input parsers; green on an empty repo |
| Tools | `scripts/verify-package <pypi\|npm\|crates\|nuget\|pub> <name> [version]`: does the package exist, licence, last release (registry API) |
| CI | GitHub (checks, PR title, guardrails, workflow audit with zizmor, optional CodeQL, release on tag with SBOM, cosign-signed checksums and provenance, optional Claude agent workflow, weekly settings check and long fuzz run) or GitLab (the same checks, tag pipeline with SBOM, release and back-merge MR) |
| Repo settings | `scripts/repo-settings [--gitlab] plan\|apply\|verify`: rulesets (GitLab: protected branches, pipelines must succeed) for `main`/`dev` (PR, required checks, no bypass, no force push), squash title = PR title, labels |

## Requirements

- [uv](https://docs.astral.sh/uv/) (runs Copier and Spec Kit with `uvx`, nothing to install globally)
- Git, Bash; [lefthook](https://lefthook.dev) for the git hooks
- Network on first run: Spec Kit and the opengrep rule sets are downloaded; `scripts/check docs` needs Node (markdownlint-cli2 via npx); `scripts/verify-package` needs curl and jq

## Create a project

```bash
uvx --from copier==9.7.1 copier copy --trust /path/to/dev-standard ./my-project
```

Copier asks the [questions](#questions), writes the files, then runs its tasks: `git init` (branch
`dev`), `specify init` + the preset, constitution sync, and vendoring the opengrep rule sets.
`--trust` is needed because of those tasks. Nothing is committed.

Non-interactive example:

```bash
uvx --from copier==9.7.1 copier copy --trust --defaults \
  --data project_name="My App" --data project_slug=my-app --data issue_key=APP \
  --data tracker=todo --data feature_level=ai-assist --data bug_level=agentic --data release_level=agentic \
  --data platform=github --data use_speckit=true --data owner=<you> \
  /path/to/dev-standard ./my-app
```

## After creating

1. `cd my-project && scripts/setup` (hooks, scanners, rule sets).
2. Read `CONSTITUTION.md` and `AGENTS.md`; add project principles (VII+) with `/speckit-constitution` or by hand.
3. Review and make the first commit yourself: `chore: set up the repository from dev-standard`.
4. Create the remote, push `dev`, create `main`, then `scripts/repo-settings apply` (GitHub: rulesets,
   required checks `result` and `guardrails`, no bypass, labels `test-change`, `large-change`,
   `guardrail-change`, `agent`). GitLab: protected branches and "Pipelines must succeed" by hand.
5. Work through `TODO.md`: vision → assess and research → stack decision → stack layer (`docs/process/stack-layer.md`, skill `/stack-layer`) → build → review the research (item `<KEY>-6`).

## Questions

| Question | Values | Default |
|---|---|---|
| `project_name`, `project_slug`, `description` | text | — |
| `issue_key` | 2–10 capitals, e.g. `APP` | — |
| `tracker` | `todo`, `github`, `jira` | `todo` |
| `feature_level` / `bug_level` / `release_level` | `ai-assist`, `agentic` | ai-assist / agentic / agentic |
| `platform` | `github`, `gitlab`, `none` | `github` |
| `use_speckit` | yes / no | yes |
| `speckit_version` | pinned version | `1.4.4` |
| `owner` | handle for CODEOWNERS and decision records | `maintainer` |
| `stack` | `none` (day 0), `python`, `node`, `rust`, `dotnet`, `flutter` | `none` |
| `safety_critical` | controls hardware or anything that can hurt people: safety principle + `scripts/check safety` required | no |
| `network_api` | exposes an API or UI on a network: secure control-surface principle + checklist | no |
| `github_agent` | adds `claude-agent.yml` (Claude GitHub Action for bugs and releases) | no |

Start with `stack=none`; after the stack decision: `copier update --trust --data stack=<name>`.

The levels decide which branches the agent may commit on (`git-policy.sh`) and what `AGENTS.md`,
the README and the workflow say. Mixed levels are normal: e.g. features ai-assist, bugs and releases agentic.

## Spec Kit and our additions

| From Spec Kit (as is) | Changed by our preset | Ours (Spec Kit has no equivalent) |
|---|---|---|
| specify, clarify, plan, tasks, analyze, implement, converge, checklist | constitution command → edits `CONSTITUTION.md`, then syncs | `CONSTITUTION.md` usable without Spec Kit |
| idea assessment (`assess` extension) | constitution template: our six principles | work types with AI levels, enforced by hooks |
| bug process (`bug` extension) | spec template: issue key, **Proof** table, **Security & Data** | Conventional Commits + key, `next-version`, `/release` |
| 43 agent integrations | plan template: **Guardrails & Security** gate, **Departures during build** | scanners, canary, guardrails, exceptions register, CI |

Spec Kit numbers spec folders `specs/001-…`; the issue key goes in the spec's **Issue** field.

## Updating projects

`copier update --trust` in a project applies a newer version of this template as a three-way merge
(needs this folder to be a git repository with version tags, e.g. `v0.1.0`). Spec Kit itself is
updated with `specify upgrade`; the preset with `specify preset add --dev <path>` again.

## Verified

Tested 2026-11-24 by generating a project (features ai-assist, bugs and releases agentic; Spec Kit 1.4.4):

- All 7 Copier tasks ran; Spec Kit installed 19 skills next to ours; `CLAUDE.md` untouched by Spec Kit; preset templates resolve.
- Commit rule: 6 valid messages accepted, 4 invalid ones rejected (missing key on feat/fix, wrong key, no type).
- `next-version`: no-release, patch, minor, breaking on 0.x and 1.x, breaking footer, changelog notes.
- `git-policy.sh`: commits blocked on `dev`, allowed on `fix/…`; feat branch creation blocked; merge, tag, force push, push to main, `--no-verify`, `reset --hard` blocked.
- `protect-paths.sh`: Spec Kit setup, synced constitution copy, `AGENTS.md`, skills, `check.config` blocked; `CONSTITUTION.md`, `specs/`, assessments, `TODO.md`, docs allowed.
- `scripts/check` on the empty project: constitution, secrets, deps, sast, config pass; canary detects all 15 planted findings; an edited constitution copy fails until synced.

High pass (2026-11-24), generated projects `python`, `rust` and `none` (safety and network on):

- Conditional files render only for their stack; no Jinja left in the output.
- `none`: `scripts/check all` green (15/15 canary); a stray `main.py` fails `code-needs-gates`; `spikes/` fails on `dev`, passes on `spike/…`; a plan without accepted ADR 0002 fails.
- `python` (uv, ruff, mypy, pytest): fast, test, coverage green; quality canary 7/7; security canary 38 findings; test-integrity fails on a new skip + removed assertion, warns with `test-change`; changed-line coverage below 80% fails.
- `rust`: quality canary 6/6 (format, clippy, failing test, zero tests, `#[ignore]`, clean control).
- `next-version`: stops (exit 4) when a newer tag isn't merged back, correct after the back-merge.
- `git-policy.sh`: 26 cases incl. `$G merge`, `git -C . rebase`, `-c core.hooksPath`, subprocess `["git","merge"]` (also with escaped quotes), `node -e`, `bash -c`.
- Workflows: zizmor 1.33.1 finds nothing at medium+; `repo-settings plan` renders (with and without CodeQL).

Remaining-items pass (2026-11-24; `tests/template-tests.sh`: 62 cases, all pass; plus the runs below). Generated projects: `none`, `python` (uv, ruff, mypy, pytest; safety and network on), `node` (npm, prettier, eslint, vitest), `rust` (cargo), GitLab and GitHub variants, `dotnet` and `flutter` rendered only.

- Day 0 (`none`): `scripts/check all` green locally and with `CI=1` (docs lint and hook tests included; canary finds 18 planted items, 3 of them the new gitleaks rules).
- `stack-layer`: no code: skipped. Python with code: empty variables WARN locally (exit 0), FAIL with `CI=1`; `none` without a reason comment FAILs, with a reason passes. `complexity` passes on simple code and fails on a 16-branch function.
- `research`: complete note passes; missing field, bad Status, re-check date more than 90 days after Date, accepted decision without evidence, proposed decision linking a stale note all fail; an open note past its time-box warns; re-checking the note fixes it.
- `proof`: Issue differs from the branch key, TODO cell, FR without a row, bad kind, unfilled Issue all fail; a good spec passes. `scope` warns about a file outside the plan and never fails. `pr-size`: a fix/ branch over 200 lines or touching `auth/` fails, the same size on an agent branch passes under 800.
- `deps` malicious-package gate, with a stub `osv-scanner` (osv.dev is blocked here): a `MAL-` advisory fails, one inside the canary folders and other advisories pass, osv unreachable WARNs locally and FAILs with `CI=1`; the jq, python3 and grep result parsers each tested.
- `licenses`: a GPL-3.0 production dependency fails (trivy: restricted, HIGH), passes with an exception in `.trivyignore.yaml`, fails again after its `expired_at`. `secrets`/`fast`: a tracked `.env.production` fails. The canary notices a removed gitleaks rule. `docs`: a broken relative link and a markdownlint error fail (links in code blocks are skipped).
- Hooks: 68 cases (escaped quotes and backslashes added) run with the jq, python3 and sed parsers: 204 runs, all as expected. `format-file.sh` formats with ruff (all three parsers) and rustfmt, skips canary folders, never blocks. The Stop hook runs `STOP_STAGES`: passes, blocks with exit 2 when `BUILD_CMD` fails, ignores the build when it is not listed.
- `verify-package`: pypi, npm, crates, nuget, pub against the live registries; unknown package and missing version exit 1, usage error exit 2.
- Node: `scripts/check all` green with `node_modules/` and `coverage/` present (after adding them to `.gitignore`, `.semgrepignore` and the eslint ignores). Rust: all stages green except coverage (no `cargo-llvm-cov` here).
- Workflows: `release.yml`, `checks.yml`, `claude-agent.yml`, `guardrails.yml` parse as YAML; zizmor 1.33.1 (`--offline --min-severity medium`) reports no findings; the rendered GitLab file parses and has the new jobs. `repo-settings --gitlab plan` renders. Spec Kit preset 0.2.0 installs and the appended addenda appear in `speckit-bug-assess`, `speckit-assess-intake` and `speckit-assess-research`.

Not verified: a real CI run (GitHub or GitLab), `repo-settings apply` or `--gitlab apply` on a live project, the cosign signing on a real tag, the Claude agent workflow (and whether it loads the hooks), the `quality-reviewer` agent and the `/stack-layer` and `/quality-review` skills inside Claude Code, `copier update`, the malicious-package gate against live osv.dev, licence scan of Python and Rust lockfiles, Rust coverage, the dotnet profile (no SDK) and the flutter profile. Follow-ups: `TODO.md` STD-71 to STD-79.
