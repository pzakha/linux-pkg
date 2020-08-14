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
	echo "Usage: $(basename "$0")"
	echo ""
	echo "  This is a wrapper script that is meant to be called from"
	echo "  Jenkins. It consumes and processes environment variables"
	echo "  passed from Jenkins and call 'buildpkg.sh <PACKAGE_NAME>'."
	echo ""
	exit 2
}

#
# Converts PACKAGE_S3_URLS into distinct package-prefixed variables of the form
# of <PACKAGE>_S3_URL. See example below.
#
# If PACKAGE_S3_URLS is:
# '''
# zfs: s3:/dev-bucket/path/to/zfs/artifacts/
# cloud-init: s3:/dev-bucket/path/to/cloud-init/artifacts/
# '''
#
# Then this produces the following environment variables:
# ZFS_S3_URL=s3:/dev-bucket/path/to/zfs/artifacts/
# CLOUD_INIT_S3_URL=s3:/dev-bucket/path/to/cloud-init/artifacts/
#
function parse_package_s3_urls() {
	local line
	local pkg
	local url
	local prefix
	local var

	while IFS= read -r line; do
		# Skip blank lines
		[[ -z "$(echo "$line" | tr -d '[:space:]')" ]] && continue

		pkg="$(echo "$line" | cut -d ':' -f 1 | tr -d '[:space:]')"
		url="$(echo "$line" | cut -d ':' -f 2- | tr -d '[:space:]')"
		if [[ -z $pkg ]] || [[ -z $url ]]; then
			die "Error parsing PACKAGE_S3_URLS, invalid format of" \
				"line '$line'"
		fi
		check_package_exists "$pkg"
		aws s3 ls "$url" >/dev/null || die "Invalid S3 URL: $url"
		get_package_prefix "$pkg"
		prefix="$_RET"
		var="${prefix}_S3_URL"
		logmust export "${var}=$url"
	done < <(printf '%s\n' "$PACKAGE_S3_URLS")
}

[[ $# -eq 0 ]] || usage "takes no arguments." >&2

check_env PACKAGE_NAME
check_package_exists "$PACKAGE_NAME"

if [[ -n $PACKAGE_S3_URLS ]]; then
	logmust parse_package_s3_urls
fi

args=()
if [[ -n $PACKAGE_GIT_URL ]]; then
	args+=(-g "$PACKAGE_GIT_URL")
fi
if [[ -n $PACKAGE_GIT_BRANCH ]]; then
	args+=(-b "$PACKAGE_GIT_BRANCH")
fi

logmust cd "$TOP"
logmust ./setup.sh
logmust ./buildpkg.sh "${args[@]}" "$PACKAGE_NAME"
