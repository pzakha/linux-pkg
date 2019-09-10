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
# shellcheck disable=SC2034

DEFAULT_PACKAGE_GIT_URL="https://github.com/delphix/bpftrace.git"
DEFAULT_PACKAGE_VERSION=1.0.0

UPSTREAM_GIT_URL="https://github.com/iovisor/bpftrace.git"
UPSTREAM_GIT_BRANCH="master"

function prepare() {
	if ! dpkg-query --show libbcc >/dev/null 2>&1; then
		echo_bold "libbcc not installed. Building package 'bcc' first."
		logmust "$TOP/buildpkg.sh" bcc
	fi

	logmust install_pkgs \
		bison \
		cmake \
		flex \
		g++ \
		git \
		libelf-dev \
		zlib1g-dev \
		libfl-dev \
		systemtap-sdt-dev \
		llvm-7-dev \
		llvm-7-runtime \
		libclang-7-dev \
		clang-7
}

function build() {
	logmust dpkg_buildpackage_default
}

function update_upstream() {
	logmust update_upstream_from_git
}
