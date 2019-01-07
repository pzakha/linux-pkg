FROM alpine:latest

#
# We create the required directories.
# - /etc/ssl: holds the certificate and private keys used by HTTPS
RUN  \
    mkdir -p /etc/ssl/certs \
    mkdir -p /etc/ssl/private

#
# Copy nginx configuration into the container
#
COPY files/nginx/* /etc/nginx/

#
# Copy our generated SSL cerificates into the container
#
COPY tmp/linux-pkg.crt /etc/ssl/certs/
COPY tmp/linux-pkg.key /etc/ssl/private/

#
# We need the following packages:
# - nginx: this is our http(s) server
# - git-daemon: it provides the git-http-backend CGI script
# - fcgiwrap: this is how nginx does CGI
# - spawn-fcgi: used to launch fcgiwrap
# - bash: for easier debugging
#
RUN apk add --update nginx git-daemon fcgiwrap spawn-fcgi bash && \
    rm -rf /var/cache/apk/*

#
# Launch the applications:
# - launch fcgiwrap via spawn-fcgi in the background. Note that we pass -f to
#   fcgiwrap so that errors are logged in the default nginx error log.
# - launch nginx in the foreground as the main process.
#
CMD spawn-fcgi -s /run/fcgi.sock -- /usr/bin/fcgiwrap -f && \
    nginx -g "daemon off;"
