#!/bin/bash -e

repo="$1"
dir="/srv/git/${repo}.git"

rm -rf "$dir"
mkdir "$dir"
cd "$dir"
git init --bare
git config --local http.receivepack true
git update-server-info
