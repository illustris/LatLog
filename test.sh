#!/bin/bash

log_net(){
	./log_network.sh "$@"
}

load_net(){
	./load_network.sh "$@"
}

load_cpu(){
	./load_cpu.sh "$@"
}

log_cpu(){
	./log_cpu.sh "$@"
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