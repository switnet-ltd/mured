#!/bin/bash
# mured - *buntu 16.04 (LTS) based systems.
# SwITNet Ltd © - 2018, https://switnet.net/
# GPLv3 or later.

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 1
fi

if [ "$(dpkg-query -W -f='${Status}' redis-server 2>/dev/null | grep -c "ok")" == "1" ]; then
		echo "Redis is installed, skipping..."
    else
		echo -e "\n---- Install Redis Server ----"
		apt -yqq install redis-server
fi

echo "Sufijo de 'redis':"
read RED_SUFIX
RED_CONF_ORIG=/etc/redis/redis.conf
RED_CONF_ADD=/etc/redis/redis$RED_SUFIX.conf
RED_SYS_ORIG=/lib/systemd/system/redis-server.service
RED_SYS_ADD=/lib/systemd/system/redis-server$RED_SUFIX.service
RED_PID_ORIG=/var/run/redis/redis-server.pid
RED_PID_ADD=/var/run/redis/redis-server$RED_SUFIX.pid
RED_LOG_ORIG=/var/log/redis/redis-server.log
RED_LOG_ADD=/var/log/redis/redis-server$RED_SUFIX.log
RED_SCK_ORIG=/var/run/redis/redis.sock
RED_SCK_ADD=/var/run/redis/redis$RED_SUFIX.sock
RED_VAR_ORIG=/var/lib/redis
RED_VAR_ADD=/var/lib/redis$RED_SUFIX

install -o redis -g redis -d $RED_VAR_ADD

#Checking variables phase
check_unixsocket() {
if grep ^[^#] $RED_CONF_ORIG | grep "unixsocket "
then
	echo "Redis configured with unixsocket"
	elif grep ^[^#] $RED_CONF_ORIG | grep "port"
	then
	echo "Redis configured using port: $(grep ^[^#] /etc/redis/redis.conf | grep port | cut -d " " -f2)"
	echo "Exiting... for this release we only support unixsocket connection."
	exit
else 
	echo "Not detected configuration"
fi
}

check_unixsocket

cp -p $RED_CONF_ORIG $RED_CONF_ADD
echo "-> Setting up conf file..."
sed -i "s|$RED_PID_ORIG|$RED_PID_ADD|" $RED_CONF_ADD
sed -i "s|$RED_SCK_ORIG|$RED_SCK_ADD|" $RED_CONF_ADD
sed -i "s|$RED_LOG_ORIG|$RED_LOG_ADD|" $RED_CONF_ADD
sed -i "s|$RED_VAR_ORIG|$RED_VAR_ADD|" $RED_CONF_ADD
#sed -i "s|dump.rdb|dump$RED_SUFIX.rdb|" $RED_CONF_ADD

cp $RED_SYS_ORIG $RED_SYS_ADD
echo "-> Setting up system service"
sed -i "s|$RED_CONF_ORIG|$RED_CONF_ADD|" $RED_SYS_ADD
sed -i "s|$RED_PID_ORIG|$RED_PID_ADD|" $RED_SYS_ADD
sed -i "s|$RED_VAR_ORIG|$RED_VAR_ADD|" $RED_SYS_ADD
sed -i "s|redis.service|redis$RED_SUFIX.service|" $RED_SYS_ADD

systemctl enable redis-server$RED_SUFIX.service
systemctl start redis-server$RED_SUFIX.service

echo "-> Check details of added redis at:"
echo $RED_CONF_ADD
echo $RED_LOG_ADD
echo $RED_SCK_ADD
