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

if [ $# -lt 2 ]
then
	echo -n "Usage: "
	echo -n $0
	echo " [iface] [period]"
	exit
fi

sudo id # Just to acquire sudo

# wait for first remote trigger
echo "waiting for first remote trigger"
echo 65123 | ./nc -N -lp $rport

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
cat /dev/null | ./nc -l -p $rport

killtree $pid1
killtree $pid2
echo "killed logging processes"
pstree -lp $$

# send logs
echo "sending logs"
cat remote_tx_$iflog | ./nc -N -lp $rport
echo "remote_tx"
cat remote_rx_$iflog | ./nc -N -lp $rport
echo "remote_rx"
cat remote_$cpulog | ./nc -N -lp $rport
echo "remote_cpu"
