#!/usr/bin/env bats

load ../lib/test-common

function check_artifact_present() {
	test -f "$LINUX_PKG_ROOT/artifacts/$1"*.deb
}

@test "buildall: sanity test" {
	deploy_package_fixture test--alpha
	deploy_package_fixture test--beta
	deploy_package_fixture test--simple

	# Populate package lists for buildall.sh
	rm -rf "$TMP_PKG_LISTS"
	mkdir "$TMP_PKG_LISTS"
	touch "$TMP_PKG_LISTS/buildall.pkgs"
	touch "$TMP_PKG_LISTS/metapackage.pkgs"
	echo test--alpha >> "$TMP_PKG_LISTS/buildall.pkgs"
	echo test--beta >> "$TMP_PKG_LISTS/buildall.pkgs"
	echo test--simple >> "$TMP_PKG_LISTS/buildall.pkgs"
	export _PACKAGE_LISTS_DIR="$TMP_PKG_LISTS"

	echo ">> buildall.sh"
	buildall.sh

	check_artifact_present test-alpha-package
	check_artifact_present test-beta-package
	check_artifact_present test-simple-package
}
