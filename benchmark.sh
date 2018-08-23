#!/bin/bash

source config.sh

log_net(){
		if [ $# -lt 2 ]
	then
		echo -n "Usage: "
		echo -n $0
		echo " <iface> <period>"
		exit
	fi

	rm -f $iflog
	while :
	do
		date +%s >> $iflog
		ifconfig $1 >> $iflog
		sleep $2
	done
}

load_net(){
	./load_network.sh "$@"
}

load_cpu(){
	corecount=$(cat /proc/cpuinfo | awk '/^processor/{print $3}' | wc -l)

	if [ $# -gt 0 ]
	then
		corecount=$1
	fi

	stress --cpu $corecount
}

log_cpu(){
	if [ $# -lt 1 ]
	then
		echo -n "Usage: "
		echo -n $0
		echo " <period>"
		exit
	fi

	rm -f $cpulog
	while :
	do
		date +%s >> $cpulog
		cat /proc/loadavg >> $cpulog
		sleep $1
	done
}

terminate() {
	kill -- -$(ps -o pgid= $$ | grep -o [0-9]*)
}

log_ping() {
	rm -f ping.log
	ping -c $2 $1 > ping.log
	cat ping.log | sed -n -e 's/^rtt\s[a-z\/]*\s=\s[0-9.]*\/\([0-9.]*\).*/\1/p' >> ping.log
}

log_arping() {
	rm -f arping.log
	sudo arping -c $2 $1 > arping.log
	cat arping.log | sed -n -e 's/^rtt\s[a-z\/]*\s=\s[0-9.]*\/\([0-9.]*\).*/\1/p' >> arping.log
}

log_cpu 1 &
log_net wlp2s0 1 &
log_ping localhost 5 && terminate &

wait
echo "Something weird happened"