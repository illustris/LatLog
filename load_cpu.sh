#!/bin/bash

corecount=$(cat /proc/cpuinfo | awk '/^processor/{print $3}' | wc -l)

if [ $# -gt 0 ]
then
	corecount=$1
fi

stress --cpu $corecount