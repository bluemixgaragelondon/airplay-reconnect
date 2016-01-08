# airplay-reconnect
Scripts to automatically re-connect to an airplay device (like an Apple TV)

For more information, see the [Bluemix Garage Blog](http://garage.mybluemix.net/posts/apple-tv-reconnect/).

wifidevice=`networksetup -listallhardwareports | grep -A1 Wi-Fi | grep Device | sed s/"Device: "/""/`
networksetup -setairportpower $wifidevice on

# Required prep
## Allow password-less sudo 

    # Allow anyone to run tcpdump without asking for a password
    buildmachine ALL=(ALL:ALL) NOPASSWD: /usr/sbin/tcpdump
    buildmachine ALL=(ALL:ALL) NOPASSWD: /bin/kill

## Enable assistive assistance to the script 

It's a good idea to run the airplay.sh script manually at least once. You will see an error message which prompts 
you to [update your settings and allow airplay.sh to control the UI](https://support.apple.com/en-gb/HT202866).

