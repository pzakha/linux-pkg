#!/bin/bash -ex
# shellcheck disable=SC2012

set -o pipefail

cd "$(git rev-parse --show-toplevel)"

# Expect: "zfs	https://github.com/delphix/zfs.git"
read -r -a fields <<<"$(./query-packages.sh single -o name,git-url zfs)"
[[ ${#fields[@]} -eq 2 ]]
[[ ${fields[0]} == 'zfs' ]]
[[ ${fields[1]} == 'https://github.com/delphix/zfs.git' ]]

# Expect: "https://github.com/delphix/zfs.git	zfs"
read -r -a fields <<<"$(./query-packages.sh single -o git-url,name zfs)"
[[ ${#fields[@]} -eq 2 ]]
[[ ${fields[0]} == 'https://github.com/delphix/zfs.git' ]]
[[ ${fields[1]} == 'zfs' ]]

# Expect: "zfs"
read -r -a fields <<<"$(./query-packages.sh single zfs)"
[[ ${#fields[@]} -eq 1 ]]
[[ ${fields[0]} == 'zfs' ]]

# Expect: "https://github.com/delphix/zfs.git"
read -r -a fields <<<"$(./query-packages.sh single -o git-url zfs)"
[[ ${#fields[@]} -eq 1 ]]
[[ ${fields[0]} == 'https://github.com/delphix/zfs.git' ]]

# Expect that "list all" outputs all directory names under packages/
diff <(ls -1 packages | sort) <(./query-packages.sh list all | sort)

# Expect that outputing git-url for all packages works and that the output
# length corresponds to the number of packages.
[[ $(ls -1 packages | wc -l) -eq $(./query-packages.sh list -o name,git-url all | wc -l) ]]

# Check that all package lists under package-lists\ can be loaded and that each
# line of the output of the command actually refers to a package.
find package-lists -name '*.pkgs' | while read -r list; do
	list="${list#package-lists/}"
	./query-packages.sh list "$list" | (
		cd packages
		xargs ls
	) >/dev/null
done

# Check that querying "appliance" list works
./query-packages.sh list appliance >/dev/null

# Check that the output from the appliance list contains zfs and
# delphix-platform packages. Note, we explicitly do not use grep -q here as it
# exits as soon as a match is found and that causes a broken pipe error as
# query-packages attempts to write more output.
./query-packages.sh list appliance | grep zfs >/dev/null
./query-packages.sh list appliance | grep delphix-platform >/dev/null
