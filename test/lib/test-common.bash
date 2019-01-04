#!/bin/bash -e

TEST_ROOT="$LINUX_PKG_ROOT/test"
TEST_TMP="$TEST_ROOT/tmp"
FIXTURES_DIR="$TEST_ROOT/fixtures"
DOCKER_GIT_DIR="$TEST_ROOT/docker/tmp/srv/git"

DOCKER_IMG=linux-pkg-nginx-img

# BASE_GIT_URL is meant to be useable in config.sh for test packages
export BASE_GIT_URL="https://localhost/git"
# prevent git from asking password when cloning from invalid url
export GIT_TERMINAL_PROMPT=0

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

# TODO: remove
function create_git_repo2() {
	local repo="$1"

	docker exec "$DOCKER_IMG" create-repo.sh "$repo"
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

	sudo rm -rf "$SRV_DIR/git/${repo}.git"
}

function cleanup_git_repos() {
	sudo rm -rf "$SRV_DIR"/git/*
}

function deploy_package_fixture_default() {
	local package="$1"

	mkdir "$LINUX_PKG_ROOT/packages/$package"

	deploy_package_config "$package" config.sh
	deploy_package_git_repo "$package" repo "$package"
}

function deploy_package_config() {
	local package="$1"
	local config_file="$2"

	local pkg_dir="$FIXTURES_DIR/packages/$package"
	[[ -f "$pkg_dir/$config_file" ]]
	[[ -d "$LINUX_PKG_ROOT/packages/$package" ]]

	cp "$pkg_dir/$config_file" "$LINUX_PKG_ROOT/packages/$package/config.sh"
}

function deploy_package_git_repo() {
	local package="$1"
	local repo_dir="$2"
	local repo_name="$3"

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
