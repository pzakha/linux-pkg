#!/bin/bash -ex

function create_git_repo() {
	local repo="$1"
	local dir="/srv/git/${repo}.git"

	sudo rm -rf "$dir"
	sudo mkdir "$dir"
	cd "$dir"
	sudo git init --bare
	sudo git config --local --add http.receivepack true
	sudo git update-server-info
	sudo chown -R www-data:www-data "$dir"
	sudo chmod -R 754 "$dir"
}

sudo apt update
sudo apt install fcgiwrap nginx -y

# User: linux-pkg-test, pw: testpw
sudo cp git-server/htpasswd /etc/nginx/.htpasswd

sudo cp git-server/nginx-git.conf /etc/nginx/sites-available/
sudo cp git-server/git-http-backend.conf /etc/nginx/

sudo rm -f /etc/nginx/sites-enabled/*
sudo ln -s /etc/nginx/sites-available/nginx-git.conf \
	/etc/nginx/sites-enabled/nginx-git.conf

sudo openssl req \
    -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/ssl/private/linux-pkg.key \
    -out /etc/ssl/certs/linux-pkg.crt \
    -subj "/C=US/ST=California/L=San Francisco/O=Engineering/OU=Engineering/CN=localhost"

sudo mkdir -p /srv/git/

sudo systemctl restart nginx

create_git_repo test-repo
