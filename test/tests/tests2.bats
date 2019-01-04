#!/usr/bin/bats

load lib/test-common

@test "hello2" {
	[[ 3 -eq 3 ]]
}

@test "bye2" {
	echo "$LINUX_PKG_ROOT"
	[[ -z "$LINUX_PKG_ROOT" ]]
	echo test
}
