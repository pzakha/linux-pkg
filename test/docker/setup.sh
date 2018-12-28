#!/bin/bash -e

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
sudo ln -sf $PWD/tmp/linux-pkg.crt /etc/ssl/certs/
