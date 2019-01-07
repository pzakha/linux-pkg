#!/bin/bash -e

# Make sure are current directory is the parent of this script
cd "${BASH_SOURCE%/*}"

docker stop linux-pkg-nginx-img >/dev/null 2>&1 || true
docker rm linux-pkg-nginx-img >/dev/null 2>&1 || true

sudo rm -rf tmp
