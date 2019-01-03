#!/bin/bash -e

# Make sure are current directory is the parent of this script
cd "${BASH_SOURCE%/*}"

sudo rm -rf tmp
mkdir tmp tmp/srv tmp/srv/git tmp/srv/archive tmp/aptly

#
# Create a self-signed certificate that is required to serve git through HTTPS.
#
openssl req \
	-x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout tmp/linux-pkg.key \
	-out tmp/linux-pkg.crt \
	-subj "/C=US/ST=California/L=San Francisco/O=Engineering/OU=Engineering/CN=localhost"

# Add the certificate we just created to our known certificates
sudo ln -sf "$PWD/tmp/linux-pkg.crt" /etc/ssl/certs/

# Cleanup previous images
docker stop linux-pkg-nginx-img >/dev/null 2>&1 || true
docker rm linux-pkg-nginx-img >/dev/null 2>&1 || true

docker build -t linux-pkg-nginx .

docker run -d -p 80:80 -p 443:443 --mount src="$(pwd)/tmp/srv",target=/srv,type=bind \
	--name linux-pkg-nginx-img linux-pkg-nginx
