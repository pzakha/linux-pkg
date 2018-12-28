FROM alpine:latest

#
# We create the required directories.
# - /etc/ssl: holds the certificate and private keys used by HTTPS
RUN  \
    mkdir -p /etc/ssl/certs \
    mkdir -p /etc/ssl/private

#
# Copy nginx configuration and our scripts into the container
#
COPY files/nginx/* /etc/nginx/
COPY files/scripts/* /bin/

#
# Copy our generated SSL cerificates into the container
#
COPY tmp/linux-pkg.crt /etc/ssl/certs/
COPY tmp/linux-pkg.key /etc/ssl/private/

#
# We need the following packages:
# - nginx: this is our http(s) server
# - git-daemon: it provides the git-http-backend CGI script
# - git: it is used to create repositories inside the container
# - fcgiwrap: this is how nginx does CGI
# - spawn-fcgi: used to launch fcgiwrap
# - bash: for executing scripts and easier debugging
#
RUN apk add --update nginx git-daemon git fcgiwrap spawn-fcgi bash && \
    rm -rf /var/cache/apk/*

#
# Launch the applications:
# - launch fcgiwrap via spawn-fcgi in the background. Note that we need to
#   grant extra permissions the socket so that nginx can read and write to it.
#   We also pass -f to fcgiwrap so that errors are logged in the default nginx
#   error log.
# - launch nginx in the foreground as the main process.
#
CMD spawn-fcgi -s /run/fcgi.sock -M 0666 -- /usr/bin/fcgiwrap -f && \
    nginx -g "daemon off;"
