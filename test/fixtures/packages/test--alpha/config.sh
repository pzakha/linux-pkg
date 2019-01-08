#!/bin/bash
# shellcheck disable=SC2034

DEFAULT_PACKAGE_GIT_URL="$BASE_GIT_URL/test--alpha.git"
#DEFAULT_PACKAGE_GIT_BRANCH
#DEFAULT_PACKAGE_VERSION
#DEFAULT_PACKAGE_REVISION

function prepare() {
	echo "alpha_prepare"
	#return 1
}

function build() {
	PACKAGE_VERSION=2.0.2
	logmust dpkg_buildpackage_default
	echo "Random info" >"$WORKDIR/build_info"
}
