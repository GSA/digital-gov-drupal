#!/bin/bash

# Bulk-delete the log archives for a GitHub Actions workflow's runs, filtered by branch.
#
# Deletes ONLY the log archive for each matching run
# (DELETE /repos/{owner}/{repo}/actions/runs/{id}/logs); the run row itself (status,
# timing, commit) remains visible in the Actions UI.
#
# Requires the `gh` CLI (authenticated) and `jq`.

set -uo pipefail

help(){
  echo "Usage: $0 -w <workflow> -b <branch-pattern> [options]" >&2
  echo
  echo "   -w   Workflow file name or numeric id (e.g. build-and-deploy.yml)   [required]"
  echo "   -b   Branch name or glob pattern (e.g. develop  or  '*-deploydev')  [required]"
  echo "   -r   Repository in owner/repo form   (default: GSA/digital-gov-drupal)"
  echo "   -n   Dry run: print the gh commands that would run; make NO changes"
  echo "   -h   Show this help"
}

RED='\033[0;31m'
NC='\033[0m'

REPO="GSA/digital-gov-drupal"
DRYRUN=""

while getopts 'w:b:r:nh' flag; do
  case ${flag} in
    w) WORKFLOW=${OPTARG} ;;
    b) BRANCH=${OPTARG} ;;
    r) REPO=${OPTARG} ;;
    n) DRYRUN=1 ;;
    h) help && exit 0 ;;
    *) help && exit 1 ;;
  esac
done

# --- Preflight -------------------------------------------------------------

if ! hash gh 2>/dev/null ; then
  echo "Please install the GitHub CLI:
    https://github.com/cli/cli#installation"
  exit 1
fi

if ! hash jq 2>/dev/null ; then
  echo "Please install jq:
    https://jqlang.github.io/jq/download/"
  exit 1
fi

[[ -z "${WORKFLOW:-}" ]] && help && echo -e "\n${RED}Error: Missing -w flag.${NC}" && exit 1
[[ -z "${BRANCH:-}" ]] && help && echo -e "\n${RED}Error: Missing -b flag.${NC}" && exit 1

if ! gh auth status >/dev/null 2>&1 ; then
  echo -e "${RED}Error: gh is not authenticated.${NC} Run: gh auth login -h github.com" >&2
  exit 1
fi

# --- Collect matching run ids ---------------------------------------------

run_ids=()

if [[ "${BRANCH}" == *[\*\?\[]* ]]; then
  # Glob pattern: the API branch= filter is exact-match only, so list every run for
  # the workflow and match head_branch client-side with a bash glob.
  echo "Listing runs for workflow '${WORKFLOW}' in ${REPO}, matching branch pattern '${BRANCH}'..."
  while IFS=$'\t' read -r id head_branch; do
    [[ -z "${id}" ]] && continue
    if [[ "${head_branch}" == ${BRANCH} ]]; then
      run_ids+=("${id}")
    fi
  done < <(gh api --paginate \
    "repos/${REPO}/actions/workflows/${WORKFLOW}/runs?per_page=100" \
    --jq '.workflow_runs[] | [.id, .head_branch] | @tsv')
else
  # Exact branch name: let the API filter server-side.
  echo "Listing runs for workflow '${WORKFLOW}' in ${REPO}, branch '${BRANCH}'..."
  while read -r id; do
    [[ -z "${id}" ]] && continue
    run_ids+=("${id}")
  done < <(gh api --paginate \
    "repos/${REPO}/actions/workflows/${WORKFLOW}/runs?branch=${BRANCH}&per_page=100" \
    --jq '.workflow_runs[].id')
fi

matched=${#run_ids[@]}
echo "Matched ${matched} run(s)."

if [[ "${matched}" -eq 0 ]]; then
  exit 0
fi

# --- Delete log archives ---------------------------------------------------

deleted=0
failed=0

for id in "${run_ids[@]}"; do
  cmd="gh api -X DELETE repos/${REPO}/actions/runs/${id}/logs"
  if [[ -n "${DRYRUN}" ]]; then
    echo "# ${cmd}"
    deleted=$((deleted + 1))
    continue
  fi
  if ${cmd} >/dev/null 2>&1 ; then
    echo "Deleted logs for run ${id}."
    deleted=$((deleted + 1))
  else
    echo -e "${RED}Failed to delete logs for run ${id} (already expired or no logs).${NC}" >&2
    failed=$((failed + 1))
  fi
done

echo
if [[ -n "${DRYRUN}" ]]; then
  echo "Dry run: ${matched} run(s) matched, ${deleted} deletion command(s) would run, 0 executed."
else
  echo "Done: ${matched} matched, ${deleted} log archive(s) deleted, ${failed} failure(s)."
fi
