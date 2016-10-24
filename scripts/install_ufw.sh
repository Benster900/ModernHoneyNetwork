#!/bin/bash
#Author: Ben Bornholm

set -e
set -x

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

sed -i 's/IPV6=yes/IPV6=no/g' /etc/default/ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 10000/tcp
ufw allow 8181/tcp
ufw allow 3000/tcp
ufw allow 5601/tcp
ufw disable
ufw enable
