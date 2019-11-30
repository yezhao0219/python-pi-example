#!/bin/bash

#if [ "$EUID" -ne 0 ]
  #	then echo "Please run this as root"
  #	sleep 10
  #	exit
#fi
  

apt-get update -y
apt-get remove --purge hostapd dnsmasq -y
apt-get install hostapd dnsmasq -y
systemctl stop dnsmasq
systemctl stop hostapd

sed -i 's/wpa-conf/# wpa-conf/g' /etc/network/interfaces

cat >> /etc/dhcpcd.conf <<EOF
interface wlan0
static ip_address=192.168.0.10/24
EOF

service dhcpcd restart

cat >> /etc/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=102.168.0.11,192.168.0.30,255.255.255.0,24h
EOF

systemctl start dnsmasq
systemctl reload dnsmasq

cat >> /etc/hostapd/hostapd.conf <<EOF
# This is the name of the WiFi interface we configured above
interface=wlan0
# This is the name of the network
ssid=RasPi3-AP
# Use the 2.4GHz band
hw_mode=g
# Use channel 6
channel=6
# Enable 802.11n
ieee80211n=1
# Enable WMM
wmm_enabled=1
# Enable 40MHz channels with 20ns guard interval
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]
# Accept all MAC addresses
macaddr_acl=0
# Use WPA authentication
auth_algs=1
# Require clients to know the network name
ignore_broadcast_ssid=0
# Use WPA2
wpa=2
# Use a pre-shared key
wpa_key_mgmt=WPA-PSK
# The network passphrase
wpa_passphrase=shmily7218
# Use AES, instead of TKIP
rsn_pairwise=CCMP
EOF

cat >> /etc/default/hostapd <<EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

systemctl unmask hostapd
systemctl enable hostapd
systemctl start hostapd
cat >> /etc/sysctl.conf <<EOF
net.ipv4.ip_forward=1
EOF

iptables -t -nat -A POSTROUTING -o eth0 -j MASQUERADE
sh -c "iptables-save > /etc/iptables.ipv4.nat"

sed -i -- 's/exit 0/ /g' /etc/rc.local


cat >> /etc/rc.local <<EOF
ifconfig wlan0 down
ifconfig wlan0 192.168.0.10 netmask 255.255.255.0 up
service dnsmasq restart
hostapd -B /etc/hostapd/hostapd.conf & > /dev/null 2>&1
iptables-restore < /etc/iptables.ipv4.nat
exit 0
EOF

echo "All done, rebooting in 10 seconds!"
sleep 10
echo "Rebooting!"

shutdown -r now
