#! /bin/bash

isinuse() {
	tvhostname=$1
	# For a bonjour lookup, nslookup and host don't work, so we can use dns-sd or ping. The dns-sd gives more 
	# information, but by design doesn't return until killed, so use ping. 
	ipaddress=$(ping -c 1 $tvhostname | awk -F'[()]' '/PING/{print $2}')
	echo About to sniff traffic to $tvhostname \($ipaddress\)
	tcpdump tcp port 7000 and host $ipaddress &> /var/tmp/airplay-tcpdump-output &
	# Get the PID of the tcpdump command
	pid=$!
	# Capture 10 seconds of output, then kill the job
	sleep 10
	kill $pid
	# Process the output file to see how many packets are reported captured
	packetcount=`awk -F'[ ]' '/captured/{print $1}' /var/tmp/airplay-tcpdump-output`
	echo Finished sniffing packets - there were $packetcount. 
	
	if [ $packetcount -gt 0 ]
        # 0 is true and 1 is false in bash-world
	then
		echo Apple TV is in use. 
		return 0
	else
		return 1
	fi

}

tvname=$1

# Substitute dashes for spaces to find the Bonjour name
hostname=${tvname/ /-}.local
echo Hostname is $hostname


if ! isinuse $hostname
then 
	echo Grabbing control of $hostname. 
        dir=`dirname $0`
        osascript $dir/clickairplaymenu.applescript $tvname
fi

