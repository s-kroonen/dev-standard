# Changelog

All releases of dev-standard. A project that updates reads the **Upgrade notes** of every version
between its own and the new one; `scripts/update-standard` prints them. Versioning rules are in
[docs/releasing.md](docs/releasing.md): a renamed or removed standard file or variable, a new
required check or a new manual step is a breaking change (minor while the major version is 0), and
each breaking change ships a Copier migration or an upgrade note.

## v0.3.0 (unreleased)

### Added

- File ownership for clean updates: standard files, project files (`_skip_if_exists` in
  `copier.yml`) and shared files with a marked project section
  (`docs/process/updating.md` in every project).
- `project.config`: the project's own settings, sourced after `check.config` by `scripts/check`,
  `scripts/setup`, `scripts/update-rules` and the hooks.
- Extension points that updates never touch: `.opengrep/rules/project/`, `.vale/styles/Project/`,
  `tests/hooks/project-cases.tsv`.
- `scripts/update-standard <KEY-n> [--to vX.Y.Z]`, the skill `/update-standard` and the Copier
  question `update_level` (work type "Standard update").
- `scripts/post-update`: constitution copy and vendored rule sets after a merge.
- `scripts/check standard-version` and a weekly CI job: a newer version prints its upgrade notes.
- `tests/update-tests.sh` and the CI job `update-test`: every release is proven to update projects
  of the previous release and of v0.1.0 without conflicts.
- `docs/adopting.md`: adopt a repository that did not start from the standard.
- This changelog, `docs/releasing.md` and a release workflow for this repository.

### Changed

- `check.config` is a standard file that every update replaces. Coverage thresholds, `VALE_EXCLUDE`
  and the stack-layer variables move to `project.config`.
- `AGENTS.md`, `CLAUDE.md`, `CONSTITUTION.md`, `.guardrails`, `lefthook.yml`, `.gitignore` and
  `CODEOWNERS` end with a marker line; the standard never edits below it.
- `CODEOWNERS`, `.trivyignore.yaml`, `osv-scanner.toml` and `docs/security-exceptions.md` are
  project files.
- Copier tasks that read shared files (constitution sync, rule vendoring) run as a migration after
  the merge instead of a task before it.
- The README of generated projects documents updates; generation examples use `gh:<owner>/dev-standard`.

### Fixed

- The synced constitution copy is current after `copier update`.
- A relative `_src_path` stops `scripts/update-standard` with the fix; the README examples use
  `gh:<owner>/dev-standard`.

### Upgrade notes

- A Copier migration moves the project's values from `check.config` into `project.config` and
  restores `check.config`. Review `project.config` and the diff of `check.config` in the PR.
  Edited pinned-tool versions in `check.config` are dropped.
- The first update from v0.1.0 or v0.2.0 runs with plain `copier update --trust --defaults
  --conflict inline --vcs-ref v0.3.0`; `scripts/update-standard` exists from v0.3.0 on.
- Shared files gain a marker line. A project that appended its own text at the end of `CLAUDE.md`,
  `lefthook.yml`, `.gitignore` or `CODEOWNERS` resolves one conflict there: its text goes below the
  marker.
- New guardrail files: `project.config` (also in `CODEOWNERS` and the sandbox `denyWrite` list of
  `.claude/settings.json`). Run `scripts/check hooks` after the update.
- New Copier question `update_level` (default `agentic`) and the branch pattern
  `chore/<KEY>-<n>-update-dev-standard` for agents.
- If `_src_path` in `.copier-answers.yml` is a relative path, set it to `gh:<owner>/dev-standard`
  before updating.

## v0.2.0

### Added

- The writing rule (`docs/process/writing.md`), enforced by Vale (pinned, offline `DevStandard`
  style) on Markdown, source comments and PR text; the PostToolUse hook `lint-file.sh`.
- AI attribution in `AGENTS.md` and the README only; commit, PR title and PR body checks reject
  watermarks.
- dev-standard runs its own CI, hooks and guardrails with the issue key `STD`.

### Changed

- The merge request template and the Node profile gain the writing-rule entries.

### Upgrade notes

- Run `scripts/setup` to install Vale; `scripts/check docs` fails in CI without it.

## v0.1.0

### Added

- The Copier template and the Spec Kit preset for day 0 of a project: constitution, agent rules and
  work types with AI levels, Claude Code hooks and sandbox, `scripts/check` as the one entry point
  (quality, security, test integrity, canaries), GitHub and GitLab CI, release and repo-settings
  scripts, and the stack-layer playbook.

### Upgrade notes

- None: the first release.
