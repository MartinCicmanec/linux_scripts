
nmcli con add ifname br0 type bridge con-name br0
nmcli con add type bridge-slave ifname enp8s0 master br0

sudo nmcli connection modify br0 ipv4.addresses '192.168.88.7/24'
sudo nmcli connection modify br0 ipv4.gateway '192.168.88.100'
sudo nmcli connection modify br0 ipv4.dns '8.8.8.8,8.8.4.4'
sudo nmcli connection modify br0 ipv4.dns-search 'sysguides.com'
sudo nmcli connection modify br0 ipv4.method manual

sudo nmcli connection up br0

sudo nmcli connection modify br0 connection.autoconnect-slaves 1

sudo nmcli connection up br0

$ vim nwbridge.xml
<network>
  <name>br0</name>
  <forward mode='bridge'/>
  <bridge name='br0'/>
</network>