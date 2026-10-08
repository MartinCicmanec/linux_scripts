#!/bin/bash
# Recreate the br0 KVM bridge on enp0s31f6 and the cable/wifi uplink watcher.
# Run as: sudo ./setup-br0.sh   (safe to re-run)
set -euo pipefail

SRC="/run/media/martin/XPG GAMMIX S5/system"
PORT=enp0s31f6
BRIDGE=br0
VIRSH="virsh -c qemu:///system"
BACKUP=/home/martin/vm-xml-backup-$(date +%F)

[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }

has_con() { nmcli -t -f NAME connection show | grep -qx "$1"; }

echo "== NetworkManager profiles"
# Keep NM from generating a "Wired connection 1" that would grab the port.
install -Dm644 /dev/stdin /etc/NetworkManager/conf.d/10-br0.conf <<EOF
[main]
no-auto-default=interface-name:$PORT
EOF
nmcli general reload conf

# The bridge takes the NIC's MAC, so the router's DHCP lease/reservation stays the same.
has_con "$BRIDGE" || nmcli connection add type bridge ifname "$BRIDGE" con-name "$BRIDGE" \
	bridge.stp no \
	ethernet.cloned-mac-address "$(cat /sys/class/net/$PORT/address)" \
	connection.autoconnect yes connection.autoconnect-ports true \
	ipv4.method auto ipv6.method auto
has_con "$BRIDGE-port-$PORT" || nmcli connection add type ethernet ifname "$PORT" \
	con-name "$BRIDGE-port-$PORT" controller "$BRIDGE" port-type bridge connection.autoconnect yes
has_con "Wired connection 1" && nmcli connection delete "Wired connection 1"
nmcli connection up "$BRIDGE" >/dev/null 2>&1 || echo "   (br0 has no uplink yet; the watcher brings it up when the cable is plugged in)"

echo "== uplink watcher"
install -Dm755 "$SRC/br0-uplink-watch" /usr/local/sbin/br0-uplink-watch
install -Dm644 "$SRC/br0-uplink-watch.service" /etc/systemd/system/br0-uplink-watch.service
systemctl daemon-reload
systemctl enable --now br0-uplink-watch.service

echo "== VM NICs: libvirt 'default' network -> bridge $BRIDGE (backups in $BACKUP)"
install -d -o martin -g martin "$BACKUP"
for dom in $($VIRSH list --all --name); do
	$VIRSH dumpxml --inactive "$dom" >"$BACKUP/$dom.xml"
	chown martin:martin "$BACKUP/$dom.xml"
	$VIRSH domiflist --inactive "$dom" | awk 'NR > 2 && $2 == "network" && $3 == "default" { print $5 }' |
		while read -r mac; do
			echo "   $dom: NIC $mac"
			virt-xml -c qemu:///system "$dom" --edit mac="$mac" --network type=bridge,source="$BRIDGE" >/dev/null
		done
done

echo
echo "Done. Running guests keep their old NIC until they are shut down and started again."
systemctl --no-pager status br0-uplink-watch.service | head -5
