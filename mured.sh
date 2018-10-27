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
PORT_BASE=$(grep -r "port " $(ls /etc/redis/redis*.conf) | cut -d ":" -f2 | grep ^[^#] | sort -r | cut -d " " -f2 | head -n 1)

install -o redis -g redis -d $RED_VAR_ADD

echo "What kind of connection should this redis instance use?
TCP = 1 || unixsocket = 2"
while [[ $RED_CON != 1 && $RED_CON != 2 ]]
do
read RED_CON
if [ $RED_CON = 1 ]; then
echo "We'll setup tpc connection"
SET_RED=1
elif [ $RED_CON = 2 ]; then
echo "We'll setup unix connection."
	else
	echo "Only 1 or 2 are valid responses."
fi
done

cp -p $RED_CONF_ORIG $RED_CONF_ADD
PORT_NUM_LIN=$(grep -n "port" $RED_CONF_ADD | grep -v "[0-9]:#" | cut -d ":" -f1)
if [[ $PORT_BASE = 0 && $SET_RED = 1 ]]; then
	NEW_PORT=6379
	sed -i "$PORT_NUM_LIN s|.*port .*|port $NEW_PORT|" $RED_CONF_ADD
	elif [[ $PORT_BASE != 0 && $SET_RED = 1 ]]; then
		NEW_PORT=$((PORT_BASE + 1))
		sed -i "$PORT_NUM_LIN s|.*port .*|port $NEW_PORT|" $RED_CONF_ADD
	elif [ $RED_CON = 2 ]; then
		echo "Configuring redis unix socket"
		NEW_PORT=0
		sed -i "$PORT_NUM_LIN s|.*port .*|port $NEW_PORT|" $RED_CONF_ADD
	else
		echo "Invalid option"
		echo "Please report to: https://github.com/switnet-ltd/mured"
	exit
fi

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

echo "-> Check details of new redis instance at:"
echo $RED_CONF_ADD
echo $RED_LOG_ADD
echo $RED_SCK_ADD
