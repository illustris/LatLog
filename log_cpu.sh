#!/bin/bash

source config.sh

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