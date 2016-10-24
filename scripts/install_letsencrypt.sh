#!/bin/bash
#Author: Ben Bornholm

set -e
set -x

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

read -p "Setup a Let's Encrypt domain? [yn]: " answer
if [[ $answer = y ]];
then
echo 'server {
    listen       80;
    server_name  _;

    location / {
        try_files $uri @mhnserver;
    }

    root /opt/www;

    location @mhnserver {
      include uwsgi_params;
      uwsgi_pass unix:/tmp/uwsgi.sock;
    }

    location  /static {
      alias /opt/mhn/server/mhn/static;
    }

    location ~ /.well-known {
        allow all;
    }           
}
' | tee /etc/nginx/sites-enabled/default
	service nginx restart

	# Install let's encrypt
	cd /usr/local/sbin
	wget https://dl.eff.org/certbot-auto
	chmod a+x /usr/local/sbin/certbot-auto
	
	# Read in a domain
	read -p "Enter a domain to register: " domain
#	certbot-auto certonly -a webroot --webroot-path=/usr/share/nginx/html -d $domain -d www.$domain 
	certbot-auto certonly -d $domain -d www.$domain 
	ls -l /etc/letsencrypt/live/$domain


echo 'server {
    listen               80;
    listen              443 ssl;
    server_name         _;
    ssl_certificate     /etc/letsencrypt/live/'$domain'/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/'$domain'/privkey.pem;

    if ($ssl_protocol = "") {
        rewrite ^ https://$host$request_uri? permanent;
    }

    location / { 
        try_files $uri @mhnserver; 
    }

    root /opt/www;

    location ~ /.well-known {
    	allow all;
    }

    location @mhnserver {
      include uwsgi_params;
      uwsgi_pass unix:/tmp/uwsgi.sock;
    }

    location  /static {
      alias /opt/mhn/server/mhn/static;
    }
}
' | tee /etc/nginx/sites-enabled/mhn-https

service nginx restart


fi

