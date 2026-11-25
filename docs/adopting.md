# Adopting an existing repository

A repository that did not start from dev-standard gets the standard on a branch. Nothing of the
project is overwritten silently: project files that exist are kept, and everything else shows up as
a diff to review.

## Steps

1. New branch from the default branch: `git switch -c chore/<KEY>-adopt-dev-standard`. The issue key
   (2 to 10 capitals) is asked for by the template.
2. Run Copier in the repository:

   ```bash
   uvx --from copier==9.7.1 copier copy --trust gh:<owner>/dev-standard .
   ```

   Answer the questions (stack, platform, AI levels). `--trust` is needed for the tasks (Spec Kit
   setup, executable bits).
3. Files that exist and are project files are kept. The list is `_skip_if_exists` in the
   standard's `copier.yml`: `README.md`, `CHANGELOG.md`, `TODO.md`, `project.config`,
   `docs/product/`, `docs/decisions/0002-*`, `docs/security-exceptions.md`, `.trivyignore.yaml`,
   `osv-scanner.toml`, `.prettierignore` and the extension points. For any other file that exists,
   Copier asks; with `--overwrite` it replaces them. Answer "no" (or pass `--skip <path>`) for a file
   whose content must stay, then merge by hand.
4. Existing CI files stay next to the standard's: the standard's workflows have their own names
   (`checks.yml`, `guardrails.yml`, `release.yml`). A workflow with one of these names is replaced.
5. Merge by hand and commit in small steps:
   - **CI**: decide per job whether the existing one is covered by `scripts/check`; remove the
     duplicates in a later PR.
   - **Lint and format configuration** (`eslint`, `ruff`, `prettier`, `tsconfig`): the stack profile
     in `check.config` calls the project's tools; put differences in `project.config`.
   - **README**: keep the project's text; add the sections of the standard's README that apply
     (commands, AI use, updating).
   - **`.gitignore`, `lefthook.yml`, `CODEOWNERS`**: the project's own lines go below the marker line.
   - **Branch names**: `scripts/check branch` expects `<type>/<KEY>-<n>-<slug>`; existing branches
     are renamed when they continue.
   - **Commit history**: the commit rule (`scripts/check commit-msg`) applies to new commits only.
     Old commits that break it do not matter; the PR check reads the commits of the PR.
6. Run `scripts/setup` and `scripts/check all`. Fix what the checks find in project code; decide
   the stack layer with `/stack-layer`. Commit `.copier-answers.yml`.
7. Open the PR, label `guardrail-change` (set by a maintainer), then `scripts/repo-settings apply`.

After the merge the project updates like any other: `scripts/update-standard <KEY-n>`
([updating.md](../template/docs/process/updating.md)).
