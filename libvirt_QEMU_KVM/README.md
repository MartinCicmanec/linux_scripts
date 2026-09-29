This (guide)[https://github.com/infokiller/win10-vm] on setting up virtual and latest (repository)[https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/] for virtio.

To install TIA in Tiny10 use this guide from (reddit)[https://www.reddit.com/r/tiny10/comments/1128tny/how_to_install_internet_explorer_on_tiny_10/]:
for people seeing this post in the future, if roblox doesn't open in tiny10 then do this:
```bash
1] open Registry Editor
2] go here: Computer\HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer
3] right click > new > String Value
4] rename the newly created file to "Version" - exactly like this
5] open the "Version" file, in the "Value Data:" field put "9.11.25211.0" - exactly like thisand that is it! go play roblox! and enjoy!
6] Also probably add "W2kVersion": "9.11.25211.0" -- "svcVersion":"11.3750.19041.0" -- "svcUpdateVersion":"11.0.1000" - Did not help
 Try more : "Build":"919041"
    "Version Vector": {"IE":"9.0000", "VML":"1.0"}
```


Next step is .NET 3.5 SP1 from this (thread)[https://www.reddit.com/r/tiny10/comments/vfmivl/cant_install_net_and_directx_in_tiny10_can_anyone/]
```
For those who find this post now, you can install dotnet 3.5 (and probably other features (if you can find the featureName) through cmd prompt. You just need a windows/tiny10 iso or boot usb drive etc.



Plug in your USB drive or find your iso

open cmd/powershell as admin

run the below cmd changing the /Source to the location/drive of your iso/boot drive

dism /online /enable-feature /featurename:NetFX3 /All /Source:D:\sources\sxs /LimitAccess
dism /online /Add-Capability /CapabilityName:Browser.InternetExplorer~~~~0.0.11.0 /Source:D:\sources\sxs /LimitAccess
```
 Check out GPU (passthrough)[https://wiki.archlinux.org/title/QEMU/Guest_graphics_acceleration] in future

CHTT
irm christitus.com/win | iex

# Setup USB-ETH device for direct connection of switchboard
```bash
nmcli device
nmcli ip link set enx9c69d3017ed8 up
nmcli con  enx9c69d3017ed8 up
nmcli device set enx9c69d3017ed8 managed yes
sudo nmcli device connect enx9c69d3017ed8
sudo nmcli con add type ethernet ifname enx9c69d3017ed8 con-name usb-eth0 ip4 192.168.1.5/24

```

# Shared folder between host and Windows VM (virtiofs)
Shares host dir `~/vm-share` with VM `win10-ent`; it shows up in Windows as drive `Z:`.
Needs the `virtiofsd` package on the host (Ubuntu: `sudo apt install virtiofsd`).

## Host
```bash
mkdir -p ~/vm-share
# virtiofs requires shared memory backing
virt-xml --connect qemu:///system win10-ent --edit --memorybacking source.type=memfd,access.mode=shared
# add the share; target.dir is just a tag the guest sees
virt-xml --connect qemu:///system win10-ent --add-device --filesystem driver.type=virtiofs,source.dir=$HOME/vm-share,target.dir=host_share
# check
virsh -c qemu:///system dumpxml --inactive win10-ent | grep -A4 -E '<memoryBacking|<filesystem'
```
Changes apply only after a full power-off (a reboot from inside Windows is not enough):
```bash
virsh -c qemu:///system shutdown win10-ent
virsh -c qemu:///system start win10-ent
```
Attach the virtio-win ISO for the guest drivers:
```bash
wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
sudo mv virtio-win.iso /var/lib/libvirt/images/
virsh -c qemu:///system change-media win10-ent sdb /var/lib/libvirt/images/virtio-win.iso --insert --live --config
```

## Guest (Windows)
1. Install [WinFsp](https://winfsp.dev/rel/) (the default options are fine).
2. From the virtio-win CD, run `virtio-win-guest-tools.exe`. It installs the VirtIO-FS driver and the `VirtioFsSvc` service.
   Without the installer: Device Manager -> "Mass Storage Controller" -> Update driver -> `<CD>:\viofs\w10\amd64`.
3. In an admin cmd, start the service and set it to start at boot:
```
sc.exe config VirtioFsSvc start=auto
sc.exe start VirtioFsSvc
```
4. The share appears as drive `Z:`.

Note: `virtiofsd` runs as root, so files created from Windows are owned by root on the host. To fix:
`sudo chown -R $USER: ~/vm-share`

Remove the share again:
```bash
virt-xml --connect qemu:///system win10-ent --remove-device --filesystem target.dir=host_share
```

# Following the uplink cable (host and guests)

Two symptoms, one cause: unplug the cable and the host has no internet although wifi is
associated, and the guests sit on a bridge with no uplink.

NetworkManager ignores carrier on bridges, so `br0` keeps its DHCP lease and its default
route at metric 425, which outranks wifi's 600 — host traffic goes into a dead bridge.
The ethernet port is a bridge *port*, so NM does not react to its carrier either, and
nothing tears the stale config down.

`br0-uplink-watch` (systemd service) follows the carrier of `enp0s31f6`:

| cable | host | guests |
| --- | --- | --- |
| in | `br0` has the LAN address, metric 425 | tap on `br0`, guest on 192.168.0.0/24 |
| out | `br0` flushed, wifi default route wins | tap moved to `virbr0`, guest NAT'd out wifi |

```bash
sudo install -m 755 br0-uplink-watch /usr/local/sbin/br0-uplink-watch
sudo install -m 644 br0-uplink-watch.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now br0-uplink-watch
journalctl -t br0-uplink-watch -f
```

Test it without touching the cable — a full cycle takes about 6 s:
```bash
sudo ip link set enp0s31f6 down    # ip route, virsh domiflist win10-ent
sudo ip link set enp0s31f6 up
```

## Why wifi is not simply added to the bridge

It cannot be. An 802.11 station sends 3-address frames, and the AP only accepts ones
whose source MAC is the station's own, so guest frames are dropped. The way around it is
4-address (WDS) mode, which `iwlwifi` does not support and which foreign APs would not
offer anyway. NAT through `virbr0` is the working equivalent: libvirt's `default` network
masquerades 192.168.122.0/24 with no outbound-interface restriction, so it follows
whatever default route the host has.

While on wifi the guest can still reach the LAN outbound (masqueraded), but nothing on
the LAN can reach the guest, and a router-side DHCP reservation for it does not apply.

## Two traps this works around

`nmcli connection up br0` (and an NM restart) silently detaches libvirt's `vnet0` from
the bridge. libvirt never notices, so the guest stays offline until the VM is restarted —
that is how `win10-ent` ended up with a detached tap. The watcher re-attaches a tap that
is in the wrong bridge, and prefers `nmcli device reapply br0`, which keeps foreign ports.

STP on `br0` cost 15-30 s on every replug: the port sits in listening/learning, so NM's
DHCP finds no path and the address only arrives once the port forwards. With a single
uplink port there is no loop to protect against:
```bash
sudo nmcli con mod br0 bridge.stp no
sudo sh -c 'echo 0 > /sys/class/net/br0/bridge/stp_state'   # live, no reactivation
```
That took a replug from ~31 s down to ~6 s.

Knobs: `POLL` (re-apply tick, only covers a guest started while unplugged) and `RETRY`
(backoff after a failed action) in the unit file. `br0-uplink-watch --once` applies the
current state and exits.
