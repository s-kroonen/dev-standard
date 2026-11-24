#!/usr/bin/env bash
#
# Claude Code PostToolUse hook: formats the file the agent just wrote or edited, so the agent sees
# formatted code right away (and the `format` check at the end finds nothing to complain about).
# FORMAT_FILE_CMD in check.config, with {file} for the path (empty or "none": does nothing).
# Never blocks: a formatter that fails or is missing is reported on stderr and the edit stands.

shopt -u patsub_replacement 2>/dev/null
input="$(cat)"
# shellcheck source=parse-input.sh
source "$(dirname "${BASH_SOURCE[0]}")/parse-input.sh" || exit 0
root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
[[ -f "$root/check.config" ]] || exit 0

cmd_tpl="$(bash -c 'source "$1/check.config" 2>/dev/null; echo "${FORMAT_FILE_CMD:-}"' _ "$root")"
[[ -z "$cmd_tpl" || "$cmd_tpl" == none ]] && exit 0

while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    path="${path//\\//}"
    [[ "$path" == "$root"/* && -f "$path" ]] || continue
    rel="${path#"$root"/}"
    # Planted problems, throwaway code and generated tooling are not ours to reformat.
    [[ "$rel" =~ ^(tests/(quality|security)-canary|spikes|\.specify|\.claude|\.opengrep|node_modules|\.tools)/ ]] && continue
    (cd "$root" && bash -c "${cmd_tpl//\{file\}/$(printf '%q' "$rel")}") >/dev/null 2>&1 \
        || echo "format-file: '$cmd_tpl' failed for $rel (the format check will say what is wrong)" >&2
done < <(hook_paths)
exit 0
