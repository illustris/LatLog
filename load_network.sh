#!/bin/bash

if [ $# -lt 2 ]
then
	echo -n "Usage: "
	echo -n $0
	echo " [i/o] [inbound load source IP] port"
	exit
fi
# more argument validation needed

if [ $1 == 'o' ]
then
	cat /dev/zero | nc -lp $2
	exit
fi

if [ $1 == 'i' ]
then
	state=$(sudo nmap -sS 127.0.0.1 -p 1337 | sed -n -e 's/^[0-9]*\/tcp\s\([a-z]*\)\s.*/\1/p')
	if [ $state == "open" ]
	then
		# echo "Remote port open"
		nc $2 $3 > /dev/null
	else
		echo "Remote port not open"
		exit
	fi
	exit
fi