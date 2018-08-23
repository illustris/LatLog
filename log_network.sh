#!/bin/bash

source config.sh

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