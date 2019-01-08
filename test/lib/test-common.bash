#!/bin/bash -e

TEST_ROOT="$LINUX_PKG_ROOT/test"
TEST_TMP="$TEST_ROOT/tmp"
FIXTURES_DIR="$TEST_ROOT/fixtures"
# shellcheck disable=SC2034
TMP_PKG_LISTS="$TEST_TMP/pkg-lists"

# Test git repositories should be copied to this directory. When setting up
# a test repository, this directory can be used to clone the repository from.
DOCKER_GIT_DIR="$TEST_ROOT/docker/tmp/srv/git"

# BASE_GIT_URL is meant to be useable in config.sh for test packages as it it
# an HTTPS URL.
export BASE_GIT_URL="https://localhost/git"
# prevent git from asking password when cloning from invalid url
export GIT_TERMINAL_PROMPT=0

function setup() {
	if [[ -f "$TEST_TMP/abort_tests" ]]; then
		skip
	fi
}

function teardown() {
	[[ -f "$TEST_TMP/abort_tests" ]] && return

	if [[ -n "$BATS_ERROR_STATUS" ]] && [[ -n "$STOP_ON_FAILURE" ]]; then
		touch "$TEST_TMP/abort_tests"
		echo "============================="
		echo "Skipping all remaining tests"
		echo "============================="
		return
	fi

	cleanup_git_repos
	cleanup_test_packages
}

