#!/bin/bash

# Переименовываем машину
hostnamectl set-hostname hq-rtr.au-team.irpo

systemctl stop systemd-resolved
systemctl disable systemd-resolved

# Создаем директории для интерфейсов
mkdir -p /etc/net/ifaces/{ens19,ens19.100,ens19.200,ens19.999,iptunnel}

# Настраиваем интерфейс ens19
cat <<EOF > /etc/net/ifaces/ens19/options
BOOTPROTO=static
TYPE=eth
EOF

# Настраиваем интерфейс ens19.100 (VLAN 100)
cat <<EOF > /etc/net/ifaces/ens19.100/options
BOOTPROTO=static
TYPE=vlan
HOST=ens19
VID=100
EOF

# Настраиваем интерфейс ens19.200 (VLAN 200)
cat <<EOF > /etc/net/ifaces/ens19.200/options
BOOTPROTO=static
TYPE=vlan
HOST=ens19
VID=200
EOF

# Настраиваем интерфейс ens19.999 (VLAN 999)
cat <<EOF > /etc/net/ifaces/ens19.999/options
BOOTPROTO=static
TYPE=vlan
HOST=ens19
VID=999
EOF

# Устанавливаем статические адреса для интерфейсов VLAN
echo '192.168.1.1/26' > /etc/net/ifaces/ens19.100/ipv4address
echo '192.168.2.1/28' > /etc/net/ifaces/ens19.200/ipv4address
echo '192.168.99.1/29' > /etc/net/ifaces/ens19.999/ipv4address

# Настраиваем интерфейс iptunnel (GRE)
cat <<EOF > /etc/net/ifaces/iptunnel/options
TYPE=iptun
TUNTYPE=gre
TUNLOCAL=172.16.4.2
TUNREMOTE=172.16.5.2 
EOF

# Устанавливаем статический адрес и шлюз для интерфейса iptunnel
echo '10.0.0.1/30' > /etc/net/ifaces/iptunnel/ipv4address
echo '192.168.3.0/27 via 10.0.0.2' > /etc/net/ifaces/iptunnel/ipv4route

# Включаем форвардинг пакетов
sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf

sysctl -p

# Очищаем существующие правила iptables и настраиваем NAT
iptables -F
iptables -t nat -A POSTROUTING -o ens18 -j MASQUERADE
iptables-save > /etc/sysconfig/iptables

# Перезапускаем сеть
service network restart

# Добавляем IPTABLES в автозапуск
systemctl enable iptables
systemctl start iptables

apt-get update
apt-get install frr openssh-server chrony dnsmasq rsyslog-classic -y

# Создаем нового пользователя
useradd net_admin

# Устанавливаем пароль для пользователя net_admin
passwd net_admin

# Редактируем файл sudoers, разрешая пользователю выполнять команды без пароля
echo 'net_admin ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers

cat <<EOF > /tmp/sshd_new_top
Port 2024
PermitRootLogin no
AllowUsers net_admin
MaxAuthTries 2
Banner /etc/openssh/banner
EOF

cat /etc/openssh/sshd_config >> /tmp/sshd_new_top
mv /tmp/sshd_new_top /etc/openssh/sshd_config

# Создаем файл баннера входа
cat <<EOF > /etc/openssh/banner
Authorized access only

EOF

# Перезапускаем сервис SSHD
systemctl enable --now sshd.service
systemctl restart sshd.service

# Включаем OSPF
sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons

systemctl restart frr

cat <<EOF > /etc/frr/frr.conf
frr version 9.0.2
frr defaults traditional
hostname hq-rtr.au-team.irpo
log file /var/log/frr/frr.log
no ipv6 forwarding
!
router ospf
 router-id 2.2.2.2
 network 10.0.0.0/30 area 0
 network 172.16.4.0/28 area 0
 network 172.16.5.0/28 area 0
 network 192.168.1.0/26 area 0
 network 192.168.2.0/28 area 0
 network 192.168.99.0/29 area 0
exit
!
EOF

systemctl enable --now frr
systemctl restart frr

# Настраеваем dnsmasq
cat <<EOF > /etc/dnsmasq.conf
no-resolv
dhcp-range=192.168.2.2,192.168.2.15,999h
dhcp-option=3,192.168.2.1
dhcp-option=6,192.168.1.10
interface=ens19.200

expand-hosts
localise-queries
conf-dir=/etc/dnsmasq.conf.d
EOF

systemctl enable --now dnsmasq.service
systemctl restart dnsmasq.service

# Настраеваем сервер chrony
cat <<EOF > /etc/chrony.conf
local stratum 7
allow 192.168.1.0/26
allow 192.168.2.0/28
allow 172.16.4.0/28
allow 172.16.5.0/28
allow 192.168.3.0/27
#bindaddress 0.0.0.0
#port 123

driftfile /var/lib/chrony/drift
makestep 1.0 3
#rtcsync
ntsdumpdir /var/lib/chrony
logdir /var/log/chrony
pool 192.168.44.5 iburst
EOF

systemctl enable --now chronyd
systemctl restart chronyd
timedatectl set-ntp 0
systemctl restart chronyd

echo 'domain ak.local' > /etc/resolv.conf
echo 'nameserver 77.88.8.8' >> /etc/resolv.conf
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf

exec bash
#reboot
