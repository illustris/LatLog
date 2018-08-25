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

terminate() {
	kill -- -$(ps -o pgid= $$ | grep -o [0-9]*)
}

sudo id # Just to acquire sudo

# wait for first remote trigger
cat /dev/null | nc -lp $rport

# start logging
log_cpu $2 &
pid1=$!
log_net $1 $2 &
pid2=$!

# wait for second remote trigger
cat /dev/null | nc -l -p $rport

kill $pid1
kill $pid2

# send logs
cat remote_tx_$iflog | nc -lp $rport
cat remote_rx_$iflog | nc -lp $rport
cat remote_$cpulog | nc -lp $rport
