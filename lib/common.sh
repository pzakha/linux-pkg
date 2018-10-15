#!/bin/bash
#
# Copyright 2018 Delphix
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

export _RET
export _RET_LIST
export DEBIAN_FRONTEND=noninteractive

# TODO: allow updating upstream for other branches than master
export REPO_UPSTREAM_BRANCH="upstreams/master"

# shellcheck disable=SC2086
function enable_colors() {
	export DPKG_COLORS="always"
	[[ -t 1 ]] && flags="" || flags="-T xterm"
	FMT_RED="$(tput $flags setaf 1)"
	FMT_GREEN="$(tput $flags setaf 2)"
	FMT_BOLD="$(tput $flags bold)"
	FMT_NF="$(tput $flags sgr0)"
	COLORS_ENABLED=true
}

function disable_colors() {
	unset DPKG_COLORS
	FMT_RED=""
	FMT_GREEN=""
	FMT_BOLD=""
	FMT_NF=""
	COLORS_ENABLED=false
}

if [[ -t 1 ]] || [[ "$FORCE_COLORS" == "true" ]]; then
	enable_colors
else
	disable_colors
fi

function without_colors() {
	if [[ "$COLORS_ENABLED" == "true" ]]; then
		disable_colors
		"$@"
		enable_colors
	else
		"$@"
	fi
}

function echo_error() {
	echo -e "${FMT_BOLD}${FMT_RED}Error: $*${FMT_NF}"
}

function echo_success() {
	echo -e "${FMT_BOLD}${FMT_GREEN}Success: $*${FMT_NF}"
}

function echo_bold() {
	echo -e "${FMT_BOLD}$*${FMT_NF}"
}

function die() {
	echo_error "$*"
	exit 1
}

function logmust() {
	echo Running: "$@"
	"$@" || die "failed command '$*'"
}

function check_platform() {
	if [[ "$DISABLE_PLATFORM_CHECK" == "true" ]]; then
		echo "WARNING: platform check disabled."
		return 0
	fi

	if ! command -v lsb_release >/dev/null ||
		[[ $(lsb_release -cs) != "bionic" ]]; then
		die "Script can only be ran on an ubuntu-bionic system."
	fi
	#
	# Sanity check to make sure this is not ran on a local developer system.
	#
	if ! curl "http://169.254.169.254/latest/meta-datas" \
		>/dev/null 2>&1; then
		die "Not running in AWS, are you sure you are on the" \
			"right system?"
	fi
	return 0
}

function check_valid_package() {
	local pkg="$1"

	check_env TOP
	echo "$pkg" | grep -q '/' && die "Package name should not contain '/'"
	[[ -d "$TOP/packages/$pkg" ]] || die "Unknown package '$pkg'."
}

function check_env() {
	local var val required

	required=true
	for var in "$@"; do
		if [[ "$var" == "--" ]]; then
			required=false
			continue
		fi

		val="${!var}"
		if $required && [[ -z "$val" ]]; then
			die "$var must be non-empty"
		fi
	done
	return 0
}

function check_git_ref() {
	local ref
	for ref in "$@"; do
		if ! git show-ref -q "$ref"; then
			die "git ref '$ref' not found"
		fi
	done
	return 0
}

function query_git_credentials() {
	if [[ -n "$PUSH_GIT_USER" ]] && [[ -n "$PUSH_GIT_PASSWORD" ]]; then
		return 0
	fi

	if [[ ! -t 1 ]]; then
		die "PUSH_GIT_USER and PUSH_GIT_PASSWORD environment" \
			"variables must be set to a user that has" \
			"push permissions for the target repository."
	fi

	echo "Please enter git credentials for pushing to repository."
	read -r -p "User: " PUSH_GIT_USER
	read -r -s -p "Password: " PUSH_GIT_PASSWORD
	echo ""
	export PUSH_GIT_USER
	export PUSH_GIT_PASSWORD
	return 0
}

function stage() {
	typeset func=$1
	typeset optional=${2:-false}

	check_env PACKAGE

	echo ""
	if type -t "$func" >/dev/null; then
		echo_bold "PACKAGE $PACKAGE: STAGE $func STARTED"
		logmust "$func"
		echo_bold "PACKAGE $PACKAGE: STAGE $func COMPLETED"
	elif $optional; then
		echo_bold "PACKAGE $PACKAGE: SKIPPING UNDEFINED STAGE $func"
	else
		die "Package $PACKAGE doesn't have $func() hook defined" \
			"in its config."
	fi
	echo ""
}

#
# This is the default function for the "fetch" stage.
#
function fetch() {
	logmust fetch_repo_from_git
}

