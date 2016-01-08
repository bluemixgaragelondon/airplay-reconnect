#! /bin/bash

wifidevice=`networksetup -listallhardwareports | grep -A1 Wi-Fi | grep Device | sed s/"Device: "/""/`

isinuse() {
	tvhostname=$1
	# For a bonjour lookup, nslookup and host don't work, so we can use dns-sd or ping. The dns-sd gives more 
	# information, but by design doesn't return until killed, so use ping. 
	ipaddress=$(ping -c 1 $tvhostname | awk -F'[()]' '/PING/{print $2}')
	echo About to sniff traffic to $tvhostname \($ipaddress\)
  arp -n $ipaddress &> /var/tmp/arp-output
  fieldindex='$4'
  # Parse something of the form ? (10.37.109.150) at 40:33:1a:3d:e6:ee on en0 ifscope [ethernet] 
  # The awk quotes get a bit messy with the variable substitution, so split the expression up
  echo Parsing mac address from line `awk -F"[ ]" "/\($ipaddress\)/{print}" /var/tmp/arp-output`
  macaddress=`awk -F"[ ]" "/($ipaddress)/{print $fieldindex}" /var/tmp/arp-output`
 echo Looking for traffic to mac address $macaddress 
  # Make sure that the user running this script has passwordless sudo tcpdump
	sudo tcpdump -i $wifidevice -I ether dst $macaddress &> /var/tmp/airplay-tcpdump-output &
	# Get the PID of the tcpdump command
	pid=$!
	# Capture 10 seconds of output, then kill the job
	sleep 10
	sudo kill $pid
	# Process the output file to see how many packets are reported captured
	packetcount=`awk -F'[ ]' '/captured/{print $1}' /var/tmp/airplay-tcpdump-output`
	echo Finished sniffing packets - there were $packetcount. 
	
  # There will be a lot of packets flying around, so the bar for in-use is high
	if [ $packetcount -gt 20 ]
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
# Bounce the wifi to make sure it's in a good state since monitor mode can make it hard to connect to the TV
    echo Bouncing wifi interface $wifidevice
        networksetup -setairportpower $wifidevice off
        networksetup -setairportpower $wifidevice on
# Allow the wifi to initialise
        sleep 20
        dir=`dirname $0`
        osascript $dir/clickairplaymenu.applescript "$tvname"
fi

