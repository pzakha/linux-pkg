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

DEFAULT_PACKAGE_GIT_URL="https://github.com/delphix/python-rtslib-fb.git"
DEFAULT_PACKAGE_VERSION="2.1.57"

UPSTREAM_SOURCE_PACKAGE=python-rtslib-fb

function prepare() {
	logmust install_pkgs \
		debhelper \
		dh-python \
		python-all \
		python-epydoc \
		python-setuptools \
		python3-all \
		python3-setuptools
}

function build() {
	logmust dpkg_buildpackage_default
	logmust store_git_info
}

function update_upstream() {
	logmust update_upstream_from_source_package
}
