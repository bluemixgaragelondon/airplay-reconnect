# airplay-reconnect
Scripts to automatically re-connect to an airplay device (like an Apple TV)

For more information, see the [Bluemix Garage Blog](http://garage.mybluemix.net/posts/apple-tv-reconnect/).

wifidevice=`networksetup -listallhardwareports | grep -A1 Wi-Fi | grep Device | sed s/"Device: "/""/`
networksetup -setairportpower $wifidevice on

