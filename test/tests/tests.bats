#!/usr/bin/env bats

load ../lib/test-common

@test "buildpkg: build simple package" {
	deploy_package_fixture test--simple
	buildpkg.sh test--simple
	check_package_file_present test--simple /etc/dummy.txt
}

@test "buildpkg: git branch" {
	deploy_package_fixture test--simple

	# Checkout test--simple locally for changes
	rm -rf "$TEST_TMP/repo"
	git clone "$DOCKER_GIT_DIR/test--simple.git" "$TEST_TMP/repo"
	cd "$TEST_TMP/repo"

	# Create branch1
	git checkout -b branch1 origin/master
	echo "Hello from branch1" > etc/branch1
	git add etc/branch1
	git commit -m 'branch1 commit'
	sudo git push origin HEAD:branch1

	# Create branch2
	git checkout -b branch2 origin/master
	echo "Hello from branch2" > etc/branch2
	git add etc/branch2
	git commit -m 'branch2 commit'
	sudo git push origin HEAD:branch2

	# Create branch3
	git checkout -b branch3 origin/master
	echo "Hello from branch3" > etc/branch3
	git add etc/branch3
	git commit -m 'branch3 commit'
	sudo git push origin HEAD:branch3

	# First build the package for the default branch and check that
	# /etc/branch1 is not there as a sanity check.
	echo ""
	echo ">> Building using defaults"
	buildpkg.sh test--simple
	check_package_file_absent test--simple /etc/branch1

	# Set DEFAULT_PACKAGE_GIT_BRANCH=branch1 in config.sh, rebuild the
	# package and check that /etc/branch1 is there.
	echo ""
	echo ">> Building when setting DEFAULT_PACKAGE_GIT_BRANCH"
	sed -i '/DEFAULT_PACKAGE_GIT_BRANCH/c\DEFAULT_PACKAGE_GIT_BRANCH=branch1' \
		"$LINUX_PKG_ROOT/packages/test--simple/config.sh"
	buildpkg.sh test--simple
	check_package_file_present test--simple /etc/branch1

	# Now test with "-b branch2".
	echo ""
	echo ">> Building when passing -b"
	buildpkg.sh -b branch2 test--simple
	check_package_file_present test--simple /etc/branch2
	check_package_file_absent test--simple /etc/branch1

	# Finally test setting git branch with the package-specific environment
	# variable.
	echo ""
	echo ">> Building when setting TEST__SIMPLE_GIT_BRANCH"
	export TEST__SIMPLE_GIT_BRANCH=branch3
	buildpkg.sh test--simple
	check_package_file_present test--simple /etc/branch3
	check_package_file_absent test--simple /etc/branch2
	check_package_file_absent test--simple /etc/branch1
}

@test "buildpkg: git url" {
	deploy_package_fixture test--simple

	# Create a few copies of the base repository
	sudo cp -r "$DOCKER_GIT_DIR/test--simple.git" \
		"$DOCKER_GIT_DIR/simple-alt1.git"
	sudo cp -r "$DOCKER_GIT_DIR/test--simple.git" \
		"$DOCKER_GIT_DIR/simple-alt2.git"

	# Customize simple-alt1.git
	rm -rf "$TEST_TMP/repo"
	git clone "$DOCKER_GIT_DIR/simple-alt1.git" "$TEST_TMP/repo"
	pushd "$TEST_TMP/repo"
	echo "Hello from simple-alt1" > etc/simple-alt1
	git add etc/simple-alt1
	git commit -m 'simple-alt1 commit'
	sudo git push origin HEAD:master
	popd

	# Customize simple-alt2.git
	rm -rf "$TEST_TMP/repo"
	git clone "$DOCKER_GIT_DIR/simple-alt2.git" "$TEST_TMP/repo"
	pushd "$TEST_TMP/repo"
	echo "Hello from simple-alt2" > etc/simple-alt2
	git add etc/simple-alt2
	git commit -m 'simple-alt2 commit'
	sudo git push origin HEAD:master
	popd

	# First build the package using the DEFAULT_PACKAGE_GIT_BRANCH value
	# that is currently in config.sh and check that /etc/simple-alt1 is
	# not there.
	echo ""
	echo ">> Building using defaults"
	buildpkg.sh test--simple
	check_package_file_absent test--simple /etc/simple-alt1

	# Now test "-g ..simple-alt1.git".
	echo ""
	echo ">> Building when passing -g"
	buildpkg.sh -g "$BASE_GIT_URL/simple-alt1.git" test--simple
	check_package_file_present test--simple /etc/simple-alt1

	# Finally test setting git url with the package-specific environment
	# variable.
	echo ""
	echo ">> Building when setting TEST__SIMPLE_GIT_URL"
	export TEST__SIMPLE_GIT_URL="$BASE_GIT_URL/simple-alt2.git"
	buildpkg.sh test--simple
	check_package_file_present test--simple /etc/simple-alt2
	check_package_file_absent test--simple /etc/simple-alt1
}

@test "buildall: sanity test" {
	# Override the default package-lists defined in linux-pkg
	export _PACKAGE_LISTS_DIR="$FIXTURES_DIR/pkg-lists/list1"

	buildall.sh
}
