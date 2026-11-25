#!/usr/bin/env bash
#
# Copier migration of dev-standard v0.3.0 (stage "after", run in the project directory by
# `copier update`; the new template's checkout is the first argument).
#
# Before v0.3.0, check.config held the project's own values between `# >>> project` and
# `# <<< project` and in the section `# >>> stack layer playbook`, and the project edited the file.
# From v0.3.0 on, check.config is a standard file that every update replaces, and the project's
# values live in project.config. This script
#   1. renders the previous and the new version of the template (same answers) into a scratch folder;
#   2. takes every top-level assignment of the project's committed check.config (HEAD) that differs
#      from the previous standard's own value: these are the project's values;
#   3. writes them into project.config (the new skeleton replaces a line of the same variable; the
#      rest goes under a heading at the end);
#   4. replaces check.config (merged, possibly with conflict markers) with the new standard file.
# Needs a clean start: the update refuses to run on a dirty tree, so HEAD is the project's version.
# Safe to run again: a project.config with the marker line is left alone.
set -uo pipefail
src="${1:?usage: v0.3.0-project-config.sh <template checkout>}"
from="${VERSION_FROM:-}"; to="${VERSION_TO:-}"
marker="# Values moved from check.config by the v0.3.0 migration"

[[ -f project.config ]] || { echo "migration v0.3.0: no project.config in the new render; nothing to do." >&2; exit 0; }
if grep -qF "$marker" project.config; then echo "migration v0.3.0: already applied."; exit 0; fi
if ! git rev-parse --verify -q HEAD >/dev/null; then echo "migration v0.3.0: no git history; move your values from check.config into project.config by hand." >&2; exit 0; fi
if ! git show HEAD:check.config >/dev/null 2>&1; then echo "migration v0.3.0: no committed check.config; nothing to move."; exit 0; fi

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
copier_version="$(sed -n 's/^COPIER_VERSION="\([0-9.]*\)".*/\1/p' "$src/template/check.config.jinja")"
copier_version="${copier_version:-9.7.1}"
if command -v uvx >/dev/null 2>&1; then copier=(uvx --quiet --from "copier==$copier_version" copier); else copier=(copier); fi
answers="$tmp/answers.yml"; cp .copier-answers.yml "$answers"

render() { # <ref> <dir>
    "${copier[@]}" copy --trust --defaults --skip-tasks --overwrite --quiet --vcs-ref "$1" --data-file "$answers" "$src" "$2" >/dev/null 2>&1
}
if [[ -z "$from" ]] || ! render "$from" "$tmp/old"; then
    echo "migration v0.3.0: cannot render the previous standard ($from); move your values from check.config into project.config by hand." >&2
    exit 0
fi
render "${to:-HEAD}" "$tmp/new" || { echo "migration v0.3.0: cannot render the new standard." >&2; exit 0; }

git show HEAD:check.config > "$tmp/user.config"
assign() { grep -E '^[A-Z][A-Z0-9_]*=' "$1"; }   # one line per top-level assignment
declare -A pristine=()
while IFS= read -r line; do pristine["${line%%=*}"]="$line"; done < <(assign "$tmp/old/check.config")

moved=(); skipped=()
while IFS= read -r line; do
    name="${line%%=*}"
    [[ "${pristine[$name]:-}" == "$line" ]] && continue
    if [[ "$name" =~ _(VERSION|SHA256|COMMIT|IMAGE)$ ]]; then skipped+=("$name"); continue; fi
    # '|' and '&' are special in the sed replacement: escape them with the backslash.
    esc="$(printf '%s' "$line" | sed 's/[\\&|]/\\&/g')"
    if grep -qE "^${name}=" project.config; then
        sed -i "s|^${name}=.*|${esc}|" project.config
    else
        if ! grep -qF "$marker" project.config; then printf '\n%s (%s -> %s)\n' "$marker" "$from" "$to" >> project.config; fi
        printf '%s\n' "$line" >> project.config
    fi
    moved+=("$name")
done < <(assign "$tmp/user.config")
grep -qF "$marker" project.config || printf '\n%s (%s -> %s)\n' "$marker" "$from" "$to" >> project.config

cp "$tmp/new/check.config" check.config
echo "migration v0.3.0: check.config is the standard file again; ${#moved[@]} value(s) of the project moved into project.config${moved:+: ${moved[*]}}."
if [[ ${#skipped[@]} -gt 0 ]]; then echo "migration v0.3.0: pinned-tool values edited in check.config are dropped (${skipped[*]}); the standard owns the pins."; fi
exit 0