function install_pkgs() {
	logmust sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

function read_package_list() {
	local file="$1"

	local pkg
	local line

	_RET_LIST=()

	while read -r line; do
		# trim whitespace
		pkg=$(echo "$line" | sed 's/^\s*//;s/\s*$//')
		[[ -z "$pkg" ]] && continue
		# ignore comments
		[[ ${pkg:0:1} == "#" ]] && continue
		check_valid_package "$pkg"
		_RET_LIST+=("$pkg")
	done <"$file" || die "Failed to read package list: $file"

	return 0
}

function install_shfmt() {
	if [[ ! -f /usr/local/bin/shfmt ]]; then
		logmust sudo wget -nv -O /usr/local/bin/shfmt \
			https://github.com/mvdan/sh/releases/download/v2.4.0/shfmt_v2.4.0_linux_amd64
		logmust sudo chmod +x /usr/local/bin/shfmt
	fi
	echo "shfmt version $(shfmt -version) is installed."
}

function install_kernel_headers() {
	determine_target_kernels
	check_env EXPLICIT_KERNEL_VERSIONS

	local kernel
	local headers_pkgs=""

	for kernel in $EXPLICIT_KERNEL_VERSIONS; do
		headers_pkgs="$headers_pkgs linux-headers-$kernel"
	done

	# shellcheck disable=SC2086
	logmust install_pkgs $headers_pkgs
}

function default_revision() {
	echo "delphix-$(date '+%Y.%m.%d.%H')"
}

#
# Check if the default settings are overriden in the environment.
# When building a single package, SINGLE_PACKAGE_XXX variables can be used
# to override defaults.
# When building multiple packages, prefix_XXX variables can be used
# to override defaults, where prefix is the package's name in CAPS,
# with - replaced by _.
# For upstream git url and branch we only check prefix_XXX variables since
# those settings really shouldn't need to be overriden.
#
function get_settings_from_env() {
	local prefix=$1
	local var

	prefix=$(echo "$PACKAGE" | tr - _ | tr '[:lower:]' '[:upper:]')
	[[ "$prefix" =~ ^[A-Z][A-Z0-9_]*$ ]] ||
		die "Failed to convert package name '$PACKAGE' to valid" \
			"prefix ($prefix)"
	echo "get_settings_from_env(): using prefix: ${prefix}_"

	var="${prefix}_GIT_URL"
	if [[ -n "${!var}" ]]; then
		PACKAGE_GIT_URL="${!var}"
		echo "PACKAGE_GIT_URL set to value of ${var}"
	elif [[ -n "$SINGLE_PACKAGE_GIT_URL" ]]; then
		PACKAGE_GIT_URL="$SINGLE_PACKAGE_GIT_URL"
		echo "PACKAGE_GIT_URL set to value of SINGLE_PACKAGE_GIT_URL"
	elif [[ -n "$DEFAULT_PACKAGE_GIT_URL" ]]; then
		PACKAGE_GIT_URL="$DEFAULT_PACKAGE_GIT_URL"
		echo "PACKAGE_GIT_URL set to value of DEFAULT_PACKAGE_GIT_URL"
	fi

	var="${prefix}_GIT_BRANCH"
	if [[ -n "${!var}" ]]; then
		PACKAGE_GIT_BRANCH="${!var}"
		echo "PACKAGE_GIT_BRANCH set to value of ${var}"
	elif [[ -n "$SINGLE_PACKAGE_GIT_BRANCH" ]]; then
		PACKAGE_GIT_BRANCH="$SINGLE_PACKAGE_GIT_BRANCH"
		echo "PACKAGE_GIT_BRANCH set to value of" \
			"SINGLE_PACKAGE_GIT_BRANCH"
	elif [[ -n "$DEFAULT_PACKAGE_GIT_BRANCH" ]]; then
		PACKAGE_GIT_BRANCH="$DEFAULT_PACKAGE_GIT_BRANCH"
		echo "PACKAGE_GIT_BRANCH set to value of" \
			"DEFAULT_PACKAGE_GIT_BRANCH"
	fi

	if [[ -z "$PACKAGE_GIT_BRANCH" ]]; then
		PACKAGE_GIT_BRANCH="$DEFAULT_GIT_BRANCH"
		echo "PACKAGE_GIT_BRANCH set to value of DEFAULT_GIT_BRANCH"
	fi

	var="${prefix}_VERSION"
	if [[ -n "${!var}" ]]; then
		PACKAGE_VERSION="${!var}"
		echo "PACKAGE_VERSION set to value of ${var}"
	elif [[ -n "$SINGLE_PACKAGE_VERSION" ]]; then
		PACKAGE_VERSION="$SINGLE_PACKAGE_VERSION"
		echo "PACKAGE_VERSION set to value of SINGLE_PACKAGE_VERSION"
	elif [[ -n "$DEFAULT_PACKAGE_VERSION" ]]; then
		PACKAGE_VERSION="$DEFAULT_PACKAGE_VERSION"
		echo "PACKAGE_VERSION set to value of DEFAULT_PACKAGE_VERSION"
	fi

	var="${prefix}_REVISION"
	if [[ -n "${!var}" ]]; then
		PACKAGE_REVISION="${!var}"
		echo "PACKAGE_REVISION set to value of ${var}"
	elif [[ -n "$SINGLE_PACKAGE_REVISION" ]]; then
		PACKAGE_REVISION="$SINGLE_PACKAGE_REVISION"
		echo "PACKAGE_REVISION set to value of SINGLE_PACKAGE_REVISION"
	elif [[ -n "$DEFAULT_PACKAGE_REVISION" ]]; then
		PACKAGE_REVISION="$DEFAULT_PACKAGE_REVISION"
		echo "PACKAGE_REVISION set to value of DEFAULT_PACKAGE_REVISION"
	fi

	if [[ -z "$PACKAGE_REVISION" ]]; then
		PACKAGE_REVISION="$DEFAULT_REVISION"
		echo "PACKAGE_REVISION set to value of DEFAULT_REVISION"
	fi

	export PACKAGE_GIT_URL
	export PACKAGE_GIT_BRANCH
	export PACKAGE_VERSION
	export PACKAGE_REVISION

	echo_bold "------------------------------------------------------------"
	echo_bold "PACKAGE_GIT_URL:      $PACKAGE_GIT_URL"
	echo_bold "PACKAGE_GIT_BRANCH:   $PACKAGE_GIT_BRANCH"
	echo_bold "PACKAGE_VERSION:      $PACKAGE_VERSION"
	echo_bold "PACKAGE_REVISION:     $PACKAGE_REVISION"
	echo_bold "------------------------------------------------------------"

	return 0
}

#
# Fetch package repository into $WORKDIR/repo
#
function fetch_repo_from_git() {
	check_env PACKAGE_GIT_URL PACKAGE_GIT_BRANCH

	logmust cd "$WORKDIR"
	logmust git clone --branch "$PACKAGE_GIT_BRANCH" "$PACKAGE_GIT_URL" \
		repo
	logmust cd "$WORKDIR/repo"
	logmust git checkout -b repo-HEAD HEAD
}

function generate_commit_message_from_dsc() {
	local dsc
	shopt -s failglob
	dsc=$(echo "$WORKDIR/source/$UPSTREAM_SOURCE_PACKAGE"*.dsc)
	shopt -u failglob

	rm -f "$WORKDIR/commit-message"
	grep -E '^Version:' "$dsc" >"$WORKDIR/commit-message"
	echo "" >>"$WORKDIR/commit-message"
	cat "$dsc" >>"$WORKDIR/commit-message"

	return 0
}

function update_upstream_from_source_package() {
	check_env PACKAGE_GIT_BRANCH UPSTREAM_SOURCE_PACKAGE

	#
	# Fetch the source package into source/
	#
	logmust mkdir "$WORKDIR/source"
	logmust cd "$WORKDIR/source"
	logmust apt-get source "$UPSTREAM_SOURCE_PACKAGE"

	#
	# Checkout the upstream branch from our repository, and delete all
	# files.
	#
	logmust cd "$WORKDIR/repo"
	logmust git checkout -b upstream-HEAD \
		"remotes/origin/$REPO_UPSTREAM_BRANCH"
	logmust git rm -qrf .
	logmust git clean -qfxd

	#
	# Deploy the files from the source package on top of our repo.
	#
	logmust cd "$WORKDIR"
	shopt -s dotglob failglob
	logmust mv source/"$UPSTREAM_SOURCE_PACKAGE"*/* repo/
	shopt -u dotglob failglob

	#
	# Check if there are any changes. If so then commit them, and put the
	# source package description as the commit message.
	#
	logmust cd "$WORKDIR/repo"
	logmust git add -f .
	if git diff --cached --quiet; then
		echo "NOTE: upstream for $PACKAGE is already up-to-date."
	else
		logmust generate_commit_message_from_dsc
		logmust git commit -F "$WORKDIR/commit-message"

		logmust touch "$WORKDIR/upstream-updated"
	fi

	logmust cd "$WORKDIR"
	return 0
}

function update_upstream_from_git() {
	check_env UPSTREAM_GIT_URL UPSTREAM_GIT_BRANCH
	logmust cd "$WORKDIR/repo"
	check_git_ref "remotes/origin/$REPO_UPSTREAM_BRANCH" repo-HEAD

	logmust git remote add upstream "$UPSTREAM_GIT_URL"
	logmust git fetch upstream "$UPSTREAM_GIT_BRANCH"

	if git diff --cached --quiet FETCH_HEAD \
		"remotes/origin/$REPO_UPSTREAM_BRANCH"; then
		echo "NOTE: upstream for $PACKAGE is already up-to-date."
	else
		logmust git checkout -q repo-HEAD
		#
		# Note we do --ff-only here which will fail if upstream has
		# been rebased. We always want this behaviour as a rebase
		# is not something that maintainers usually do and if they do
		# then we definitely want to be notified.
		#
		logmust git merge --no-edit --ff-only --no-stat FETCH_HEAD

		logmust touch "$WORKDIR/upstream-updated"
	fi

	logmust cd "$WORKDIR"
}

#
# Creates a new changelog entry for the package with the appropriate fields.
# If no changelog file exists, source package name can be passed in first arg.
#
function set_changelog() {
	check_env PACKAGE_VERSION PACKAGE_REVISION
	local src_package="${1:-$PACKAGE}"

	logmust export DEBEMAIL="Delphix Engineering <eng@delphix.com>"
	if [[ -f debian/changelog ]]; then
		# update existing changelog
		logmust dch -b -v "${PACKAGE_VERSION}-${PACKAGE_REVISION}" \
			"Automatically generated changelog entry."
	else
		# create new changelog
		logmust dch --create --package "$src_package" \
			-v "${PACKAGE_VERSION}-${PACKAGE_REVISION}" \
			"Automatically generated changelog entry."
	fi
}

function dpkg_buildpackage_default() {
	logmust cd "$WORKDIR/repo"
	logmust set_changelog
	logmust dpkg-buildpackage -b -us -uc
	logmust cd "$WORKDIR/"
	logmust mv ./*.deb artifacts/
}

#
# Store some metadata about what was this package built from. When running
# buildall.sh, build_info for all packages is ingested by the metapackage
# and installed into /etc/delphix-extra-build-info.
#
function store_git_info() {
	logmust pushd "$WORKDIR/repo"
	echo "Git hash: $(git rev-parse HEAD)" >"$WORKDIR/build_info" ||
		die "storing git info failed"
	echo "Git repo: $PACKAGE_GIT_URL" >>"$WORKDIR/build_info"
	echo "Git branch: $PACKAGE_GIT_BRANCH" >>"$WORKDIR/build_info"
	logmust popd
}

#
# Returns the default (usually latest) kernel version for a given platform.
# Result is placed into _RET.
#
function get_kernel_for_platform() {
	local platform="$1"

	#
	# We poll the linux-image-KVERS dependency of the default
	# linux-image-generic package since that is what we install in our
	# appliance. This is not necessarily the latest kernel version
	# available, but it is one that will match our appliance.
	#
	if [[ "$(apt-cache show --no-all-versions "linux-image-${platform}" \
		2>/dev/null | grep Depends)" =~ linux-image-([^,]*-${platform}) ]]; then
		_RET=${BASH_REMATCH[1]}
		return 0
	else
		die "failed to determine default kernel version for platform" \
			"'${platform}'"
	fi
}

#
# Determine explicitly which kernel versions to build modules for and store
# the value into EXPLICIT_KERNEL_VERSIONS, unless it is already set.
#
# We determine the target kernel versions based on the value passed for
# KERNEL_VERSIONS. Here is a list of accepted values for KERNEL_VERSIONS:
#  a) "default": to build for all supported platforms
#  b) "aws gcp ...": to build for the default kernel version of those platforms.
#  c) "4.15.0-1010-aws ...": to build for specific kernel versions
#  d) mix of b) and c)
#
function determine_target_kernels() {
	if [[ -n "$EXPLICIT_KERNEL_VERSIONS" ]]; then
		echo "Kernel versions to use to build modules:"
		echo "  $EXPLICIT_KERNEL_VERSIONS"
		return 0
	fi
	if [[ -z "$KERNEL_VERSIONS" ]]; then
		KERNEL_VERSIONS="default"
	fi

	local supported_platforms="generic aws gcp azure kvm"
	local kernel
	local platform

	if [[ "$KERNEL_VERSIONS" == default ]]; then
		echo "KERNEL_VERSIONS set to 'default', so selecting all" \
			"supported platforms"
		KERNEL_VERSIONS="$supported_platforms"
	fi

	for kernel in $KERNEL_VERSIONS; do
		for platform in $supported_platforms; do
			if [[ "$kernel" == "$platform" ]]; then
				logmust get_kernel_for_platform "$platform"
				kernel="$_RET"
				break
			fi
		done
		#
		# Check that the target kernel is valid
		#
		apt-cache show "linux-image-${kernel}" >/dev/null 2>&1 ||
			die "Invalid target kernel '$kernel'"

		EXPLICIT_KERNEL_VERSIONS="$EXPLICIT_KERNEL_VERSIONS $kernel"
	done

	echo "Kernel versions to use to build modules:"
	echo "  $EXPLICIT_KERNEL_VERSIONS"

	return 0
}
