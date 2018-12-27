#!/bin/bash -ex

FILES=/files

function create_git_repo() {
	local repo="$1"
	local dir="/srv/git/${repo}.git"

	rm -rf "$dir"
	mkdir "$dir"
	cd "$dir"
	git init --bare
	git config --local --add http.receivepack true
	git update-server-info
	chown -R www-data:www-data "$dir"
	chmod -R 754 "$dir"
}

apt-get update
apt-get install git git-core fcgiwrap nginx -y

# User: linux-pkg-test, pw: testpw
# Created using htpasswd from package apache2-utils:
#   htpasswd -c /etc/nginx/.htpasswd linux-pkg-test
#
cp "$FILES/htpasswd" /etc/nginx/.htpasswd

cp "$FILES/nginx-git.conf" /etc/nginx/sites-available/
cp "$FILES/git-http-backend.conf" /etc/nginx/

rm -f /etc/nginx/sites-enabled/*
ln -s /etc/nginx/sites-available/nginx-git.conf \
	/etc/nginx/sites-enabled/nginx-git.conf

openssl req \
    -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/ssl/private/linux-pkg.key \
    -out /etc/ssl/certs/linux-pkg.crt \
    -subj "/C=US/ST=California/L=San Francisco/O=Engineering/OU=Engineering/CN=localhost"

mkdir -p /srv/git/

create_git_repo test-repo
