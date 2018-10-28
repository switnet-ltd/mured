#!/bin/bash
# mured - *buntu 16.04 (LTS) based systems.
# SwITNet Ltd © - 2018, https://switnet.net/
# GPLv3 or later.

#Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 1
fi

docker_num=$(grep -nc docker /proc/1/cgroup)
check_docker() {
if [ $1 = 0 ]; then
	echo "Ok, this doesn't seems to be a docker container"
	else
	echo "This script won't work on a docker container, exiting..."
	exit
fi
}
check_docker $docker_num

if [ "$(dpkg-query -W -f='${Status}' redis-server 2>/dev/null | grep -c "ok")" == "1" ]; then
		echo "Redis is already installed, skipping..."
    else
		echo -e "\n---- Install Redis Server ----"
		apt -yqq install redis-server
fi
REDIS_INST=$(find /etc/redis -name redis* | cut -d "_" -f2 | grep -v redis | sed "s|.conf||" |  sort -r)
echo "Redis sufix:"
while [[ -z $RED_SUFIX ]]
do
echo "These have been already taken (avoid them):"
if [[ -z "$REDIS_INST" ]]; then
	echo " -> Seems there is no other custom instance present."
else
	echo $REDIS_INST
fi

read RED_SUFIX
if [[ ! -z $RED_SUFIX ]]; then
	echo "We'll use \"$RED_SUFIX\" "
else
	echo "Please enter a small sufix for this redis instance."
fi
done
RED_CONF_ORIG=/etc/redis/redis.conf
RED_CONF_ADD=/etc/redis/redis_$RED_SUFIX.conf
RED_SYS_ORIG=/lib/systemd/system/redis-server.service
RED_SYS_ADD=/lib/systemd/system/redis-server_$RED_SUFIX.service
RED_PID_ORIG=/var/run/redis/redis-server.pid
RED_PID_ADD=/var/run/redis/redis-server_$RED_SUFIX.pid
RED_LOG_ORIG=/var/log/redis/redis-server.log
RED_LOG_ADD=/var/log/redis/redis-server_$RED_SUFIX.log
RED_SCK_ORIG=/var/run/redis/redis.sock
RED_SCK_ADD=/var/run/redis/redis_$RED_SUFIX.sock
RED_VAR_ORIG=/var/lib/redis
RED_VAR_ADD=/var/lib/redis_$RED_SUFIX
PORT_BASE=$(grep -n "port" $(find /etc/redis/redis*.conf) | grep -v "[0-9]:#" | cut -d ":" -f3 | sort -r | cut -d " " -f2 | head -n 1)
sed_var_conf() {
	sed -i "$1 s|.*$2.*|$2 $3|" $4
	}
close_socket() {
if grep $1 $2 | grep -v "#"; then
	echo "disabling unixsocket"
	sed -i "s|$1|#$1|g" $2
else 
	echo "unixsocket is already disabled"
fi
}

echo "
What kind of connection should this redis instance use?
TCP = 1 || unixsocket = 2
"
while [[ $RED_CON != 1 && $RED_CON != 2 ]]
do
read RED_CON
if [ $RED_CON = 1 ]; then
	echo "We'll setup \"tcp\" connection"
	SET_RED=1
elif [ $RED_CON = 2 ]; then
	echo "We'll setup \"unixsocket\" connection."
else
	echo "Only \"1\" or \"2\" are valid responses."
fi
done

install -o redis -g redis -d $RED_VAR_ADD
cp -p $RED_CONF_ORIG $RED_CONF_ADD

PORT_NUM_LIN=$(grep -n "port" $RED_CONF_ADD | grep -v "[0-9]:#" | cut -d ":" -f1)
USOCK_NUM_LIN=$(grep -n "unixsocket " $RED_CONF_ADD | cut -d ":" -f1)
USOCK_PERM_LIN=$(grep -n "unixsocketperm" $RED_CONF_ADD | cut -d ":" -f1)

if [ "$PORT_BASE" = "0" ] && [ "$SET_RED" = "1" ]; then
	NEW_PORT=6379
	sed_var_conf $PORT_NUM_LIN port $NEW_PORT $RED_CONF_ADD
	close_socket unixsocket $RED_CONF_ADD
elif [ "$PORT_BASE" != "0" ] && [ "$SET_RED" = "1" ]; then
	NEW_PORT=$((PORT_BASE + 1))
	sed_var_conf $PORT_NUM_LIN port $NEW_PORT $RED_CONF_ADD
	close_socket unixsocket $RED_CONF_ADD
elif [ "$RED_CON" = "2" ]; then
	echo "Configuring redis unix socket"
	NEW_PORT=0
	sed -i "s|# unixsocket|\ \ unixsocket|g" $RED_CONF_ADD
	sed_var_conf $PORT_NUM_LIN port $NEW_PORT $RED_CONF_ADD
	sed_var_conf $USOCK_PERM_LIN unixsocketperm 770 $RED_CONF_ADD
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

echo "
New redis instance ready!
"
echo "-> This redis instance is using:"


if [ $RED_CON = 1 ]; then
	echo "	* Port: $NEW_PORT
	* Socket: (disabled)"
elif [ $RED_CON = 2 ]; then
	echo "	* Port: (disabled)
	* Socket: $RED_SCK_ADD"
else
	echo "Invalid option"
	echo "Please report to: https://github.com/switnet-ltd/mured"
	exit
fi

echo "-> Check further details of new redis instance at:"
echo "	$RED_CONF_ADD
	$RED_LOG_ADD"
