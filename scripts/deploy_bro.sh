#!/bin/bash

set -e
set -x

# Make sure script is running as root
if [ $# -ne 2 ]
    then
        echo "Wrong number of arguments supplied."
        echo "Usage: $0 <server_url> <deploy_key>."
        exit 1
fi

# Download the bro source code
cd /opt
git clone --recursive git://git.bro.org/bro
cd bro/

# Check to see if the system is centos or ubuntu
if [ -f /etc/debian_version ]; then
	# install dependencies
	apt-get install cmake make gcc g++ flex bison libpcap-dev libssl-dev python-dev swig zlib1g-dev
	
	# compile source
	./configure
	make
	make install

	#start cron service and add job
	service cron start
	echo "0-59/5 * * * * $PREFIX/bin/broctl cron" >> /etc/crontab

elif [ -f /etc/redhat-release ]; then
	# install dependencies
	yum install cmake make gcc gcc-c++ flex bison libpcap-devel openssl-devel python-devel swig zlib-devel
	
	# compile source
	./configure
	make
	make install

	# Config bro scripts
	interface=$(ip a | grep 2: | awk '{print $2}' | head -c -2)
	sed -i "s/interface=eth0/interface=$interface/g" /usr/local/bro/etc/node.cfg
	echo "::/0" >> /usr/local/bro/etc/networks.cfg
	echo "0.0.0.0/0" >> /usr/local/bro/etc/networks.cfg

	# Start cron service and add job
	systemctl start crond
	echo "0-59/5 * * * * /usr/local/bro/bin/broctl cron" >> /etc/crontab
	
fi

# install bro service and start it
/usr/local/bro/broctl install
/usr/local/bro/broctl start

# Add bro to path
export PATH=/usr/local/bro/bin:$PATH

