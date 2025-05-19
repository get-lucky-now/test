#!/bin/bash

# Переименовываем машину
hostnamectl set-hostname hq-srv.au-team.irpo

apt-get update
apt-get install openssh-server systemd-timesyncd dnsmasq tree -y

# Создаем нового пользователя
useradd sshuser -u 1010
id sshuser
passwd sshuser

# Редактируем файл sudoers, разрешая пользователю выполнять команды без пароля
echo 'sshuser ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers

cat <<EOF > /tmp/sshd_new_top
Port 2024
PermitRootLogin no
AllowUsers sshuser
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

# Настраиаем timesyncd
systemctl disable --now chronyd

echo 'NTP=192.168.1.1' >> /etc/systemd/timesyncd.conf

systemctl enable --now systemd-timesyncd
systemctl restart systemd-timesyncd

cat <<EOF > /etc/dnsmasq.conf
domain=au-team.irpo
server=8.8.8.8
server=/au-team.irpo/192.168.3.10
interface=ens18

# --- A и PTR ---
address=/hq-rtr.au-team.irpo/192.168.1.1
ptr-record=1.1.168.192.in-addr.arpa,hq-rtr.au-team.irpo

address=/hq-srv.au-team.irpo/192.168.1.10
ptr-record=10.1.168.192.in-addr.arpa,hq-srv.au-team.irpo

address=/hq-cli.au-team.irpo/192.168.2.10
ptr-record=10.2.168.192.in-addr.arpa,hq-cli.au-team.irpo

# --- Только A ---
address=/br-rtr.au-team.irpo/192.168.3.1
address=/br-srv.au-team.irpo/192.168.3.10
address=/moodle.au-team.irpo/172.16.4.1
address=/wiki.au-team.irpo/172.16.5.1
EOF

systemctl enable --now dnsmasq
systemctl restart dnsmasq

timedatectl timesync-status

exec bash
