Latency logger
===

# Dependencies
```
sudo apt install bc sysstat arping netcat-openbsd
```

# Benchmark
Logs ping times, CPU and network utilization.
Usage:
```
./benchmark.sh [destination hosts list] [network interface] [period] [count] [(optional): remote logs[y/N]]
Destination hosts list: file with list of target IPs to which latency is being tested
Network interface: network interface to be logged
Period: sampling interval for CPU and network load
Count: Number of ping probes to send
Remote logs: If enabled, remote.sh is expected to be running on the remote host. Fetches
             remote CPU and network load logs.
```

# Remote logger
Should be run on the remote host. Logs CPU and network utilization.
Usage:
```
./remote.sh [interface] [period]
Interface: network interface to be logged
Period: sampling interval for CPU and network load
```
