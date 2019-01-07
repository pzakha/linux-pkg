#!/bin/bash -e

# Make sure are current directory is the parent of this script
cd "${BASH_SOURCE%/*}"

mkdir -p tmp/srv/git

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

docker build -t linux-pkg-nginx .

docker run -d -p 443:443 --mount src="$(pwd)/tmp/srv",target=/srv,type=bind \
	--name linux-pkg-nginx-img linux-pkg-nginx

# Check that the container is healthy
# TODO: make this more reliable
sleep 1
if [[ $(docker inspect --format '{{.State.Running}}' \
	linux-pkg-nginx-img) != true ]]; then
	echo "ERROR: Container is not running. Docker logs:" >&2
	docker logs linux-pkg-nginx-img >&2
	exit 1
fi
