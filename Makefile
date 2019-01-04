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

ALL_PACKAGES = $(shell find packages -maxdepth 1 -mindepth 1 -exec basename {} \;)
SHELL_FILES = $(shell find . -type f -name '*.sh' -o -name '*.bash')

.PHONY: \
	clean \
	shellcheck \
	shfmtcheck \
	$(ALL_PACKAGES)

all: setup
	./buildall.sh

$(ALL_PACKAGES): setup
	./buildpkg.sh $@

setup:
	./setup.sh

test: clean setup check
	test/run-tests.sh

clean:
	@sudo rm -rf test/tmp
	@sudo rm -rf test/docker/tmp
	@sudo rm -rf packages/-test-*
	@sudo rm -rf packages/*/tmp
	@rm -rf artifacts
	@(cd metapackage && make clean)
	@rm -f *.buildinfo *.changes *.deb
	@rm -rf update-status

shellcheck:
	shellcheck --exclude=SC1090,SC1091 \
		$$(find . -type f -name '*.sh' -o -name '*.bash')

shfmtcheck:
	shfmt -d $$(find . -type f -name '*.sh' -o -name '*.bash')

check: shellcheck shfmtcheck
