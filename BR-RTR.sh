#!/bin/bash

# Переименовываем машину
hostnamectl set-hostname br-rtr.au-team.irpo

systemctl stop systemd-resolved
systemctl disable systemd-resolved

# Создаем директории для интерфейсов
mkdir -p /etc/net/ifaces/{ens19,iptunnel}

# Настраиваем интерфейс ens19
cat <<EOF > /etc/net/ifaces/ens19/options
BOOTPROTO=static
TYPE=eth
EOF

# Устанавливаем статический адрес для интерфейса ens19
echo '192.168.3.1/27' > /etc/net/ifaces/ens19/ipv4address

# Настраиваем интерфейс iptunnel (GRE)
cat <<EOF > /etc/net/ifaces/iptunnel/options
TYPE=iptun
TUNTYPE=gre
TUNLOCAL=172.16.5.2 
TUNREMOTE=172.16.4.2
EOF

# Устанавливаем статический адрес и шлюз для интерфейса iptunnel
echo '10.0.0.2/30' > /etc/net/ifaces/iptunnel/ipv4address
echo '192.168.1.0/26 via 10.0.0.1' > /etc/net/ifaces/iptunnel/ipv4route
echo '192.168.2.0/28 via 10.0.0.1' >> /etc/net/ifaces/iptunnel/ipv4route
echo '192.168.99.0/29 via 10.0.0.1' >> /etc/net/ifaces/iptunnel/ipv4route

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
apt-get install frr openssh-server systemd-timesyncd rsyslog-classic -y

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
hostname br-rtr.au-team.irpo
log file /var/log/frr/frr.log
no ipv6 forwarding
!
router ospf
 router-id 3.3.3.3
 network 10.0.0.0/30 area 0
 network 172.16.4.0/28 area 0
 network 172.16.5.0/28 area 0
 network 192.168.3.0/27 area 0
exit
!
EOF

systemctl enable --now frr
systemctl restart frr

systemctl disable --now chronyd

#cat <<EOF > /etc/systemd/timesyncd.conf
#NTP=172.16.4.2
#EOF

echo 'NTP=172.16.4.2' >> /etc/systemd/timesyncd.conf

systemctl enable --now systemd-timesyncd
systemctl restart systemd-timesyncd
timedatectl timesync-status
exec bash
