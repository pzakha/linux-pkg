#!/bin/bash
#
# Copyright 2020 Delphix
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

TOP="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$TOP/lib/common.sh"

logmust check_running_system

function usage() {
	[[ $# != 0 ]] && echo "$(basename "$0"): $*"
	echo "Usage: $(basename "$0") <package>"
	echo ""
	echo "  Push code that was previously merged. sync-with-upstream.sh must"
	echo "  already have been run. Before pushing the merge, it will first"
	echo "  check that the target branch has not been updated since the merge"
	echo "  was performed, and fail if it is the case."
	echo ""
	echo "  As a safety check, DRYRUN environment variable must be set to"
	echo "  'false'."
	echo ""
	echo "    -h  display this message and exit."
	echo ""
	exit 2
}

while getopts ':h' c; do
	case "$c" in
	h) usage >&2 ;;
	*) usage "illegal option -- $OPTARG" >&2 ;;
	esac
done
shift $((OPTIND - 1))
[[ $# -lt 1 ]] && usage "package argument missing" >&2
[[ $# -gt 1 ]] && usage "too many arguments" >&2
PACKAGE=$1

if [[ "$DRYRUN" != 'false' ]]; then
	die "DRYRUN environment variable must be set to 'false'."
fi

logmust check_package_exists "$PACKAGE"

DEFAULT_REVISION="${DEFAULT_REVISION:-$(default_revision)}"
logmust determine_default_git_branch
logmust load_package_config "$PACKAGE"

if [[ ! -d "$WORKDIR/repo" ]]; then
	die "$WORKDIR/repo doesn't exist, have you run sync-with-upstream for" \
		"package $PACKAGE?"
fi
logmust cd "$WORKDIR/repo"

set -o pipefail
echo "Running: git show-ref refs/heads/repo-HEAD-saved"
saved_ref=$(git show-ref "refs/heads/repo-HEAD-saved" | awk '{print $1}') ||
	die "Failed to read local ref refs/heads/repo-HEAD-saved"
remote_ref=$(git ls-remote "$DEFAULT_PACKAGE_GIT_URL" "refs/heads/$DEFAULT_GIT_BRANCH" |
	awk '{print $1}') ||
	die "Failed to read remote ref refs/heads/$DEFAULT_GIT_BRANCH"
set +o pipefail

if [[ "$saved_ref" != "$remote_ref" ]]; then
	touch "$WORKDIR/merge-commit-outdated"
	die "Remote branch $DEFAULT_GIT_BRANCH was modified while merge" \
		"testing was being performed. Previous hash: $saved_ref," \
		"new hash: $remote_ref. Not pushing merge."
fi

logmust check_git_credentials_set

# TODO: set force if rebase required
logmust push_to_remote "refs/heads/repo-HEAD" \
	"refs/heads/$DEFAULT_GIT_BRANCH" false

echo_success "Merge pushed successfully for package $PACKAGE to remote" \
	"branch $DEFAULT_GIT_BRANCH"
