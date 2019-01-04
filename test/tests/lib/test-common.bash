#!/bin/bash -e

DOCKER_IMG=linux-pkg-nginx-img
TEST_ROOT="$LINUX_PKG_ROOT/test"
TEST_TMP="$TEST_ROOT/tmp"
TEST_WS="$TEST_TMP/ws"
SRV_DIR="$LINUX_PKG_ROOT/test/docker/tmp/srv"

# BASE_GIT_URL is meant to be useable in config.sh for test packages
export BASE_GIT_URL="https://localhost/git/"

function setup_test_ws() {
	rm -rf "$TEST_WS"
	mkdir "$TEST_WS"
}

#
# This function checks the contents of a deb artifact generated when building
# target package and returns success if the specified file is present.
#
# Param 1: package name
# Param 2: absolute path of file (must not contain white space)
#
function check_file_in_package_deb() {
	local package="$1"
	local file="$2"

	[[ -n "$file" ]]

	local artifacts="$LINUX_PKG_ROOT/packages/$package/tmp/artifacts"

	# Check that this package was built
	[[ -d "$artifacts" ]]

	shopt -s failglob
	local debs
	debs=("$artifacts"/*.deb)
	shopt -u failglob

	# Check that there is only one deb
	[[ "${#debs[@]}" -eq 1 ]]

	set -o pipefail
	#
	# dpkg-deb -c prints contents of archive in tar format.
	# The last argument is the absolute file path with root as './'.
	# Note that this will fail if there is whitespace in $file.
	#
	dpkg-deb -c "${debs[0]}" | awk '{print $NF}' | grep -qx ".$file"
	local result=$?
	set +o pipefail

	return "$result"
}

function create_git_repo() {
	local repo="$1"

	docker exec "$DOCKER_IMG" create-repo.sh "$repo"
}

function create_git_repo2() {
	local repo="$1"
	local dir="$SRV_DIR/git/${repo}.git"

	sudo mkdir "$dir"
	pushd "$dir"
	sudo git init --bare
	sudo git config --local http.receivepack true
	sudo git update-server-info
	popd "$dir"
}

function destroy_git_repo() {
	local repo="$1"

	sudo rm -rf "$SRV_DIR/git/${repo}.git"
}

function cleanup_git_repos() {
	sudo rm -rf "$SRV_DIR"/git/*
}

function get_repo_url() {
	local repo="$1"

	echo "https://localhost/git/${repo}.git"
}
