#!/bin/bash
YUM=$(which yum)
IP=$(curl -4 -s icanhazip.com)
IPC=$(echo $IP | cut -d"." -f3)
IPD=$(echo $IP | cut -d"." -f4)
INT=$(ls /sys/class/net | grep e)

if [ "$YUM" ]; then
	echo > /etc/sysctl.conf
	tee -a /etc/sysctl.conf <<EOF
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.all.disable_ipv6 = 0
EOF
	sysctl -p

	IPV6_PREFIX="2403:6a40:0"
	if [ $IPC == 4 ]; then
		IPV6_PREFIX+=":40"
	elif [ $IPC == 5 ]; then
		IPV6_PREFIX+=":41"
	elif [ $IPC == 244 ]; then
		IPV6_PREFIX="2403:6a40:2000:244"
	else
		IPV6_PREFIX+=":$IPC"
	fi

	tee -a /etc/sysconfig/network-scripts/ifcfg-eth0 <<-EOF
	IPV6INIT=yes
	IPV6_AUTOCONF=no
	IPV6_DEFROUTE=yes
	IPV6_FAILURE_FATAL=no
	IPV6_ADDR_GEN_MODE=stable-privacy
	IPV6ADDR=$IPV6_PREFIX::$IPD:0000/64
	IPV6_DEFAULTGW=$IPV6_PREFIX::1
	EOF

	service network restart
	rm -rf ipv6.sh
else
	IPV6_PREFIX="2403:6a40:0"
	if [ "$IPC" = "4" ]; then
		IPV6_PREFIX+=":40"
	elif [ "$IPC" = "5" ]; then
		IPV6_PREFIX+=":41"
	elif [ "$IPC" = "244" ]; then
		IPV6_PREFIX="2403:6a40:2000:244"
	else
		IPV6_PREFIX+=":$IPC"
	fi

	IPV6_ADDRESS="$IPV6_PREFIX::$IPD:0000/64"
	GATEWAY="$IPV6_PREFIX::1"

	if [ "$INT" = "ens160" ]; then
		netplan_path="/etc/netplan/99-netcfg-vmware.yaml"
	elif [ "$INT" = "eth0" ]; then
		netplan_path="/etc/netplan/50-cloud-init.yaml"
	else
		echo 'Khong co card mang phu hop'
		exit 1
	fi

	netplan_config=$(cat "$netplan_path")
	new_netplan_config=$(sed "/gateway4:/i \ \ \ \ \ \ \ \ \ \ \ \ - $IPV6_ADDRESS" <<< "$netplan_config")
	new_netplan_config=$(sed "/gateway4:.*/a \ \ \ \ \ \ \ \ \ \ \ \ gateway6: $GATEWAY" <<< "$new_netplan_config")
	echo "$new_netplan_config" > "$netplan_path"
	sudo netplan apply
fi

echo 'Da tao IPV6 thanh cong!'
