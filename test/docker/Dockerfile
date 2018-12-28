FROM alpine:latest

RUN  \
    mkdir -p /etc/ssl/certs \
    mkdir -p /etc/ssl/private \
    mkdir -p /srv/git

COPY files/.htpasswd /etc/nginx/
COPY files/nginx-git.conf /etc/nginx/
COPY files/nginx.conf /etc/nginx
COPY files/create-repo.sh /bin/create-repo

COPY tmp/linux-pkg.crt /etc/ssl/certs/
COPY tmp/linux-pkg.key /etc/ssl/private/

#
# We need the following packages:
# - git-daemon: it provides the git-http-backend CGI script
# - fcgiwrap: this is how nginx does CGI
# - spawn-fcgi: used to launch fcgiwrap
# - nginx: this is our server
# - bash: for executing scripts and easier debugging
#
RUN apk add --update nginx git-daemon fcgiwrap spawn-fcgi bash && \
    rm -rf /var/cache/apk/*

#
# launch fcgiwrap via spawn-fcgi; launch nginx in the foreground
# so the container doesn't die on us.
#
CMD spawn-fcgi -s /run/fcgi.sock -M 0666 -- /usr/bin/fcgiwrap -f && \
    nginx -g "daemon off;"
