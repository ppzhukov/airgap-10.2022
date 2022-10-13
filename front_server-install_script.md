## Если у Вас нет DHCP сервера Вы можете временно настроить сеть, для возможности подключиться по SSH и сделать остальные настройки.
### Временная настройка сети
```bash
ip a a 192.168.1.1/24 dev eth0
ip l s up eth0
ip ro add default via 192.168.1.254
echo "nameserver 192.168.1.254" >> /etc/resolv.conf
```
## Расширение раздела виртуальной машины до размеров диска (on-line).
```bash
echo -e "quit\nY\n" | sfdisk /dev/sda --force
partprobe /dev/sda
echo 1 > /sys/block/sda/device/rescan
parted -s /dev/sda resize 3 100%
btrfs filesystem resize max /
```

## Настройка сервера (замените {YOUR_CODE} своими данными)
```bash
 export reg_code={YOUR_CODE}
SUSEConnect -r ${reg_code}
swapoff -a
systemctl disable kdump --now
systemctl disable firewalld --now
zypper in -y -t pattern enhanced_base base yast2_basis
zypper in yast2-network
zypper in -y wget screen
```
Настройка сети на постоянной основе.
```bash
yast2 lan
```
Установка и настройка Docker.
```bash
SUSEConnect -p sle-module-containers/15.3/x86_64
zypper in -y docker
usermod -aG docker sles
usermod -aG docker root
chown root:docker /var/run/docker.sock
systemctl enable docker --now
```
