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

	stdbuf -oL mpstat $1 | stdbuf -o0 awk '/all/{print 100-$NF}' | while read l; do echo "$(date +%s): $l"; done  >> $cpulog
}

killtree() {
	pkill -TERM -P $1 1>&2
	kill -9 $1 1>&2
}

log_ping() {
	rm -f ping.log 1>&2
	ping -c $2 $1 | while read pong; do echo "$(date +%s%N): $pong"; done > ping.log
	cat ping.log | sed -n -e 's/.*rtt\s[a-z\/]*\s=\s[0-9.]*\/\([0-9.]*\).*/\1/p' >> ping.log
}

log_arping() {
	rm -f arping.log 1>&2
	sudo arping -I $3 -c $2 $1 | while read pong; do echo "$(date +%s%N): $pong"; done > arping.log
	cat arping.log | sed -n -e 's/.*rtt\s[a-z\/-]*\s=\s[0-9.]*\/\([0-9.]*\)\/.*/\1/p' >> arping.log
}

run() {
	remoteport=''
	remotelogging=$5

	mkdir -p logs/$1 1>&2

	# if remote logging is enabled, trigger logging
	if [ $remotelogging == 'y' ]
	then
		printf "sending trigger to %s for logging on port %s\n" "$1" "$rport" 1>&2
		remoteport=$(LD_LIBRARY_PATH="$(pwd)/libs" ./nc -w 5 -d $1 $rport)
		if [ -z "$remoteport" ]
		then
			echo "Failed to get remote port" 1>&2
			remotelogging='n'
		fi
	fi

	log_arping $1 $4 $2 &
	pid1=$!
	printf "arping started with PID %s\n" "$pid1" 1>&2
	pstree -lp $pid1 1>&2
	log_ping $1 $4 &
	pid2=$!
	printf "ping started with PID %s\n" "$pid2" 1>&2
	pstree -lp $pid2 1>&2
	log_cpu $3 &
	pid3=$!
	printf "cpu logging started with PID %s\n" "$pid3" 1>&2
	pstree -lp $pid3 1>&2
	log_net $2 $3 &
	pid4=$!
	printf "network logging started with PID %s\n" "$pid4" 1>&2
	pstree -lp $pid4 1>&2

	echo "waiting for ping/arping to finish" 1>&2
	pstree -lp $$ 1>&2
	wait $pid1 1>&2
	wait $pid2 1>&2
	echo "killing CPU logging" 1>&2
	killtree $pid3
	echo "killing net logging" 1>&2
	killtree $pid4
	pstree -lp $$ 1>&2

	# terminate remote logging, fetch remote logs
	if [ $remotelogging == 'y' ]
	then
		echo "sending trigger to end remote logging" 1>&2
		LD_LIBRARY_PATH="$(pwd)/libs" ./nc -zv $1 $remoteport
		sleep 2
		LD_LIBRARY_PATH="$(pwd)/libs" ./nc -d $1 $remoteport > r_tx_$iflog
		echo "Fetched r_tx log" 1>&2
		sleep 2
		LD_LIBRARY_PATH="$(pwd)/libs" ./nc -d $1 $remoteport > r_rx_$iflog
		echo "Fetched r_rx log" 1>&2
		sleep 2
		LD_LIBRARY_PATH="$(pwd)/libs" ./nc -d $1 $remoteport > r_$cpulog
		echo "Fetched r_cpu log" 1>&2
	fi

	echo "parsing logs" 1>&2
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

	fname=$(date +%s)
	printf '{"timestamp":%s,"src_host":"%s","src_service":"%s","dst_host":"%s","dst_service":"%s","ping":%s,"arping":%f,"tbytes":%s,"rbytes":%s,"total_bytes":%s,"cpu":%s' "$(date +%s)" "$(hostname -f)" "$7" "$1" "$6" "$pingav" "$arpingav" "$tspeed" "$rspeed" "$speed" "$avcpu" | sed 's/:,/: null,/g' | tee logs/$1/$fname.log

	if [ $remotelogging == 'y' ]
	then
		r_rxbytes=$(cat r_rx_$iflog | cut -d" " -f 2 | sed -e 1b -e '$!d' | tac | paste -s -d- - | bc)
		r_txbytes=$(cat r_tx_$iflog | cut -d" " -f 2 | sed -e 1b -e '$!d' | tac | paste -s -d- - | bc)
		r_tbytes=$(expr $r_rxbytes + $r_txbytes)
		r_duration=$(cat r_tx_$iflog | cut -d":" -f1 | sed -e 1b -e '$!d' | tac | paste -s -d- - | bc)
		r_tspeed=$(expr $r_txbytes / $r_duration)
		r_rspeed=$(expr $r_rxbytes / $r_duration)
		r_speed=$(expr $r_tbytes / $r_duration)

		r_count=$(cat r_cpu.log | wc -l)
		r_cputot=$(cat r_cpu.log | cut -d' ' -f2 | paste -s -d+ - | bc | grep -o "^[0-9]*")
		r_avcpu=$(expr $r_cputot / $r_count)
		printf ',"r_tbytes":%s,"r_rbytes":%s,"r_total_bytes":%s,"r_cpu":%s' "$r_tspeed" "$r_rspeed" "$r_speed" "$r_avcpu" | sed 's/:,/: null,/g' | tee -a logs/$1/$fname.log
	else
		printf ',"r_tbytes":null,"r_rbytes":null,"r_total_bytes":null,"r_cpu":null' | tee -a logs/$1/$fname.log
	fi

	echo "}" | tee -a logs/$1/$fname.log



	# generate timeseries for ping and arping
	cat arping.log | sed -n -e 's/^\([0-9:]*\)\s.*time=\([0-9.]*\).*$/\1\2/p' > ts_arping.log
	cat ping.log | sed -n -e 's/^\([0-9:]*\)\s.*time=\([0-9.]*\).*$/\1\2/p' > ts_ping.log
}

if [ $# -lt 4 ]
then
	echo -n "Usage: "
	echo -n $0
	echo " [host list file] [network interface] [period] [count] [remote logs[y/sN]]"
	exit
fi

sudo echo -n "" # Just to acquire sudo
self_ty=$(cat $1 | grep $(hostname -f) | grep -Eo "\w*$")
self_host=$(cat $1 | grep $(hostname -f) | grep -Eo "^[a-z0-9.-_]*")
shuf $1 | while read -r rem ty
do
	if [ "$rem" != "$self_host" ]
	then
		run $rem $2 $3 $4 $5 $ty $self_ty
	fi
done


#dimension : src_host, src_service, dst_host, dst_service, arping, ping, timestamp
#metric : ping, arping, tbytes, rbytes, total_bytes, cpu, r_tbytes, r_rbytes, r_total_bytes, r_cpu
