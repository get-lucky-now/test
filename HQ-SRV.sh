#!/bin/bash

# Переименовываем машину
hostnamectl set-hostname hq-srv.au-team.irpo

apt-get update
apt-get install openssh-server systemd-timesyncd dnsmasq tree -y

# Создаем нового пользователя
useradd sshuser

# Устанавливаем пароль для пользователя sshuser
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

#cat <<EOF >> /etc/systemd/timesyncd.conf
#NTP=192.168.1.1
#EOF

echo 'NTP=192.168.1.1' >> /etc/systemd/timesyncd.conf

systemctl enable --now systemd-timesyncd
systemctl restart systemd-timesyncd

cat <<EOF > /etc/dnsmasq.conf
domain=au-team.irpo
server=8.8.8.8
server=/au-team.irpo/192.168.3.10
interface=ens18

address=/hq-rtr.au-team.irpo/192.168.1.1
ptr-record=1.1.168.192.in-addr.arpa,hq-rtr.au-team.irpo

address=/hq-srv.au-team.irpo/192.168.1.10
ptr-record=10.1.168.192.in-addr.arpa,hq-srv.au-team.irpo
cname=moodle.au-team.irpo,br-srv.au-team.irpo
cname=wiki.au-team.irpo,br-srv.au-team.irpo

address=/hq-cli.au-team.irpo/192.168.2.10
ptr-record=10.2.168.192.in-addr.arpa,hq-cli.au-team.irpo

address=/br-rtr.au-team.irpo/192.168.3.1
ptr-record=1.3.168.192.in-addr.arpa,br-rtr.au-team.irpo

address=/br-srv.au-team.irpo/192.168.3.10
ptr-record=10.3.168.192.in-addr.arpa,br-srv.au-team.irpo

address=/isp.au-team.irpo/172.16.5.1
ptr-record=1.5.16.172.in-addr.arpa,isp.au-team.irpo
EOF

systemctl enable --now dnsmasq
systemctl restart dnsmasq

timedatectl timesync-status

exec bash
