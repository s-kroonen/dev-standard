# PLAN — writing rule with Vale, central AI attribution, checks on the standard itself

The previous plan (stack-layer playbook, research guardrails, process, security) is built; its
results are in `TODO.md` (STD-8 to STD-80) and in git history.

Three changes, one build:

- **A. Writing rule**, enforced with Vale (replaces STD-76's open half).
- **B. Central AI attribution**: no watermarks per commit, PR or doc; the role of AI is described
  once, in `AGENTS.md` and the README.
- **C. The standard checks itself**: dev-standard gets its own CI, rules and tests, so a local
  clone with `gh` can set up the GitHub side and everything is verified on this repository.

New `TODO.md` rows start at STD-81.

## Rules for the build

- Edit only files in this repository. Test in a scratch directory with generated projects
  (`uvx --from copier==9.7.1 copier copy --trust --defaults --vcs-ref HEAD <this repo> <dir> --data stack=<none|python|node|rust> ...`)
  and with `tests/template-tests.sh`.
- No commits. Pin only versions that were looked up (release page + checksum; action SHAs with
  `git ls-remote`); prefer releases at least 14 days old.
- Every new check gets a failing and a passing case in `tests/template-tests.sh`; hook rules get
  rows in `template/tests/hooks/cases.tsv`.
- Day 0 stays green: a fresh `stack=none` project passes `scripts/check all`, also with `CI=1`.
- All text written in this build follows the writing rule below.

## A. Writing rule, enforced with Vale

### A1. The rule (goes into `template/docs/process/writing.md`, summarised in `AGENTS.md`)

Applies to docs, code comments, changelog entries, TODO items, PR/MR text, handovers.

1. <!-- vale off -->No first or second person: no we, our, us, I, my, you, your. Name the thing: "dev-standard
   adds…", "The hook blocks…".
2. Describe what exists, in the present tense: "The `deps` stage fails on…".
3. Steps use the imperative without "you": "Run `scripts/setup`."
4. No history in docs or comments: no "now", "new", "no longer", "previously", "updated to",
   "added by". History lives in git and `CHANGELOG.md`.
5. Comments explain why, not what. No commented-out code. A TODO in code carries an issue key:
   `TODO(KEY-12): …`.
6. No filler or marketing: simply, just, easily, robust, seamless, powerful, comprehensive,
   leverage, "note that", "it's worth noting"; no emojis, no exclamation marks.
7. No hedging: "should work", "hopefully". State what is verified and what is not.
8. Changelog entries describe the product change: "Fixture groups can be renamed".
9. TODO item titles state the problem or the outcome: "Pan overshoots at the end of a cue".
10. No AI watermarks in any text (see B).
11. Commit subjects stay imperative Conventional Commits (`fix(KEY-31): stop pan overshoot`);
    Vale does not check commit subjects.
12. Text in another language (domain data) is out of scope; its paths are excluded. <!-- vale on -->

### A2. Vale in the template

1. Pin Vale (latest release ≥ 14 days old) in `check.config.jinja` (`VALE_VERSION`,
   `VALE_SHA256`) and install it in `scripts/install-tools`; macOS/Windows notes like the other
   tools.
2. `.vale.ini` + `.vale/styles/DevStandard/*.yml`, shipped in the template, offline (no
   `vale sync`, no third-party packages by default; document how to add write-good or proselint
   vendored at a pinned version). Rules:
   - <!-- vale off -->**error**: `Pronouns` (A1.1), `History` (A1.4), `Filler` (A1.6), `Hedging` (A1.7),
     `Watermarks` (B: "Co-Authored-By: Claude", "Generated with Claude Code", "🤖", session
     links), `TodoKey` (A1.5, comments: `TODO` without `(KEY-n)`), `Exclamation`; <!-- vale on -->
   - <!-- vale off -->**warning**: `SentenceLength` (> 30 words), `Passive` (simple existence pattern),
     `HeadingCase` (sentence case), `Substitutions` (utilize→use, in order to→to, …); <!-- vale on -->
   - `config/vocabularies/DevStandard/accept.txt` with project terms (Spec Kit, Copier, lefthook,
     opengrep, gitleaks, trivy, …); the project adds its own.
3. Scope in `.vale.ini`: Markdown (`*.md`), source comments for the languages Vale supports
   (check which: Python, JS/TS, Rust, C#, Go; Dart and shell comments only if supported,
   otherwise say so in `writing.md`); exclude `tests/*-canary/`, `spikes/`, `.specify/`,
   `node_modules/`, vendored rules, and a `VALE_EXCLUDE` list from `check.config` for
   other-language content.
4. `scripts/check docs`: runs Vale (errors fail, warnings are printed); with a base branch
   (`scripts/check docs [base]`, used in CI) only changed files; `scripts/check pr-text` reads the
   PR/MR body from `PR_BODY` (env) and runs Vale on it (`--ext=.md`). Keep the existing
   markdownlint and link checks in `docs`.
5. CI: GitHub `checks.yml` and GitLab run `docs` on changed files and `pr-text` on the PR body
   (passed through `env`, never interpolated into the script — zizmor must stay clean).
6. Agent feedback (STD-76): PostToolUse hook `lint-file.sh` (or extend `format-file.sh`) runs
   `LINT_FILE_CMD` (per profile: `ruff check {file}`, `npx eslint {file}`, `cargo clippy` is
   crate-wide so skip for rust, …) and Vale on edited `.md` files; problems go to stderr with
   exit 2 so the agent sees them; never blocks the edit itself.
7. <!-- vale off -->Sweep: every Markdown and `.md.jinja` file in the template, the preset, `stacks/`, and this
   repository's own `README.md`, `TODO.md` and `PLAN.md` passes the error rules (render the
   `.jinja` docs in a generated project to lint them; the standard's own CI does the same).
   Includes "how we work" in `AGENTS.md`, "what we value" in the constitution, every "you" in the
   README and skills. <!-- vale on -->
8. `AGENTS.md` hard rule "Writing" (short, links `docs/process/writing.md`); one line in
   `CLAUDE.md`; handover and PR/MR templates written in the same style.

## B. Central AI attribution instead of watermarks

1. `template/.claude/settings.json`: `"attribution": {"commit": "", "pr": "", "sessionUrl": false}`
   (Claude Code setting; `includeCoAuthoredBy` is deprecated).
2. Constitution V (template and preset), `AGENTS.md` rule "Transparency", README "How AI is
   used": the role of AI per work type is described once, there. No `Co-Authored-By`, session
   links or "generated with" lines in commits, PRs, code or docs.
3. Agent work stays traceable without watermarks: agent branches (`claude/`, `ccr-`, the
   agentic work types), the PR label `agent` (set by the agent workflow and by agents that open
   PRs: `gh pr create --label agent`), and the bot author of Action commits.
4. PR/MR templates: drop the "AI use" checkboxes; keep the agent review checklist, titled "PRs
   labelled `agent`".
5. <!-- vale off -->`scripts/check commit-msg` fails on watermark trailers (`Co-Authored-By:` naming an AI tool,
   `Claude-Session:`, "Generated with …"); pattern `WATERMARK_PATTERN` in `check.config`. The PR
   title/body checks apply the same pattern. <!-- vale on -->
6. `claude-agent.yml`: PRs it opens get the label `agent`; allowed tools include
   `gh pr create`, `gh pr edit --add-label agent`.
7. `TODO.md` STD-60 text: remove the Co-Authored-By detection idea.

## C. The standard checks itself

dev-standard follows its own standard where it applies: issue key `STD`, tracker `TODO.md`,
Conventional Commits (`feat(STD-81): …`), writing rule, guardrails.

1. Root `AGENTS.md` + `CLAUDE.md` for this repository: what it is, layout (`template/`,
   `speckit-preset/`, `stacks/`, `tests/`), how to change and test it, work types (features
   ai-assist; fixes and releases agentic), the writing rule, never weaken a test or check.
2. Root `lefthook.yml` + `scripts/` (thin wrappers or symlinks to the template's commit-msg and
   branch checks, with `ISSUE_KEY=STD`) so commits here follow the same rules.
3. Root `.guardrails` + `.claude/` (hooks from the template, settings with `attribution` empty,
   sandbox) so an agent working on the standard is constrained the same way; hook cases run in
   CI.
4. `.github/workflows/ci.yml` for this repository (actions pinned by SHA,
   `persist-credentials: false`, minimal permissions):
   - `lint`: `bash -n` + shellcheck (pinned) on every script in `template/scripts`,
     `template/.claude/hooks`, `tests/`; YAML parse of every workflow and GitLab file;
     gitleaks on the repository; Vale + markdownlint on this repository's docs;
   - `render`: generate `none`, `python`, `node`, `rust` (+ gitlab, + `github_agent`) projects;
     zizmor 1.33.1 on the rendered workflows; Vale on the rendered docs;
   - `template-tests`: `tests/template-tests.sh` (installs the pinned scanners via a generated
     project's `scripts/install-tools`);
   - `pr-rules`: PR title and commit messages (`ISSUE_KEY=STD`), PR body via `pr-text`;
   - `result`: the one required check (same pattern as the template), plus a `guardrails` job,
     so `template/scripts/repo-settings apply` works on this repository unchanged
     (`GH_REPO=s-kroonen/dev-standard`).
   - weekly schedule: template tests + `repo-settings verify`.
5. `.github/dependabot.yml` for this repository's actions (cool-down 14 days).
6. Root README section "Working on dev-standard": clone, `scripts/setup`, run the tests,
   `scripts/repo-settings apply` once (needs `gh` with admin rights), release by tag `v<x.y.z>`
   (`copier update` uses the tags).

## D. Tests (in `tests/template-tests.sh` and the repository CI)

- A planted doc with each error rule fails `docs`; the fixed doc passes; `<!-- vale off -->`
  works; a warning-only doc passes with output.
- <!-- vale off -->A Python (and TS) comment with "we" fails when Vale supports that language. <!-- vale on -->
- <!-- vale off -->`pr-text` fails on a body with "you" or a watermark, passes a clean body. <!-- vale on -->
- <!-- vale off -->`commit-msg` rejects a `Co-Authored-By: Claude…` trailer and a `Claude-Session:` line, accepts
  a plain message. <!-- vale on -->
- Generated `settings.json` contains the empty `attribution`.
- The lint-file hook reports a Vale error for an edited Markdown file (exit 2 + stderr) and
  stays silent on a clean file.
- Day-0 `scripts/check all` green locally and with `CI=1`; node, python, rust projects green.
- The repository's own checks (C4 lint and render jobs) run locally and pass.

## E. Finish

- `TODO.md`: rows STD-81 onwards for A, B, C (status per row), STD-76 updated; next free number.
- `README.md`: what a project gets (writing rule, Vale, attribution), Verified section.
- Report: built, tested (commands + results), not verified, deviations from this plan.
