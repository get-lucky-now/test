#!/bin/bash

# Переименовываем машину
hostnamectl set-hostname br-srv.au-team.irpo

apt-get update
apt-get install openssh-server systemd-timesyncd samba task-samba-dc docker-engine docker-compose rsyslog-classic -y

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
#NTP=172.16.4.2
#EOF

echo 'NTP=172.16.4.2' >> /etc/systemd/timesyncd.conf

systemctl enable --now systemd-timesyncd
systemctl restart systemd-timesyncd

wget https://raw.githubusercontent.com/get-lucky-now/script/main/BR-SRV-2.sh
chmod +x BR-SRV-2.sh
wget https://raw.githubusercontent.com/get-lucky-now/script/main/BR-SRV-3.sh
chmod +x BR-SRV-3.sh

#обновляем пакеты
apt-get update

# Обновляем файл resolv.conf, оставляя локальную запись DNS
cat <<EOF > /etc/resolv.conf
#domain ak.local
#nameserver 8.8.8.8
nameserver 127.0.0.1
EOF

# Очищаем старую конфигурацию Samba
rm -rf /etc/samba/smb.conf

# Обновляем hosts-файл
cat <<EOF >> /etc/hosts
192.168.3.10  br-srv.au-team.irpo
EOF

echo " Напоминание: сейчас AU-TEAM.IRPO > AU-TEAM > dc > SAMBA_INTERNAL > 192.168.1.10 (вручную) > P@ssw0rd"
read -p "Нажми Enter, чтобы продолжить..."

# Создаем новую доменную структуру с использованием samba-tool
samba-tool domain provision

# Перемещаем конфиг KRB5 в нужный каталог
mv -f /var/lib/samba/private/krb5.conf /etc/krb5.conf

systemctl enable smb
systemctl start smb

# Создаем дополнительные файлы автозапуска
cat <<EOF > /etc/rc.d/rc.local
#!/bin/sh -e
systemctl restart network
systemctl restart samba
exit 0
EOF

# Предоставляем права на выполнение файла rc.local
chmod +x /etc/rc.d/rc.local

timedatectl timesync-status

echo "Напоминание: после перезапуска запусти BR-SRV-2.sh"
read -p "Нажми Enter, чтобы продолжить..."

# Перезагрузка системы для применения изменений
reboot
