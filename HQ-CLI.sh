#!/bin/bash

# Переименовываем машину
hostnamectl set-hostname hq-cli.au-team.irpo

apt-get update
apt-get install openssh-server systemd-timesyncd -y

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
#NTP=192.168.2.1
#EOF

echo 'NTP=192.168.2.1' >> /etc/systemd/timesyncd.conf

systemctl enable --now systemd-timesyncd
systemctl restart systemd-timesyncd
timedatectl timesync-status
exec bash
