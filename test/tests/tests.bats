#!/usr/bin/bats

load lib/test-common

@test "hello" {
	[[ 3 -eq 3 ]]
}

@test "bye" {
	[[ 4 -eq 4 ]]
}
