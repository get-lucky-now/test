#!/bin/bash

# Переименовываем машину
hostnamectl set-hostname hq-cli.au-team.irpo

apt-get update
apt-get install openssh-server -y
apt-get install systemd-timesyncd -y
apt-get install python-module-json -y
apt-get install yandex-browser-stable -y

# Создаем нового пользователя
useradd sshuser -u 1010
id sshuser
echo " Напоминание: P@ssw0rd"
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

sed -i 's|^#NTP=.*|NTP=172.16.4.2|' /etc/systemd/timesyncd.conf

systemctl enable --now systemd-timesyncd
systemctl restart systemd-timesyncd
timedatectl set-timezone Asia/Krasnoyarsk
systemctl restart systemd-timesyncd
timedatectl timesync-status
exec bash
