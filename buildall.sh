#!/bin/bash -e
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

TOP="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
source "$TOP/lib/common.sh"

logmust check_platform

function usage() {
	[[ $# != 0 ]] && echo "$(basename "$0"): $*" >&2
	echo "Usage: $(basename "$0")"
	echo ""
	echo "  This script fetches and builds all the packages defined in"
	echo "  packages-lists/buildall.pkgs, as well as the metapackage."
	echo ""
	exit 2
}

[[ $# -eq 0 ]] || usage "takes no arguments."

logmust cd "$TOP"

if [[ -n "$BUILDER_CUSTOM_ENV" ]]; then
	echo "Parsing BUILDER_CUSTOM_ENV..."
	# TODO: add safety checks?
	eval "$BUILDER_CUSTOM_ENV"
fi

logmust make clean
logmust mkdir artifacts

[[ -n "$BUILD_ALL" ]] || BUILD_ALL="true"

build_flags=""
if [[ "$CHECKSTYLE" == "true" ]]; then
	build_flags="${build_flags} -c"
fi

#
# Auto-generate the default revision for all the packages. It will be the
# default used if the revision is not set explicitly anywhere else.
#
if [[ -z "$DEFAULT_REVISION" ]]; then
	logmust export DEFAULT_REVISION="$(default_revision)"
fi

#
# Default branch to checkout when fetching source code for packages. Note that
# this can be overriden by per-package settings.
#
if [[ -n "$DEFAULT_GIT_BRANCH" ]]; then
	logmust export DEFAULT_GIT_BRANCH=master
fi

#
# A list of target versions to build modules for can be passed in
# TARGET_PLATFORMS. Convert values like "default" or "aws" into actual kernel
# versions and store them into KERNEL_VERSIONS.
#
if [[ "$BUILD_ALL" == "true" ]]; then
	logmust determine_target_kernels
	export KERNEL_VERSIONS
fi

if [[ -n "$SINGLE_PACKAGE_NAME" ]]; then
	logmust check_valid_package "$SINGLE_PACKAGE_NAME"
	#
	# The following env parameters are propagated from jenkins:
	#   SINGLE_PACKAGE_GIT_URL, SINGLE_PACKAGE_GIT_BRANCH,
	#   SINGLE_PACKAGE_VERSION, SINGLE_PACKAGE_REVISION
	#
	# shellcheck disable=SC2086
	logmust ./buildpkg.sh $build_flags "$SINGLE_PACKAGE_NAME"
fi

if [[ "$BUILD_ALL" == "false" ]]; then
	[[ -n "$SINGLE_PACKAGE_NAME" ]] || die "SINGLE_PACKAGE_NAME must be" \
		"set when BUILD_ALL=false"
	logmust mv "packages/$SINGLE_PACKAGE_NAME/tmp/artifacts"/* artifacts/
else
	logmust read_package_list "$TOP/package-lists/buildall.pkgs"
	PACKAGES=("${_RET_LIST[@]}")

	#
	# unset all the single package env variables, otherwise they'd get
	# applied to every package built.
	#
	unset SINGLE_PACKAGE_GIT_URL
	unset SINGLE_PACKAGE_GIT_BRANCH
	unset SINGLE_PACKAGE_VERSION
	unset SINGLE_PACKAGE_REVISION

	for pkg in "${PACKAGES[@]}"; do
		logmust check_valid_package "$pkg"
		# Skip if it was already build above
		[[ "$pkg" == "$SINGLE_PACKAGE_NAME" ]] && continue
		# shellcheck disable=SC2086
		logmust ./buildpkg.sh $build_flags "$pkg"
	done

	logmust pushd metapackage
	export METAPACKAGE_VERSION="1.0.0-$DEFAULT_REVISION"
	logmust make deb
	logmust popd
	logmust mv metapackage/artifacts/* artifacts/

	for pkg in "${PACKAGES[@]}"; do
		logmust mv "packages/$pkg/tmp/artifacts"/* artifacts/
	done
	logmust cp metapackage/etc/delphix-extra-build-info artifacts/build-info
fi

echo_success "Packages have been built successfully."