#
# Can be called after building a linux-pkg package with buildpkg.
# This returns the path of the deb produced by the build.
# Function will fail if more than one deb is produced.
#
function get_package_deb() {
	local package="$1"

	local artifacts="$LINUX_PKG_ROOT/packages/$package/tmp/artifacts"

	# Check that this package was built
	[[ -d "$artifacts" ]]

	shopt -s failglob
	local debs=("$artifacts"/*.deb)
	shopt -u failglob

	# Check that there is only one deb
	[[ ${#debs[@]} -gt 0 ]]
	[[ ${#debs[@]} -eq 1 ]]

	echo "${debs[0]}"
}

#
# Can be called after running buildall.
# For a given Debian package, this returns its path in the artifacts directory.
# This function fails if several debs match the name provided.
#
function deb_path_in_artifacts() {
	local deb_name="$1"

	shopt -s failglob
	local debs=("$LINUX_PKG_ROOT/artifacts/$deb_name"*.deb)
	shopt -u failglob

	[[ ${#debs[@]} -eq 1 ]]

	echo "${debs[1]}"
}

function check_file_in_deb() {
	local deb_path="$1"
	local file="$2"

	#
	# dpkg-deb -c prints contents of archive in tar format.
	# The last argument is the absolute file path with root as './'.
	# Note that this check will fail if there is whitespace in $file.
	#
	set -o pipefail
	dpkg-deb -c "$deb_path" | awk '{print $NF}' | grep -qx ".$file"
	set +o pipefail
}

function check_file_not_in_deb() {
	local deb_path="$1"
	local file="$2"

	#
	# dpkg-deb -c prints contents of archive in tar format.
	# The last argument is the absolute file path with root as './'.
	# Note that this check will fail if there is whitespace in $file.
	#
	set -o pipefail
	dpkg-deb -c "$deb_path" | awk '{print $NF}' | grep -vqx ".$file"
	set +o pipefail
}

function get_deb_full_version() {
	local deb_path="$1"

	set -o pipefail
	dpkg-deb -I "$deb_path" | awk '/^ Version:/{ print $2 }'
	set +o pipefail
}

function check_deb_version() {
	local deb_path="$1"
	local version="$2"

	[[ $(get_deb_full_version "$deb_path") == "$version"-* ]]
}

function check_deb_revision() {
	local deb_path="$1"
	local revision="$2"

	[[ $(get_deb_full_version "$deb_path") == *-"$revision" ]]
}

#
# When a linux-pkg package is built, debs are produced and stored in the
# package's 'archive' directory.
#
# This function checks the contents of a produced deb and returns success if
# the specified file is either present or absent depending on $3. Note that
# there must only be one deb in the archive directory of the package.
#
# Param 1: Package name
# Param 2: Absolute path of file (must not contain white space)
# Param 3: "true" if file must be present or "false" if file must be absent
#
function check_package_file_common() {
	local package="$1"
	local file="$2"
	local present="$3"

	if [[ "$present" != true ]] && [[ "$present" != false ]]; then
		echo "ERROR: Argument 3 must be 'true' or 'false'" >&2
	fi

	local artifacts="$LINUX_PKG_ROOT/packages/$package/tmp/artifacts"

	# Check that this package was built
	[[ -d "$artifacts" ]]

	shopt -s failglob
	local debs
	debs=("$artifacts"/*.deb)
	shopt -u failglob

	# Check that there is only one deb
	[[ "${#debs[@]}" -eq 1 ]]

	#
	# dpkg-deb -c prints contents of archive in tar format.
	# The last argument is the absolute file path with root as './'.
	# Note that this will fail if there is whitespace in $file.
	#
	local result
	set -o pipefail
	if [[ "$present" == true ]]; then
		dpkg-deb -c "${debs[0]}" | awk '{print $NF}' | grep -qx ".$file"
		result=$?
	else
		dpkg-deb -c "${debs[0]}" | awk '{print $NF}' | grep -vqx ".$file"
		result=$?
	fi
	set +o pipefail

	return "$result"
}

function check_package_file_present() {
	check_package_file_common "$1" "$2" true
}

function check_package_file_absent() {
	check_package_file_common "$1" "$2" false
}

function create_git_repo() {
	local repo="$1"
	local dir="$DOCKER_GIT_DIR/${repo}.git"

	# Note: we need to create the repository as root because the nginx and
	# fastcgi daemons run as root in the container.
	#
	sudo mkdir "$dir"
	pushd "$dir"
	sudo git init --bare
	sudo git config --local http.receivepack true
	sudo git update-server-info
	popd
}

function destroy_git_repo() {
	local repo="$1"

	sudo rm -rf "$DOCKER_GIT_DIR/${repo}.git"
}

function cleanup_git_repos() {
	sudo rm -rf "$DOCKER_GIT_DIR"/*
}

function cleanup_test_packages() {
	sudo rm -rf "$LINUX_PKG_ROOT"/packages/test--*
}

#
# Adds a new package definition to linux-pkg based on information stored
# in DIR=fixtures/packages/<package>/:
# - A directory under linux-pkg/packages/ is created for <package>
# - The config.sh for <package> is copied from DIR/config.sh.
# - A new git repository is created from files in DIR/repo/.
#
function deploy_package_fixture() {
	local package="$1"

	mkdir "$LINUX_PKG_ROOT/packages/$package"

	deploy_package_config "$package"
	deploy_package_git_repo "$package"
}

#
# Copy config file from fixtures/packages/<package>/<config_file> to
# linux-pkg/packages/<package>/config.sh
#
function deploy_package_config() {
	local package="$1"
	local config_file="${2:-config.sh}"

	local pkg_dir="$FIXTURES_DIR/packages/$package"
	[[ -f "$pkg_dir/$config_file" ]]
	[[ -d "$LINUX_PKG_ROOT/packages/$package" ]]

	cp "$pkg_dir/$config_file" "$LINUX_PKG_ROOT/packages/$package/config.sh"
}

#
# Copy file from fixtures/packages/<package>/<repo_dir>/ into a new git repo
# at DOCKER_GIT_DIR/<repo_name>.git
#
# Repos in DOCKER_GIT_DIR are served through HTTPS by the nginx docker
# container and are accessible through BASE_GIT_URL/<repo_name>.git
#
function deploy_package_git_repo() {
	local package="$1"
	local repo_dir="${2:-repo}"
	local repo_name="${3:-$package}"

	local pkg_dir="$FIXTURES_DIR/packages/$package"
	[[ -d "$pkg_dir" ]]
	[[ -d "$pkg_dir/$repo_dir" ]]

	create_git_repo "$repo_name"
	sudo rm -rf "$TEST_TMP/repo"
	git clone "$DOCKER_GIT_DIR/${repo_name}.git" "$TEST_TMP/repo"

	pushd "$TEST_TMP/repo"
	shopt -s dotglob
	cp -r "$pkg_dir/$repo_dir"/* .
	git add -f .
	git commit -m 'initial commit'
	sudo git push origin HEAD:master
	popd

	sudo rm -rf "$TEST_TMP/repo"
}

function check_artifact_present() {
	local deb_name="$1"
	test -f "$LINUX_PKG_ROOT/artifacts/$deb_name"*.deb
}

function set_var_in_config() {
	local package="$1"
	local var="$2"
	local value="$3"

	[[ -f "$LINUX_PKG_ROOT/packages/$package/config.sh" ]]

	sed -i "/$var/c\\$var=$value" \
		"$LINUX_PKG_ROOT/packages/$package/config.sh"
}
