#!/bin/bash

systemctl stop systemd-resolved
systemctl disable systemd-resolved
systemctl restart samba

samba-tool domain info 127.0.0.1

read -p "Нажми Enter, чтобы продолжить..."

# После перезагрузки создаем новых пользователей и групп в AD
samba-tool user add user1.hq P@ssw0rd
samba-tool user add user2.hq P@ssw0rd
samba-tool user add user3.hq P@ssw0rd
samba-tool user add user4.hq P@ssw0rd
samba-tool user add user5.hq P@ssw0rd

samba-tool group add hq
samba-tool group addmembers hq user1.hq,user2.hq,user3.hq,user4.hq,user5.hq

echo "Напоминание: сейчас выполни дейтвия на КЛИ и перезагрузи её, после этого продолжай"
echo "На CLI: Центр управления системой > Аутентификация > Домен Active Directory"
echo "Домен: AU-TEAM.IRPO"
echo "Рабочая группа: AU-TEAM"
echo "Имя компьютера: hq-cli"
echo "Восстановить файлы конфигурации по умолчанию > P@ssw0rd > reboot"
echo "P@ssw0rd"
echo "reboot"
echo "Возвращаемся на BR-SRV"
read -p "Нажми Enter, чтобы продолжить..."

apt-repo add rpm http://altrepo.ru/local-p10 noarch local-p10
apt-get update
apt-get install sudo-samba-schema -y

systemctl stop systemd-resolved
systemctl disable systemd-resolved

echo "Напоминание: сейчас выполни sudo-schema-apply > yes, затем create-sudo-rule"
echo "Имя правила: prava_hq"
echo "sudoCommand: /bin/cat"
echo "sudoUser: %hq"

echo "Затем запусти BR-SRV-3.sh"
read -p "Нажми Enter, чтобы продолжить..."
