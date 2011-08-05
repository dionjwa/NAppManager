#! /usr/bin/env sh
#This script runs on the server (don't call it manuall(.  It's called by sync.py
#It installs the tools needed by apps:
#nginx, redis, nodejs, mongodb

if uname -a | grep "Darwin"; 
then
	echo "This setup script doesn't work on a mac due to sed differences. You'll have to install manually"
	exit
fi

#Load the common properties
PROPS="etc/build.properties"
TEMPFILE=$(mktemp)
cat $PROPS|sed -re 's/"/"/'g|sed -re 's/=(.*)/="\1"/g'>$TEMPFILE
. $TEMPFILE
rm $TEMPFILE

#Create the folders
sudo mkdir -p $apps_dir/cache
sudo chown -R www-data $apps_dir
if [ "$server" != "localhost" ] #Don't modify the ssh port for local dev servers, as often you have VirtualBox redirecting ports
then
	sudo sed "s/^Port .*$/Port $ssh_port/" /etc/ssh/sshd_config >/tmp/sshd_config ; sudo cp /tmp/sshd_config /etc/ssh/sshd_config
fi

#Upstart config
sudo cp $appmanager_home/etc/appmanager.conf /etc/init/
apprun="    exec sudo -u root /usr/local/bin/node ${appmanager_home}/build/appmanager.js 2>&1 >> /var/log/appmanager.node.log"
# sudo sed "s#^.*appmanager.js.*\$#${apprun}#" /etc/init/appmanager.conf >/tmp/appmanager.conf ; sudo cp /tmp/appmanager.conf /etc/init/appmanager.conf
# sudo sed "s#^.*appmanager.js.*#${apprun}#" /etc/init/appmanager.conf >/tmp/appmanager.conf ; sudo cp /tmp/appmanager.conf /etc/init/appmanager.conf

echo "REDIS"

#Redis
if ! redis-server --version | grep $redis_version
then
	echo "Redis $redis_version not found, building and installing"
	cd /tmp
	sudo apt-get --assume-yes install zip unzip ruby openssl libopenssl-ruby curl build-essential
	if [ ! -f "/tmp/redis-$redis_version.tar.gz" ];
	then
		wget --directory-prefix=/tmp http://redis.googlecode.com/files/redis-$redis_version.tar.gz
	fi
	
	tar xzf redis-$redis_version.tar.gz
	cd redis-$redis_version
	make
	sudo make install
else
	echo "Redis $redis_version up to date"
fi

echo "appmanager_home=$appmanager_home"
sudo mkdir -p ${redis_db_dir}
sudo mkdir -p /etc/redis

sudo cp $appmanager_home/etc/redis/init.d/redis-server /etc/init.d/redis-server
sudo cp $appmanager_home/etc/redis/redis.conf /etc/redis/redis.conf
#Update the redis config, and start/restart
sudo sed "s#^dir .*\$#dir ${redis_db_dir}#" /etc/redis/redis.conf >/tmp/redis.conf ; sudo cp /tmp/redis.conf /etc/redis/redis.conf
sudo chmod 744 /etc/init.d/redis-server
sudo /etc/init.d/redis-server start

echo "done REDIS"

#Nginx
nginx_install_prefix=/usr/local/nginx
echo "Checking ${nginx_install_prefix}/sbin/nginx"
NGINX_OUT=$(${nginx_install_prefix}/sbin/nginx -v 2>&1)
sudo mkdir -p /var/log/nginx
if ! echo "$NGINX_OUT" | grep $nginx_version
then
	echo "Nginx $nginx_version not found, building and installing"
	#Prerequsites
	sudo apt-get --assume-yes install libpcre3 libpcre3-dev libpcrecpp0 libssl-dev zlib1g-dev build-essential
	#Download and build
	if [ ! -f "/tmp/nginx-$nginx_version.tar.gz" ];
	then
		wget --directory-prefix=/tmp "http://nginx.org/download/nginx-$nginx_version.tar.gz";
	fi
	cd /tmp
	tar xzvf nginx-$nginx_version.tar.gz
	cd nginx-$nginx_version
	./configure --with-http_ssl_module 
	make
	sudo make install
	#Copy a temporary config file
	sudo cp $appmanager_home/etc/nginx/init.d-ubuntu/nginx /etc/init.d/
	sudo chmod 744 /etc/init.d/nginx
	sudo /etc/init.d/nginx restart
	sudo update-rc.d nginx defaults
	
else
	echo "Nginx $nginx_version up to date"
fi

#nodejs
#Build node.js
if ! node --version | grep $nodejs_version
then
	echo "Nodejs $nodejs_version not found, building and installing"
	sudo apt-get --assume-yes install curl build-essential libc6-dev-i386 lib32stdc++6 git-core libssl-dev
	sudo ln -s /usr/lib32/libstdc++.so.6 /usr/lib32/libstdc++.so
	cd /tmp
	if [ ! -f "/tmp/node-v$nodejs_version.tar.gz" ];
	then
		wget --directory-prefix=/tmp "http://nodejs.org/dist/node-v$nodejs_version.tar.gz";
	fi
	tar xzvf node-v$nodejs_version.tar.gz
	cd node-v$nodejs_version
	./configure && make && sudo make install
	
	if grep "NODE_PATH" /etc/environment;
	then
		sudo sed "s/^NODE_PATH.*$/NODE_PATH=\/usr\/local\/lib\/node_modules/" /etc/environment >/tmp/environment ; sudo cp /tmp/environment /etc/environment
	else
		echo "NODE_PATH=/usr/local/lib/node_modules" | sudo tee -a /etc/environment > /dev/null
	fi
	 
	echo "This has to be done manually to install npm:"
	echo "curl http://npmjs.org/install.sh >install.sh"
	echo "sudo sh install.sh"
	echo "sudo npm install redis connect everyauth -g"
else
	echo "nodejs $nodejs_version up to date"
fi

#MongoDB.  Comment out if you don't want it.
# if [ ! -f /usr/bin/mongod ]
# then
# 	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
# 	sudo sed "s#^.*10gen.^#deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen#" /etc/apt/sources.list >/tmp/sources.list ; sudo cp /tmp/sources.list /etc/apt/sources.list
# 	sudo apt-get update
# 	sudo apt-get install mongodb-10gen
# else
# 	echo "MongoDB installed"
# fi

