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

cd "${BASH_SOURCE%/*}"

trap exit_hook EXIT

LINUX_PKG_ROOT=$(readlink -f ..)
export LINUX_PKG_ROOT

function exit_hook() {
	local ret=$?

	[[ -n "$_LINUX_PKG_DEBUG" ]] || cleanup

	return "$ret"
}

function cleanup() {
	local ret=$?

	docker stop linux-pkg-nginx-img >/dev/null 2>&1 || true
	docker rm linux-pkg-nginx-img >/dev/null 2>&1 || true
	sudo rm -f /etc/apt/sources.list.d/linux-pkg.list
	sudo rm -rf tmp docker/tmp ../packages/test--*

	return "$ret"
}

cleanup
mkdir tmp

echo "Launching nginx container ..."
docker/launch.sh >tmp/docker-launch.log 2>&1
echo "done."

echo "Running tests ..."
if [[ $# -eq 0 ]]; then
	bats tests
else
	bats "$@"
fi
