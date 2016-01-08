# airplay-reconnect
Scripts to automatically re-connect to an airplay device (like an Apple TV)

For more information, see the [Bluemix Garage Blog](http://garage.mybluemix.net/posts/apple-tv-reconnect/).

# Required prep
## Allow password-less sudo 

    # Allow anyone to run tcpdump without asking for a password
    buildmachine ALL=(ALL:ALL) NOPASSWD: /usr/sbin/tcpdump
    buildmachine ALL=(ALL:ALL) NOPASSWD: /bin/kill

## Enable assistive assistance to the script 

It's a good idea to run the airplay.sh script manually at least once. You will see an error message which prompts 
you to [update your settings and allow airplay.sh to control the UI](https://support.apple.com/en-gb/HT202866).

# How it works 

## Scripting mirroring a display to an Apple TV

There are some excellent resources on [how to use AppleScript to drive the AirPlay menu](http://tech.adroll.com/blog/terminal/2014/09/26/introducing-aircontrol-control-airplay-through-terminal.html), and it’s pretty easy (the [applescript file I ended up with](clickairplaymenu.applescript) isn't very long). 

    tell application "System Events"
                tell process "SystemUIServer"
                        click (menu bar item 1 of menu bar 1 whose description contains "Displays")
                        set displaymenu to menu 1 of result
                        -- Tolerate numbers in brackets after the tv name --
                        click ((menu item 1 where its name starts with tvname) of displaymenu)
                end tell
         end tell

One complexity is that the name of our Apple TV box sometimes gets a number in brackets tacked on to the name, so we can’t just hardcode the name. Using a “starts with” selector fixes that problem. 

## Driving the script automatically 
 
I also set up a launch agent (a .plist file) to drive the display mirroring every five minutes. The exact plist file will depend on where the scripts are extracted, but copying our [.plist file](example.airplay.plist) to ‘~/Library/LaunchAgents’ and updating the paths is a good start. 

## Detecting when an Apple TV is already showing something

This solution wasn’t quite good enough, though. If one of us was ~currently~ sharing our screen, we didn’t want the build radiator to grab control back every five minutes. How could we tell if the screen was currently being used? It turns out that this is harder. My initial assumption was that we’d get a ‘Garage TV is being used by someone else’ prompt if an AirPlay share was active, but we didn’t. I suspect it depends on the version of the Apple TV and also the type of share (photos, videos, mirroring … ). Looking at [the AirPlay protocols](https://nto.github.io/AirPlay.html), there doesn’t seem to be any HTTP or RTSP endpoint on the Apple TV which reports whether it’s currently active. That’s ok - we can figure it out ourselves. 

AirPlay mirroring traffic is all handled on port 7000 of the Apple TV ([other types of share uses different ports](https://nto.github.io/AirPlay.html)). We can sniff the network traffic to see if there are packets flying around, and only start AirPlay mirroring if there aren’t. Bonjour allows us to find an ip address if we know the device name, and tcpdump shows us traffic. 

To get the IP address of an Apple TV, replace spaces with hyphens in the name, append a .local domain, and then ping it. The ping output will include the ip address, which can be parsed out. For example, 

     # Substitute dashes for spaces to find the Bonjour name
     tv hostname=${tvname/ /-}.local
     ipaddress=$(ping -c 1 $tvhostname | awk -F'[()]' '/PING/{print $2}')

Then tcpdump can be used to monitor traffic to that host. My initial implementation was this:

     sudo tcpdump tcp port 7000 and host $ipaddress > /var/tmp/airplay-tcpdump-output

The tcpdump command will run indefinitely, so we let it run for ten seconds, then stop it: 

        # Get the PID of the tcpdump command
        pid=$!
        # Capture 10 seconds of output, then kill the job
        sleep 10
        sudo kill $pid

This worked great when I tested locally, but when I tried it on a bigger network, I discovered that on a wireless network, traffic is point-to-point, and tcpdump 
can’t gather packets promiscuously. In other words, I could only see traffic to the Apple TV when it was coming from 
my machine. Useful, but not useful enough.

Switching to monitor mode allows all packets to be viewed, but since packets on a secure network are encrypted, tcpdump can’t filter on tcp-level details, like 
the port and IP address. Luckily, tcpdump does allow filtering by MAC address, and the arp -n command can be used to work out the MAC address from the IP address. 

     arp -n $ipaddress &> /var/tmp/arp-output
     fieldindex='$4'
     macaddress=`awk -F"[ ]" "/($ipaddress)/{print $fieldindex}" /var/tmp/arp-output`

Finally, the output file can be parsed with [awk](http://www.ibm.com/developerworks/library/l-awk1/) to count how many packets have flown past.  

        # Process the output file to see how many packets are reported captured
        packetcount=`awk -F'[ ]' '/captured/{print $1}' /var/tmp/airplay-tcpdump-output`

A heartbeat packet is sent every second, so I assumed that after listening for 10 seconds an in-use device will always generate some traffic. Listening to the tcp packets on port 7000 (my first attempt) doesn’t yield very many packets, so any packet count greater than 0 indicates the device is in use. Once I started listening to the lower-level packets, there was always some traffic, even when the tv isn’t in use, so I used a threshold of 20:

    if [ $packetcount -gt 0 ]
    then
                # Handle in-use case
        else
                # Handle not-in-use case
        fi

The pieces are connected together in [the shell script](airplay.sh). 
