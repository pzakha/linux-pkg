#!/bin/bash
# shellcheck disable=SC2034

DEFAULT_PACKAGE_GIT_URL="$BASE_GIT_URL/simple.git"
DEFAULT_PACKAGE_VERSION=1.0.0

function build() {
	logmust dpkg_buildpackage_default
	logmust store_git_info
}
