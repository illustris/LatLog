#!/bin/bash

source config.sh

randpath() {
	hsh=$(date +%s%N | md5sum | grep -o "[a-f0-9]*")
	fullpath=$(printf "/dev/shm/latlog/%s\n" "$hsh")
	mkdir -p $fullpath
	echo $fullpath
}

log_net(){
		if [ $# -lt 2 ]
	then
		echo -n "Usage: "
		echo -n $0
		echo " [iface] [period] [path]"
		exit
	fi

	rm -f $3/remote_tx_$iflog
	rm -f $3/remote_rx_$iflog
	while :
	do
		printf "%s: %s\n" "$(date +%s)" "$(cat /sys/class/net/$1/statistics/tx_bytes)" >> $3/remote_tx_$iflog
		printf "%s: %s\n" "$(date +%s)" "$(cat /sys/class/net/$1/statistics/rx_bytes)" >> $3/remote_rx_$iflog
		sleep $2
	done
}

log_cpu(){
	if [ $# -lt 1 ]
	then
		echo -n "Usage: "
		echo -n $0
		echo " [period] [path]"
		exit
	fi

	rm -f $2/remote_$cpulog

	stdbuf -oL mpstat $1 | stdbuf -o0 awk '/all/{print 100-$NF}' | while read l; do echo "$(date +%s): $l"; done  >> $2/remote_$cpulog
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
	logpath=$(randpath)
	printf "Logging to %s\n" "$logpath"
	log_cpu $2 $logpath &
	pid1=$!
	printf "cpu logging started with PID %s\n" "$pid1"
	log_net $1 $2 $logpath &
	pid2=$!
	printf "network logging started with PID %s\n" "$pid2"

	pstree -lp $$

	# wait for second remote trigger
	echo "waiting for second remote trigger"
	cat /dev/null | nc -l -p $3

	killtree $pid1
	killtree $pid2
	echo "killed logging processes"
	pstree -lp $$

	# send logs
	echo "sending logs"
	cat $logpath/remote_tx_$iflog | nc -N -lp $3
	echo "remote_tx"
	cat $logpath/remote_rx_$iflog | nc -N -lp $3
	echo "remote_rx"
	cat $logpath/remote_$cpulog | nc -N -lp $3
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
	echo $listenport | nc -N -lp $rport
	printf "starting handler on port %s\n" "$listenport"
	logging_handler $1 $2 $listenport &
done
