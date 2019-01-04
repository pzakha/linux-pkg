#!/usr/bin/bats

load ../lib/test-common

@test "hello" {
	[[ 3 -eq 3 ]]
}

@test "deploy package" {
	deploy_package_fixture_default "-test-simple"
}
