#!/bin/bash
#
# Copyright 2020 Delphix
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

DEFAULT_PACKAGE_GIT_URL="none"

function fetch() {
	# Nothing to do
	return
}

function build() {
	logmust fetch_kernel_from_artifactory "5.3.0-1022-azure" \
		"6.0.3.0/dx2/linux-modules-5.3.0-1022-azure_5.3.0-1022.dx2_amd64.deb"
}
