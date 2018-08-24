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
	./load_cpu.sh "$@"
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
	ping -c $2 $1 | while read pong; do echo "$(date +%s%N): $pong"; done > ping.log
	cat ping.log | sed -n -e 's/.*rtt\s[a-z\/]*\s=\s[0-9.]*\/\([0-9.]*\).*/\1/p' >> ping.log
}

log_arping() {
	rm -f arping.log
	sudo arping -I $3 -c $2 $1 | while read pong; do echo "$(date +%s%N): $pong"; done > arping.log
	cat arping.log | sed -n -e 's/.*rtt\s[a-z\/-]*\s=\s[0-9.]*\/\([0-9.]*\)\/.*/\1/p' >> arping.log
}

if [ $# -lt 4 ]
then
	echo -n "Usage: "
	echo -n $0
	echo " [destination IP] [network interface] [period] [count]"
	exit
fi

log_cpu $3 &
log_net $2 $3 &
log_arping $1 $4 $2 &
pid1=$!
log_ping $1 $4 &
pid2=$!

wait $pid1
wait $pid2
pingav=$(cat ping.log | tail -n1)
arpingav=$(cat arping.log | tail -n1)
printf "ping: %s\narping: %s\n" "$pingav" "$arpingav"

terminate
echo "Something weird happened"