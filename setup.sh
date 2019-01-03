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

TOP="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$TOP/lib/common.sh"

logmust check_running_system
logmust sudo apt-get update

#
# - aptly and docker.io are used by the test framework
# - bats is the test framework
# - debhelper is used to build most Debian packages. It is required by
#   the dpkg_buildpackage_default() command.
# - devscripts provides dch, which is used to automatically generate and update
#   changelog entries. It is required by the dpkg_buildpackage_default()
#   command.
# - git is used to fetch the source code for packages
# - shellcheck and shfmt are used by make check for checkstyle
#
logmust install_pkgs \
	aptly \
	bats \
	docker.io \
	debhelper \
	devscripts \
	git \
	shellcheck

logmust install_shfmt

logmust git config --global user.email "eng@delphix.com"
logmust git config --global user.name "Delphix Engineering"
