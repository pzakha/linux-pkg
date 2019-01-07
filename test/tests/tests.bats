#!/usr/bin/bats

load ../lib/test-common

@test "hello" {
	[[ 3 -eq 3 ]]
}

function teardown() {
	cleanup_git_repos
	cleanup_test_packages
}

@test "build simple package" {
	deploy_package_fixture_default test--simple
	"$LINUX_PKG_ROOT/buildpkg.sh" test--simple
	check_package_for_file test--simple /etc/dummy.txt
}
