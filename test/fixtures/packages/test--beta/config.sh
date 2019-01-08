#!/bin/bash
# shellcheck disable=SC2034

DEFAULT_PACKAGE_GIT_URL="$BASE_GIT_URL/test--beta.git"
#DEFAULT_PACKAGE_GIT_BRANCH
DEFAULT_PACKAGE_VERSION=3.0.0
#DEFAULT_PACKAGE_REVISION

function prepare() {
	echo "beta_prepare"
}

function build() {
	#return 1
	logmust dpkg_buildpackage_default
}
