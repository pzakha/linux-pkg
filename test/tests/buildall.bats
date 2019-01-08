#!/usr/bin/env bats

load ../lib/test-common

function setup_buildall_pkg_lists() {
	rm -rf "$TMP_PKG_LISTS"
	mkdir "$TMP_PKG_LISTS"
	touch "$TMP_PKG_LISTS/buildall.pkgs"
	touch "$TMP_PKG_LISTS/metapackage.pkgs"

	for pkg in "$@"; do
		echo "$pkg"
	done >> "$TMP_PKG_LISTS/buildall.pkgs"

	# This tells buildall.sh to read package lists from dir TMP_PKG_LISTS
	# instead of the default linux-pkg/packages-lists/
	export _PACKAGE_LISTS_DIR="$TMP_PKG_LISTS"
}

@test "buildall: sanity test" {
	setup_buildall_pkg_lists test--alpha test--beta test--simple

	deploy_package_fixture test--alpha
	deploy_package_fixture test--beta
	deploy_package_fixture test--simple

	echo ">> Default build"
	buildall.sh

	deb_path_in_artifacts test-alpha-package
	deb_path_in_artifacts test-beta-package
	deb_path_in_artifacts test-simple-package
}

@test "buildall: change git branch" {
	setup_buildall_pkg_lists test--alpha test--beta

	deploy_package_fixture test--alpha
	deploy_package_fixture test--beta

	# Create branch1 for test--alpha
	rm -rf "$TEST_TMP/repo"
	git clone "$DOCKER_GIT_DIR/test--alpha.git" "$TEST_TMP/repo"
	pushd "$TEST_TMP/repo"
	git checkout -b branch1 origin/master
	echo "Hello from branch1" > etc/branch1
	git add etc/branch1
	git commit -m 'branch1 commit'
	sudo git push origin HEAD:branch1
	popd

	# Create branch1 for test--beta
	rm -rf "$TEST_TMP/repo"
	git clone "$DOCKER_GIT_DIR/test--beta.git" "$TEST_TMP/repo"
	pushd "$TEST_TMP/repo"
	git checkout -b branch1 origin/master
	echo "Hello from branch1" > etc/branch1
	git add etc/branch1
	git commit -m 'branch1 commit'
	sudo git push origin HEAD:branch1
	popd

	echo ">> Building with default branch unset"
	buildall.sh

	check_file_not_in_deb $(get_package_deb test--alpha) /etc/branch1
	check_file_not_in_deb $(get_package_deb test--beta) /etc/branch1

	echo ">> Building with default branch set to branch1"
	export DEFAULT_GIT_BRANCH=branch1
	buildall.sh

	check_file_in_deb $(get_package_deb test--alpha) /etc/branch1
	check_file_in_deb $(get_package_deb test--beta) /etc/branch1

	echo ">> Building with package overriding default branch"
	set_var_in_config test--alpha DEFAULT_PACKAGE_GIT_BRANCH master
	buildall.sh

	check_file_not_in_deb $(get_package_deb test--alpha) /etc/branch1
	check_file_in_deb $(get_package_deb test--beta) /etc/branch1

	echo ">> Building with branch overriden by package-specific variable"
	export TEST__BETA_GIT_BRANCH=master
	buildall.sh

	check_file_not_in_deb $(get_package_deb test--alpha) /etc/branch1
	check_file_not_in_deb $(get_package_deb test--alpha) /etc/branch1

}

@test "buildall: change version and revision" {
	setup_buildall_pkg_lists test--alpha test--beta test--simple

	deploy_package_fixture test--alpha
	deploy_package_fixture test--beta
	deploy_package_fixture test--simple

	export DEFAULT_REVISION=test-rev
	echo ">> Building with default revision set"
	buildall.sh

	check_deb_revision $(get_package_deb test--alpha) test-rev
	check_deb_revision $(get_package_deb test--beta) test-rev
	check_deb_revision $(get_package_deb test--simple) test-rev
	check_deb_version $(get_package_deb test--alpha) 2.0.2
	check_deb_version $(get_package_deb test--beta) 3.0.0
	check_deb_version $(get_package_deb test--simple) 1.0.0

	echo ">> Building after changing package defaults"
	set_var_in_config test--beta DEFAULT_PACKAGE_REVISION beta-rev
	set_var_in_config test--simple DEFAULT_PACKAGE_REVISION simple-rev
	# Note that version for test--alpha is set manually in its build()
	# hook, so this change should not have any effect.
	set_var_in_config test--alpha DEFAULT_PACKAGE_VERSION 1.2.3
	buildall.sh

	check_deb_revision $(get_package_deb test--alpha) test-rev
	check_deb_revision $(get_package_deb test--beta) beta-rev
	check_deb_revision $(get_package_deb test--simple) simple-rev
	check_deb_version $(get_package_deb test--alpha) 2.0.2
	check_deb_version $(get_package_deb test--beta) 3.0.0
	check_deb_version $(get_package_deb test--simple) 1.0.0

	echo ">> Building after changing package-specific variables"
	export TEST__ALPHA_REVISION=alpha-rev
	export TEST__BETA_REVISION=beta2-rev
	export TEST__SIMPLE_VERSION=3.3.3
	# Note that version for test--alpha is set manually in its build()
	# hook, so this change should not have any effect.
	export TEST__ALPHA_VERSION=2.3.4
	buildall.sh

	check_deb_revision $(get_package_deb test--alpha) alpha-rev
	check_deb_revision $(get_package_deb test--beta) beta2-rev
	check_deb_revision $(get_package_deb test--simple) simple-rev
	check_deb_version $(get_package_deb test--alpha) 2.0.2
	check_deb_version $(get_package_deb test--beta) 3.0.0
	check_deb_version $(get_package_deb test--simple) 3.3.3
}

@test "buildall: failure" {
	setup_buildall_pkg_lists test--alpha test--beta

	deploy_package_fixture test--alpha
	deploy_package_fixture test--beta

	local alpha_config="$LINUX_PKG_ROOT/packages/test--alpha/config.sh"
	local beta_config="$LINUX_PKG_ROOT/packages/test--beta/config.sh"

	echo ">> Test failure in prepare()"
	# Uncomment "return 1" in test--alpha's prepare() stage
	sed -i 's/#return 1/return 1/' "$alpha_config"
	! buildall.sh

	# revert config for test--alpha
	deploy_package_config test--alpha

	echo ">> Test failure in build()"
	# Uncomment "return 1" in test--beta's build() stage
	sed -i 's/#return 1/return 1/' "$beta_config"
	! buildall.sh
	# Check that it indeed failed while building test--beta
	[[ -f $LINUX_PKG_ROOT/packages/test--beta/tmp/building ]]

	# revert config for test--beta
	deploy_package_config test--beta

	echo ">> Sanity test that build still works"
	buildall.sh
}