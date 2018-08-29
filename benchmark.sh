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

	rm -f tx_$iflog
	rm -f rx_$iflog
	while :
	do
		printf "%s: %s\n" "$(date +%s)" "$(cat /sys/class/net/$1/statistics/tx_bytes)" >> tx_$iflog
		printf "%s: %s\n" "$(date +%s)" "$(cat /sys/class/net/$1/statistics/rx_bytes)" >> rx_$iflog
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

	stdbuf -oL mpstat $1 | stdbuf -o0 awk '/all/{print 100-$13}' | while read l; do echo "$(date +%s): $l"; done  >> $cpulog
}

killtree() {
	pkill -TERM -P $1
	kill -9 $1
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
	echo " [destination IP] [network interface] [period] [count] [(optional): remote logs[y/N]]"
	exit
fi

sudo id # Just to acquire sudo

remoteport=''
remotelogging=$5

# if remote logging is enabled, trigger logging
if [ $remotelogging == 'y' ]
then
	echo "sending trigger for remote logging"
	remoteport=$(./nc -d $1 $rport)
	if [ -z "$remoteport" ]
	then
		echo "Failed to get remote port"
		remotelogging='n'
	fi
fi

log_arping $1 $4 $2 &
pid1=$!
printf "arping started with PID %s\n" "$pid1"
pstree -lp $pid1
log_ping $1 $4 &
pid2=$!
printf "ping started with PID %s\n" "$pid2"
pstree -lp $pid2
log_cpu $3 &
pid3=$!
printf "cpu logging started with PID %s\n" "$pid3"
pstree -lp $pid3
log_net $2 $3 &
pid4=$!
printf "network logging started with PID %s\n" "$pid4"
pstree -lp $pid4

echo "waiting for ping/arping to finish"
pstree -lp $$
wait $pid1
wait $pid2
echo "killing CPU logging"
killtree $pid3
echo "killing net logging"
killtree $pid4
pstree -lp $$

# terminate remote logging, fetch remote logs
if [ $remotelogging == 'y' ]
then
	echo "sending trigger to end remote logging"
	./nc -znv $1 $remoteport
	sleep 2
	./nc -d $1 $remoteport > r_tx_$iflog
	echo "Fetched r_tx log"
	sleep 2
	./nc -d $1 $remoteport > r_rx_$iflog
	echo "Fetched r_rx log"
	sleep 2
	./nc -d $1 $remoteport > r_$cpulog
	echo "Fetched r_cpu log"
fi

echo "parsing logs"
pingav=$(cat ping.log | tail -n1)
arpingav=$(cat arping.log | tail -n1)

rxbytes=$(cat rx_$iflog | cut -d" " -f 2 | sed -e 1b -e '$!d' | tac | paste -s -d- - | bc)
txbytes=$(cat tx_$iflog | cut -d" " -f 2 | sed -e 1b -e '$!d' | tac | paste -s -d- - | bc)
tbytes=$(expr $rxbytes + $txbytes)
duration=$(cat tx_$iflog | cut -d":" -f1 | sed -e 1b -e '$!d' | tac | paste -s -d- - | bc)
tspeed=$(expr $txbytes / $duration)
rspeed=$(expr $rxbytes / $duration)
speed=$(expr $tbytes / $duration)

count=$(cat cpu.log | wc -l)
cputot=$(cat cpu.log | cut -d' ' -f2 | paste -s -d+ - | bc | grep -o "^[0-9]*")
avcpu=$(expr $cputot / $count)

printf "ping: %s\narping: %s\nTx: %s\nRx: %s\nTot: %s\navCPU:%s\n" "$pingav" "$arpingav" "$tspeed" "$rspeed" "$speed" "$avcpu"

if [ $remotelogging == 'y' ]
then
	rxbytes=$(cat r_rx_$iflog | cut -d" " -f 2 | sed -e 1b -e '$!d' | tac | paste -s -d- - | bc)
	txbytes=$(cat r_tx_$iflog | cut -d" " -f 2 | sed -e 1b -e '$!d' | tac | paste -s -d- - | bc)
	tbytes=$(expr $rxbytes + $txbytes)
	duration=$(cat r_tx_$iflog | cut -d":" -f1 | sed -e 1b -e '$!d' | tac | paste -s -d- - | bc)
	tspeed=$(expr $txbytes / $duration)
	rspeed=$(expr $rxbytes / $duration)
	speed=$(expr $tbytes / $duration)

	count=$(cat r_cpu.log | wc -l)
	cputot=$(cat r_cpu.log | cut -d' ' -f2 | paste -s -d+ - | bc | grep -o "^[0-9]*")
	avcpu=$(expr $cputot / $count)
	printf "Remote stats:\nTx: %s\nRx: %s\nTot: %s\navCPU:%s\n" "$tspeed" "$rspeed" "$speed" "$avcpu"
fi



# generate timeseries for ping and arping
cat arping.log | sed -n -e 's/^\([0-9:]*\)\s.*time=\([0-9.]*\).*$/\1\2/p' > ts_arping.log
cat ping.log | sed -n -e 's/^\([0-9:]*\)\s.*time=\([0-9.]*\).*$/\1\2/p' > ts_ping.log
