#!/bin/bash
set -euo pipefail

fail() {
    echo "rumdl-fix: $1" >&2
    exit "${2:-1}"
}

command -v jq > /dev/null || fail "jq is not installed; install jq, then run hk fix again"
(($# > 0)) || exit 0

findings=""
fix_and_check() {
    local rc=0
    findings=$(rumdl check --fix --deny-config-warnings --output-format json "$@") || rc=$?
    if ((rc > 1)); then
        fail "rumdl exited with status $rc (message above); fix .rumdl.toml or the file it names, then run hk fix again" "$rc"
    fi
    jq -e 'type == "array"' <<< "$findings" > /dev/null 2>&1 \
        || fail "rumdl printed output that is not a JSON findings list; run 'rumdl check' on the files by hand"
    return 0
}

print_findings() {
    jq -r '.[] | "\(.file):\(.line):\(.column): \(.rule) \(.message)"' <<< "$findings" >&2
}

fix_and_check "$@"
total=$(jq 'length' <<< "$findings")
((total > 0)) || exit 0
print_findings

if [[ ${RUMDL_AGENT:-1} == 0 || -n ${RUMDL_AGENT_RUNNING:-} || -n ${CI:-} ]]; then
    fail "findings remaining: $total; the agent is off (RUMDL_AGENT=0, RUMDL_AGENT_RUNNING or CI is set); fix the findings listed above by hand"
fi

agent="${RUMDL_AGENT_FILE:-$HOME/.omp/agent/agents/repo-markdown-fixer.md}"
if ! command -v omp > /dev/null || [[ ! -f $agent ]]; then
    fail "findings remaining: $total; omp or $agent is missing; install them or fix the findings listed above by hand"
fi

model=$(awk 'NR > 1 && /^---$/ { exit } sub(/^model: */, "")' "$agent")
prompt=$(awk 'f; /^---$/ && ++n == 2 { f = 1 }' "$agent")
model_args=()
[[ -z $model ]] || model_args=(--model "$model")
counts=$(jq -r 'group_by(.rule) | sort_by(-length) | .[] | "\(.[0].rule): \(length)"' <<< "$findings")
files=$(jq -r '.[].file' <<< "$findings" | sort -u)

echo "rumdl-fix: asking repo-markdown-fixer (${model:-default model}) to fix $total findings" >&2
agent_rc=0
RUMDL_AGENT_RUNNING=1 omp -p --no-session --no-title --no-skills --no-rules \
    ${model_args[@]+"${model_args[@]}"} --append-system-prompt "$prompt" \
    --tools read,edit,grep,glob,bash --max-time "${RUMDL_AGENT_MAX_TIME:-5m}" \
    "Repository root: $PWD
Linter: rumdl
Findings per rule, after rumdl check --fix:
$counts
Files with findings, one per line:
$files
Findings from rumdl check --output-format json:
$findings" >&2 || agent_rc=$?
((agent_rc == 0)) || echo "rumdl-fix: the agent exited with status $agent_rc; checking what it left" >&2

fix_and_check "$@"
remaining=$(jq 'length' <<< "$findings")
((remaining > 0)) || exit 0
print_findings
fail "findings remaining after the agent: $remaining; fix the findings listed above by hand"
