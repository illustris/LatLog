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

	rm -f remote_tx_$iflog
	rm -f remote_rx_$iflog
	while :
	do
		printf "%s: %s\n" "$(date +%s)" "$(cat /sys/class/net/$1/statistics/tx_bytes)" >> remote_tx_$iflog
		printf "%s: %s\n" "$(date +%s)" "$(cat /sys/class/net/$1/statistics/rx_bytes)" >> remote_rx_$iflog
		sleep $2
	done
}

log_cpu(){
	if [ $# -lt 1 ]
	then
		echo -n "Usage: "
		echo -n $0
		echo " <period>"
		exit
	fi

	rm -f remote_$cpulog

	stdbuf -oL mpstat $1 | stdbuf -o0 awk '/all/{print 100-$13}' | while read l; do echo "$(date +%s): $l"; done  >> remote_$cpulog
}

killtree() {
	pkill -TERM -P $1
	kill -9 $1
}

checkport() {
	netstat -tulpn 2>/dev/null | sed -n -e 's/.*:\([0-9]\+\)\s.*/\1/p' | grep $1 | wc -c
}

getport() {
	used=1
	while [ $used -gt 0 ]
	do
		r=$RANDOM
		#echo $r
		port=$(expr $r + 32767)
		#port=22
		#echo $port
		used=$(checkport $port)
	done
	echo $port
}

logging_handler() {
	# start logging
	log_cpu $2 &
	pid1=$!
	printf "cpu logging started with PID %s\n" "$pid1"
	log_net $1 $2 &
	pid2=$!
	printf "network logging started with PID %s\n" "$pid2"

	pstree -lp $$

	# wait for second remote trigger
	echo "waiting for second remote trigger"
	cat /dev/null | ./nc -l -p $3

	killtree $pid1
	killtree $pid2
	echo "killed logging processes"
	pstree -lp $$

	# send logs
	echo "sending logs"
	cat remote_tx_$iflog | ./nc -N -lp $3
	echo "remote_tx"
	cat remote_rx_$iflog | ./nc -N -lp $3
	echo "remote_rx"
	cat remote_$cpulog | ./nc -N -lp $3
	echo "remote_cpu"
}

if [ $# -lt 2 ]
then
	echo -n "Usage: "
	echo -n $0
	echo " [iface] [period]"
	exit
fi

sudo id # Just to acquire sudo

while :
do
	# wait for first remote trigger
	echo "waiting for first remote trigger"
	listenport=$(getport)
	echo $listenport | ./nc -N -lp $rport
	printf "starting handler on port %s\n" "$listenport"
	logging_handler $1 $2 $listenport &
done
