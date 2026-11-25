# dev-standard

Start every project with the same AI rules, commit rules, docs and checks, on day 0, before there
is code or a stack. Built on [GitHub Spec Kit](https://github.github.com/spec-kit/) for the
spec-driven process, with a layer of its own for what Spec Kit does not do: enforcement.

| Part | What | Status |
|---|---|---|
| `copier.yml` + `template/` | [Copier](https://copier.readthedocs.io/) template: the baseline, optionally with a stack profile (python, node, rust, dotnet, flutter) | v0.3, tested (see Verified) |
| `speckit-preset/` | Spec Kit preset `dev-standard`: constitution in `CONSTITUTION.md`, Proof + Security in specs, Guardrails gate + Departures in plans, escalation check in bug assessments, extra research hosts | v0.2, tested |
| `tests/template-tests.sh` | Generates throwaway projects and checks that the stages pass and fail where they should | tested |
| `tests/update-tests.sh`, `migrations/` | Proves that a release updates projects of the previous release and of v0.1.0 without conflicts; adopts a repository that did not start from the standard | tested |
| `stacks/` | Source and test notes for the stack profiles; the profiles themselves are in the template (`stack` question) | reference |

## Contents

- [What a new project gets](#what-a-new-project-gets)
- [Requirements](#requirements)
- [Create a project](#create-a-project)
- [After creating](#after-creating)
- [Questions](#questions)
- [Spec Kit and dev-standard additions](#spec-kit-and-dev-standard-additions)
- [Updating a project](#updating-a-project)
- [Adopting an existing repository](#adopting-an-existing-repository)
- [Releasing dev-standard](#releasing-dev-standard)
- [Working on dev-standard](#working-on-dev-standard)
- [Verified](#verified)

## What a new project gets

| Area | Files |
|---|---|
| Principles | `CONSTITUTION.md`: six standard principles + room for project ones; works with and without Spec Kit (Spec Kit reads a synced copy) |
| Working rules | `AGENTS.md`: work types (feature, bug, release, chore) with an AI level each, hard rules, Definition of Done; `CLAUDE.md` imports both |
| Tracker | `TODO.md` with `<KEY>-<n>` items (or GitHub Issues / Jira) |
| Commits | Conventional Commits with the issue as scope, `feat(APP-12): …`; checked by the commit-msg hook and in CI; no AI watermark in commits, PR titles or PR text (`Co-Authored-By` trailers naming an AI tool, session links, "generated with" lines fail `commit-msg`, `pr-title` and `pr-text`) |
| Releases | `scripts/next-version` computes the version from the commits; `/release` skill prepares branch + changelog; a person merges and tags |
| Docs | product vision, research (dated notes, templates, retrospective), decision records with Evidence and Reversibility (MADR: 0001, 0002 choose the stack), workflow, **stack-layer playbook** (what to do after the first code), handover template, security exceptions; **writing rule** (`docs/process/writing.md`) |
| Claude Code | hooks: git rules per work type (`git-policy.sh`), protected files (`protect-paths.sh`), format the edited file (`format-file.sh`), report lint and writing-rule problems in it (`lint-file.sh`, `LINT_FILE_CMD`, Vale), checks before finishing (`run-checks.sh`, stages in `STOP_STAGES`), cloud setup; input parsed with jq, python3 or sed (`parse-input.sh`); no automatic MCP servers, web fetches ask; read-only `quality-reviewer` subagent; skills: Spec Kit's `/speckit-*` + `/release`, `/handover`, `/stack-layer`, `/quality-review`, `/stack-*`; `attribution` in `settings.json` is empty, so commits and PRs carry no tool trailer |
| Spec Kit | SDD process, idea assessment (no code needed), bug process, with the `dev-standard` preset |
| Checks | `scripts/check`: constitution sync, no code without gates, stack decided before plans, spikes only on spike branches, research notes dated and verified (decisions cite evidence, stale evidence fails), format/lint/typecheck, tests (0 tests fails), coverage of changed lines, safety tests, test integrity (deleted tests, skips, fewer asserts), **stack layer** (`stack-layer` + `architecture`, `complexity`, `perf`, `e2e`, `contract`, `security-native`, `fuzz`, `dast`: each decided once code exists), spec proof and scope (`proof`, `scope`), secrets (gitleaks incl. URL credentials, Discord webhooks, typed constants; no tracked `.env`), lockfiles + deps (trivy) + known malicious packages (osv-scanner `MAL-`), licences (trivy), SAST (opengrep + own rules), config (trivy), docs (markdownlint, links, **writing rule with Vale**: errors fail, warnings print; changed files only on a PR), `pr-text` (PR or MR body), security canary and quality canary of planted problems, hook tests with three input parsers; green on an empty repo |
| Tools | `scripts/verify-package <pypi\|npm\|crates\|nuget\|pub> <name> [version]`: does the package exist, licence, last release (registry API) |
| CI | GitHub (checks, PR title and PR text, label `agent` on agent PRs, guardrails, workflow audit with zizmor, optional CodeQL, release on tag with SBOM, cosign-signed checksums and provenance, optional Claude agent workflow, weekly settings check and long fuzz run) or GitLab (the same checks, tag pipeline with SBOM, release and back-merge MR) |
| Repo settings | `scripts/repo-settings [--gitlab] plan\|apply\|verify`: rulesets (GitLab: protected branches, pipelines must succeed) for `main`/`dev` (PR, required checks, no bypass, no force push), squash title = PR title, labels |

## Requirements

- [uv](https://docs.astral.sh/uv/) (runs Copier and Spec Kit with `uvx`, nothing to install globally)
- Git, Bash; [lefthook](https://lefthook.dev) for the git hooks
- Network on first run: Spec Kit and the opengrep rule sets are downloaded; `scripts/check docs` needs Node (markdownlint-cli2 via npx) and Vale (`scripts/install-tools vale`, pinned and checksum-verified); `scripts/verify-package` needs curl and jq

## Create a project

```bash
uvx --from copier==9.7.1 copier copy --trust gh:<owner>/dev-standard ./my-project
```

Copier asks the [questions](#questions), writes the files, then runs its tasks: `git init` (branch
`dev`), `specify init` + the preset, constitution sync, and vendoring the opengrep rule sets.
`--trust` is needed because of those tasks. Nothing is committed. Always generate from `gh:<owner>/dev-standard` (or an
absolute path or URL): Copier stores the source in `.copier-answers.yml`, and a relative path stops
`copier update` with "Updating is only supported in git-tracked templates".

Non-interactive example:

```bash
uvx --from copier==9.7.1 copier copy --trust --defaults \
  --data project_name="My App" --data project_slug=my-app --data issue_key=APP \
  --data tracker=todo --data feature_level=ai-assist --data bug_level=agentic --data release_level=agentic \
  --data platform=github --data use_speckit=true --data owner=<handle> \
  gh:<owner>/dev-standard ./my-app
```

## After creating

1. `cd my-project && scripts/setup` (hooks, scanners, rule sets).
2. Read `CONSTITUTION.md` and `AGENTS.md`; add project principles (VII+) with `/speckit-constitution` or by hand.
3. Review, then make the first commit by hand: `chore: set up the repository from dev-standard`.
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
| `feature_level` / `bug_level` / `release_level` / `update_level` | `ai-assist`, `agentic` | ai-assist / agentic / agentic / ai-assist |
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

## Spec Kit and dev-standard additions

| From Spec Kit (as is) | Changed by the dev-standard preset | Only in dev-standard (Spec Kit has no equivalent) |
|---|---|---|
| specify, clarify, plan, tasks, analyze, implement, converge, checklist | constitution command → edits `CONSTITUTION.md`, then syncs | `CONSTITUTION.md` usable without Spec Kit |
| idea assessment (`assess` extension) | constitution template: the six dev-standard principles | work types with AI levels, enforced by hooks |
| bug process (`bug` extension) | spec template: issue key, **Proof** table, **Security & Data** | Conventional Commits + key, `next-version`, `/release` |
| 43 agent integrations | plan template: **Guardrails & Security** gate, **Departures during build** | scanners, canary, guardrails, exceptions register, CI |

Spec Kit numbers spec folders `specs/001-…`; the issue key goes in the spec's **Issue** field.

## Working on dev-standard

dev-standard follows its own standard where it applies: issue key `STD`, tracker `TODO.md`,
Conventional Commits (`feat(STD-81): …`), the writing rule, guardrails (`.guardrails`), and
`AGENTS.md` / `CLAUDE.md` for AI tools.

```bash
git clone https://github.com/s-kroonen/dev-standard && cd dev-standard
scripts/setup                          # git hooks and every pinned tool into .tools/bin (checks and test scanners)
scripts/lint                           # bash -n, shellcheck, YAML parse
scripts/check docs                     # markdownlint, links, Vale on README, TODO, preset, stacks, template docs
tests/template-tests.sh /tmp/work      # generated projects: stages pass and fail where expected
tests/update-tests.sh /tmp/work2       # releases update projects of the previous release and of v0.1.0 without conflicts
scripts/repo-settings apply            # once, needs gh with admin rights (GH_REPO=s-kroonen/dev-standard)
```

`.github/workflows/ci.yml` runs `lint`, `render` (projects for `none`, `python`, `node`, `rust`,
GitLab and the agent workflow, with zizmor and Vale on the rendered files), `template-tests`,
`update-test` (`tests/update-tests.sh`), `pr-rules` (PR title, commits, PR text) and `guardrails`; `result` is the one required check. A
weekly run repeats the template tests and runs `scripts/repo-settings verify`.

A release is a tag `v<x.y.z>` on `main`; `copier update` in generated projects reads the tags
([docs/releasing.md](docs/releasing.md)).

## Updating a project

```bash
scripts/check standard-version      # is a newer version out? (weekly CI job; never fails)
scripts/update-standard APP-12      # branch chore/APP-12-update-dev-standard from dev, report at the end
```

Files in a generated project are of three kinds (`docs/process/updating.md` in the project):

| Kind | Files | An update |
|---|---|---|
| Standard files | `scripts/`, `.claude/`, the workflows, `check.config`, `.vale/styles/DevStandard/`, the canaries, `tests/hooks/cases.tsv`, `.opengrep/rules/custom/` | replaces them; never edited in the project |
| Project files | `README.md`, `CHANGELOG.md`, `TODO.md`, `project.config`, `docs/product/`, `docs/decisions/0002-*`, `docs/security-exceptions.md`, scanner exception files, `.opengrep/rules/project/`, `.vale/styles/Project/`, `tests/hooks/project-cases.tsv` | never touches them (`_skip_if_exists` in `copier.yml`) |
| Shared files | `AGENTS.md`, `CLAUDE.md`, `CONSTITUTION.md`, `.guardrails`, `lefthook.yml`, `.gitignore`, `CODEOWNERS` | merges them; each ends with a marked project section the standard never edits |

`check.config` (rules, pinned tools, stack profile) belongs to the standard; the project's values
live in `project.config`, sourced after it. `scripts/update-standard` refuses a dirty tree and
`main`, reads `_src_path` and `_commit` from `.copier-answers.yml`, runs the pinned Copier
(`copier update --trust --defaults --skip-tasks --conflict inline --vcs-ref <tag>`), then the post steps
(`scripts/post-update`: constitution copy and vendored rule sets; the Spec Kit preset when it
changed; `scripts/setup` when a pinned tool changed) and prints the report: upgrade notes of the
versions in between, files with conflict markers, changed guardrail files, whether
`scripts/repo-settings apply` is needed, `scripts/check fast`, and the commit message. The skill
`/update-standard` does the same for an agent. The update is mechanical; the PR review is the gate.

A project older than v0.3.0 makes its first jump with plain `copier update --trust --defaults
--conflict inline --vcs-ref v0.3.0`: a Copier migration moves the project's values from
`check.config` into `project.config` and runs the post steps.

Verified Copier 9.7.1 behaviour that the design rests on (evidence in `tests/update-tests.sh` and
below):

- `_skip_if_exists` applies on update: an existing file is kept, a missing one is created. Patterns
  are gitignore-style, but a leading `/` does not anchor them (`README.md` also matches
  `docs/research/README.md`; a later `!docs/research/README.md` takes it out again).
- `_tasks` run on update twice: in the project directory after the new standard files are rendered
  and before the merge restores the project's edits, and in a temporary copy that is not a git
  repository. Tasks of the old template run there too. `--skip-tasks` skips both.
- `_migrations` run in the project directory, `before` ahead of the update and `after` behind the
  merge, also with `--skip-tasks`. An entry with a `version` runs when the update crosses it
  (`from < version <= to`); one without runs on every update, after the merge. A migration reaches
  the new template's checkout through `{{ _copier_conf.src_path }}`; the environment has
  `STAGE`, `VERSION_FROM`, `VERSION_TO`.
- Old releases drop vendored files that their tasks created in a temporary copy (the opengrep rule
  sets): `scripts/post-update` vendors them again.

## Adopting an existing repository

A repository that did not start from the standard gets it on a branch with `copier copy --trust
gh:<owner>/dev-standard .`; project files that exist are kept, existing CI files stay next to the
standard's, and a list says what to merge by hand. See [docs/adopting.md](docs/adopting.md).

## Releasing dev-standard

A release is a tag `vX.Y.Z` on `main`; `CHANGELOG.md` has one section per version with Added,
Changed, Fixed and **Upgrade notes**. A renamed or removed standard file or variable, a new
required check or a new manual step is a breaking change (minor while 0.x) and ships a Copier
migration or an upgrade note; `tests/update-tests.sh` fails otherwise. `.github/workflows/release.yml`
publishes the GitHub release from the changelog section. See [docs/releasing.md](docs/releasing.md).

## Verified

Tested 2026-11-24 by generating a project (features ai-assist, bugs and releases agentic; Spec Kit 1.4.4):

- All 7 Copier tasks ran; Spec Kit installed 19 skills next to the dev-standard skills; `CLAUDE.md` untouched by Spec Kit; preset templates resolve.
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

Not verified: a real CI run (GitHub or GitLab), `repo-settings apply` or `--gitlab apply` on a live project, the cosign signing on a real tag, the Claude agent workflow (and whether it loads the hooks), the `quality-reviewer` agent and the `/stack-layer` and `/quality-review` skills inside Claude Code, the malicious-package gate against live osv.dev, licence scan of Python and Rust lockfiles, Rust coverage, the dotnet profile (no SDK) and the flutter profile. Follow-ups: `TODO.md` STD-71 to STD-79.

Writing-rule pass (2026-11-24; `tests/template-tests.sh`: 148 cases, all pass in 2m45s, with Vale 3.26.0, gitleaks, trivy, opengrep and shellcheck 0.11.0 on PATH):

- Vale: each error rule (`Pronouns`, `History`, `Filler`, `Hedging`, `Exclamation`, `Emoji`, `Watermarks`) fails a planted Markdown file and passes the fixed one; `<!-- vale off -->` works; a warning-only file passes and prints the warning; the full `docs` stage fails on a planted error and passes after the fix.
- Comments: a first-person comment fails in Python, TypeScript, Rust, Go and C#; a string literal is not read; shell comments are not read; `TODO` without a key fails, `TODO(TST-12)` passes. Vale 3.26.0 also reads Java, Kotlin, Swift, C, C++, Ruby, PHP and Scala (planted test, not part of the suite); Dart, shell, Lua, SQL, YAML, TOML, F# and Haskell comments are not read.
- `pr-text`: a body with a second-person pronoun, a Claude co-author trailer or a session link fails; a clean and an empty body pass. `commit-msg` rejects a Claude trailer, a Claude session line and a "generated with" line, accepts a human `Co-Authored-By` and a plain message; `pr-title` rejects a robot emoji.
- `settings.json` carries the empty `attribution`; the `.vale` files are in `.guardrails` and the sandbox `denyWrite` list. The `lint-file` hook exits 2 with the rule name on stderr for a Markdown error and for an unused Python import (ruff), and stays silent on clean files. Hook cases: 73 x 3 parsers (a bare `rm -rf .vale` and `rm -rf .claude` are blocked).
- `scripts/check docs` passes on this repository and on generated projects for `none`, `python`, `rust`, `dotnet`, `flutter`, GitLab, no Spec Kit, and mixed AI levels; `scripts/lint` (bash -n, shellcheck 0.11.0 at warning level, YAML) passes on 26 scripts; zizmor 1.33.1 reports nothing on the workflows of this repository, of the agent variant and of the default variant.
- Day 0 (`none`): `scripts/check all` green locally and with `CI=1`; `node` and `python` projects green in the suite; `rust` generated, `fast`, `build`, `quality-canary`, `hooks`, `docs`, `licenses` pass (`test` fails on the empty crate, as designed).

Not verified in this pass: `ci.yml` and the `docs` and `pr-rules` jobs on a real GitHub or GitLab run, `scripts/repo-settings apply` on this repository, the label step of `claude-agent.yml` (output name `branch_name` assumed), that Claude Code honours the `attribution` keys, eslint, flutter and dotnet `LINT_FILE_CMD`, Vale on macOS and Windows. Follow-ups: `TODO.md` STD-85 and STD-88 to STD-94.

Clean-updates pass (2026-11-25; `tests/template-tests.sh`: 167 cases, all pass; `tests/update-tests.sh`: 156 cases, all pass; Copier 9.7.1, with Vale, gitleaks, trivy, opengrep and shellcheck on PATH):

- Updates to the working tree (tagged `v0.3.0` in a scratch clone) from `v0.2.0` for the stacks `none`, `python` and `node`, and from `v0.1.0` for `none` and `python`: no conflict markers, project files byte-identical (README, TODO, product vision, decision records, project opengrep rule, project Vale term, `docs/security-exceptions.md`), project sections of `AGENTS.md` and `CONSTITUTION.md` and the `.guardrails` project line kept, constitution copy in sync, `_commit` and an absolute `_src_path` kept, the standard files (`scripts/`, hooks, workflows, `check.config`, `DevStandard` style, canary README, `docs/process/`) equal to a fresh render, `scripts/check all` green locally and with `CI=1` for `none`, and the static gates (research, secrets, sast, config, canary, hooks, docs) green for `python` and `node`.
- From `v0.1.0` and `v0.2.0` the migration moves the project's edited `COVERAGE_TOTAL_MIN`, `VALE_EXCLUDE` and `ARCH_CMD` from `check.config` into `project.config` and restores `check.config`; the first jump uses plain `copier update` (no `scripts/update-standard` yet).
- Second hop in a scratch clone (a synthetic release after the candidate that changes a standard file, `AGENTS.md` above its marker, `check.config`, the Spec Kit preset and the changelog): `scripts/update-standard` creates `chore/TST-10-update-dev-standard`, prints the upgrade note, the guardrail files, the commit message and "no repo-settings change", installs the changed preset again, keeps the project's lines below the markers and `project.config`, and `scripts/check all` is green; a dirty tree and `main` are refused (exit 2); a relative `_src_path` stops with the fix.
- Release rules: a section without upgrade notes fails, a renamed standard file that the notes do not name fails, the real changelog passes.
- Adoption: a repository with a README, a CI file and a `package.json` takes `copier copy --overwrite`; the three files stay byte-identical, the standard's workflows sit next to the existing CI file, `scripts/check fast` runs.
- zizmor 1.33.1 reports nothing on the workflows of this repository (including `release.yml` and the `update-test` job) and on the rendered agent variant.

Not verified in this pass: a real GitHub or GitLab run of `update-test`, `release.yml` and the weekly `standard-version` jobs; an update from a pushed `gh:<owner>/dev-standard` source (all runs use absolute local paths); `scripts/update-standard` inside a Claude Code session (sandbox and `protect-paths.sh` refusals); a project generated from an untagged commit (its `_commit` is a hash); the `rust`, `dotnet` and `flutter` stacks and the GitLab variant in an update; `scripts/setup` after a changed pin in `update-standard`. Follow-ups: the rows `STD-?` at the end of `TODO.md`.
