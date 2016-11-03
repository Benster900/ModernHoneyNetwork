#!/bin/bash

set -x
set -e

read -p "Add HTTPS to MHN core services[y/n]: " answer

if [[ $answer = n ]] ; then
   exit 1
fi

read -p "Select a cert type: \n
Let's Encrypt cert(L) \n
Custom cert with openssl(O) \n
Enter option [L/O]: " certType

read -p "Enter a domain to create a cert for: " domain


if [[ $certType = L ]] ; then
  cd /usr/local/sbin
  sudo wget https://dl.eff.org/certbot-auto
  sudo chmod a+x /usr/local/sbin/certbot-auto

  mv /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.bak
  rm -rf /etc/nginx/sites-enabled/*
echo 'server {
      listen 80;

      root /usr/share/nginx/html;

      location ~ /.well-known {
              allow all;
      }

}
' | tee /etc/nginx/sites-enabled/letsencrypt
  service nginx restart

  openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
  certbot-auto certonly -a webroot --webroot-path=/usr/share/nginx/html -d $domain -d www.$domain

  ########################## setup mhn via http ##########################
  echo 'server {
      listen       80;
      server_name  _;

      location / {
          try_files $uri @mhnserver;
      }

      root /opt/mhn/server;

      location @mhnserver {
        include uwsgi_params;
        uwsgi_pass unix:/tmp/uwsgi.sock;
      }

      location  /static {
        alias /opt/mhn/server/mhn/static;
      }
  }
  ' > /etc/nginx/sites-enabled/mhn-http

  ########################## setup mhn via https ##########################
cat > /etc/nginx/sites-enabled/mhn-https << EOF
server {
    listen              443 ssl;
    server_name         $domain www.$domain;
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;
    ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_stapling on;
    ssl_stapling_verify on;
    add_header Strict-Transport-Security max-age=15768000;

    if (\$ssl_protocol = "") {
        rewrite ^ https://\$host\$request_uri? permanent;
    }

    location / {
        try_files \$uri @mhnserver;
    }

    root /opt/www;

    location @mhnserver {
      include uwsgi_params;
      uwsgi_pass unix:/tmp/uwsgi.sock;
    }

    location  /static {
      alias /opt/mhn/server/mhn/static;
    }
}
EOF



  ########################## Setup kibana via https ##########################
  sed -i 's/port: 5601/port: 5602/g' /opt/kibana/config/kibana.yml
  sed -i 's/host: "0.0.0.0"/host: "localhost"/g' /opt/kibana/config/kibana.yml
  supervisorctl restart kibana
cat > /etc/nginx/sites-enabled/kibana-https << EOF
server {
    listen 5601 ssl;

    server_name         $domain www.$domain;
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;
    ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_stapling on;
    ssl_stapling_verify on;
    add_header Strict-Transport-Security max-age=15768000;

    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/htpasswd.users;

    location / {
        proxy_pass http://localhost:5602;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

  # nginx restart
  service nginx restart

  # add auto-renew to crontab
  service cron start
  echo '30 2 * * 1 /usr/local/sbin/certbot-auto renew >> /var/log/le-renew.log
35 2 * * 1 /etc/init.d/nginx reload' >> /etc/crontab

else
  mkdir -p /etc/nginx/ssl
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt
  openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

  ########################## setup mhn via http ##########################
  cat > /etc/nginx/sites-available/mhn-http << EOF
server{
      listen       80;
      server_name  $domain www.$domain

      location / {
          try_files \$uri @mhnserver;
      }

      root /opt/mhn/server;

      location @mhnserver {
        include uwsgi_params;
        uwsgi_pass unix:/tmp/uwsgi.sock;
      }

      location  /static {
        alias /opt/mhn/server/mhn/static;
      }
  }
EOF

  ########################## setup mhn via https ##########################
  cat > /etc/nginx/sites-available/mhn-https << EOF
server {
      listen              443 ssl;
      server_name         $domain www.$domain;
      ssl_certificate /etc/nginx/ssl/nginx.crt;
      ssl_certificate_key /etc/nginx/ssl/nginx.key;

      ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
      ssl_prefer_server_ciphers on;
      ssl_dhparam /etc/ssl/certs/dhparam.pem;
      ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
      ssl_session_timeout 1d;
      ssl_session_cache shared:SSL:50m;
      ssl_stapling on;
      ssl_stapling_verify on;
      add_header Strict-Transport-Security max-age=15768000;

      if (\$ssl_protocol = "") {
          rewrite ^ https://\$host\$request_uri? permanent;
      }

      location / {
          try_files \$uri @mhnserver;
      }

      root /opt/www;

      location @mhnserver {
        include uwsgi_params;
        uwsgi_pass unix:/tmp/uwsgi.sock;
      }

      location  /static {
        alias /opt/mhn/server/mhn/static;
      }
  }
EOF


  ########################## setup mhn via https ##########################
  cat > /etc/nginx/sites-enabled/mhn-https << EOF
server {
    listen              443 ssl;
    server_name         $domain www.$domain;
    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;
    ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_stapling on;
    ssl_stapling_verify on;
    add_header Strict-Transport-Security max-age=15768000;

    if (\$ssl_protocol = "") {
        rewrite ^ https://\$host\$request_uri? permanent;
    }

    location / {
        try_files \$uri @mhnserver;
    }

    root /opt/www;

    location @mhnserver {
      include uwsgi_params;
      uwsgi_pass unix:/tmp/uwsgi.sock;
    }

    location  /static {
      alias /opt/mhn/server/mhn/static;
    }
  }
EOF



  ########################## Setup kibana via https ##########################
  sed -i 's/ort: 5601/ort: 5602/g' /opt/kibana/config/kibana.yml
  sed -i 's/host: "0.0.0.0"/host: "localhost"/g' /opt/kibana/config/kibana.yml
  supervisorctl restart kibana
  cat > /etc/nginx/sites-enabled/kibana-https << EOF
server {
    listen 5601 ssl;

    server_name         $domain www.$domain;
    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;
    ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_stapling on;
    ssl_stapling_verify on;
    add_header Strict-Transport-Security max-age=15768000;

    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/htpasswd.users;

    location / {
        proxy_pass http://localhost:5602;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
  }
EOF
    # restart nginx
    service nginx restart
fi
