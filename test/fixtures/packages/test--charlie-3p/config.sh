#!/bin/bash
# shellcheck disable=SC2034

DEFAULT_PACKAGE_GIT_URL="$BASE_GIT_URL/test--charlie-3p.git"
#DEFAULT_PACKAGE_GIT_BRANCH
#DEFAULT_PACKAGE_VERSION
#DEFAULT_PACKAGE_REVISION

UPSTREAM_SOURCE_PACKAGE=test-charlie-src

function prepare() {
	echo "charlie_prepare"
}

function build() {
	PACKAGE_VERSION="cat $WORKDIR/repo/VERSION"
	logmust dpkg_buildpackage_default
	logmust store_git_info
}

function update_upstream() {
	logmust update_upstream_from_source_package
}
