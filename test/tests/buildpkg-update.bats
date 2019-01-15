#!/usr/bin/env bats

#
# Testing functionality of builpkg.sh -u
#

load ../lib/test-common

@test "buildpkg -i" {
	# Create source package and publish to local package repository
	src_pkg_copy_fixture test--charlie-3p
	pkg_archive_create
	src_pkg_build_and_deploy
	pkg_archive_publish

	# Deploy linux-pkg package definition
	mkdir "$LINUX_PKG_ROOT/packages/test--charlie-3p"
	deploy_package_config test--charlie-3p

	echo ">> Initializing package"
	buildpkg.sh -i test--charlie-3p
}
