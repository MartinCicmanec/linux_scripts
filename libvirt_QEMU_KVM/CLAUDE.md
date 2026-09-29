# QEMU/KVM Windows VM Setup — Host Notes and Tuning

Audit + tuning notes for the two Windows guests on this host. Captured 2026-08-14.
Domain XML lives in this folder: `TIAv20.xml`, `win10-ent.xml`.

## Host facts (verify before reusing any pinning/paths)

| | |
|---|---|
| CPU | AMD Ryzen 7 1800X, 8C/16T, Zen 1 |
| CCX layout | **CCX0 = cpus 0-3,8-11** / **CCX1 = cpus 4-7,12-15** (8 MB L3 each) |
| SMT siblings | `N` and `N+8` (cpu0↔cpu8, cpu1↔cpu9, …) |
| RAM | 62 GiB, single NUMA node |
| VM images | `/mnt/virtdata/images` — `/dev/sda1`, ext4, Samsung 850 EVO **SATA** SSD, 458 G |
| Root fs | `/dev/nvme0n1p2`, 1.8 T, **99 % full** (970 EVO Plus — the fast disk, unusable for VMs until cleaned) |
| Bulk disk | `/dev/sdb2` 5.5 T HDD at `/run/media/martin/LinuxData` (backup target) |
| Stack | qemu 11.1, libvirt 12.6, swtpm 0.10, edk2-ovmf 202605, virtiofsd 1.14 |
| Daemons | modular: `virtqemud`/`virtnetworkd` active, monolithic `libvirtd` inactive |
| kvm_amd | `nested=1`, `npt=Y`, **`avic=N`** |
| Security | `security_driver` none, `/etc/libvirt/qemu.conf` all defaults → **QEMU runs as root** |
| Host NIC | `enp8s0`, DHCP `192.168.88.222/24`; ProtonVPN wireguard `proton0` + killswitch |

Regenerate the CCX map after any hardware change:
```bash
for c in 0 4 8 12; do echo "cpu$c L3: $(cat /sys/devices/system/cpu/cpu$c/cache/index3/shared_cpu_list)"; done
cat /sys/devices/system/cpu/cpu0/topology/thread_siblings_list
```

## VM inventory

| | TIAv20 | win10-ent |
|---|---|---|
| Guest | Windows 11 (TIA Portal V20 workstation) | Windows 10 Enterprise |
| Machine | `pc-q35-10.1` | `pc-q35-11.0` |
| Image | `/mnt/virtdata/images/TIAv20.qcow2`, 128 G virt / 73 G alloc | `/mnt/virtdata/images/win10-ent.qcow2`, 100 G virt / **96 G alloc** |
| Firmware | OVMF secboot 4m, swtpm 2.0 (tpm-crb) | same |
| Net | macvtap (`type='direct'`, bridge mode) on `enp8s0` | same |
| Display | SPICE on 127.0.0.1 + QXL 64/64/16 | same |
| Special | — | nested virt (`svm` required) |

Both were untouched-by-default virt-manager builds; the XML in this folder is the corrected version.

## Findings and why the fixes are what they are

### 1. `topoext` — the important one
QEMU logged on **both** VMs:
```
warning: This family of AMD CPU doesn't support hyperthreading(2). Please configure -smp options properly or try enabling topoext feature.
```
With `<cpu mode='host-passthrough' migratable='on'>`, libvirt strips `topoext`, so any
`threads='2'` topology is invisible to the guest — Windows sees a bogus cache/SMT layout and
schedules badly. Always pair SMT topology with:
```xml
<cpu mode='host-passthrough' check='none' migratable='on'>
  <topology sockets='1' dies='1' clusters='1' cores='3' threads='2'/>
  <feature policy='require' name='topoext'/>
  <cache mode='passthrough'/>
</cpu>
```

### 2. Missing `<topology>` = silent socket explosion
TIAv20 had no `<topology>`, so QEMU defaulted to `-smp 4,sockets=4,cores=1,threads=1`.
**Windows 11 Pro licenses 2 sockets** (Home: 1), so the guest was probably only using 2 of the
4 vCPUs. Verify in the guest: Task Manager → Performance → CPU → "Sockets". Always set topology
explicitly for Windows guests.

### 3. Disk cache mode
win10-ent ran `cache='writeback'` (guest flushes only reach the host page cache — a host crash
can corrupt guest NTFS), TIAv20 ran `cache='none'`. Standard for both now:
```xml
<iothreads>1</iothreads>
...
<driver name='qemu' type='qcow2' cache='none' io='io_uring'
        discard='unmap' detect_zeroes='unmap' iothread='1'/>
```
`io_uring` is available (qemu links `liburing.so.2` — check with
`ldd /usr/bin/qemu-system-x86_64 | grep uring`). If it ever isn't, fall back to `io='native'`.
The dedicated iothread + io_uring recover most of what `cache='none'` costs.

### 4. Space reclaim
win10-ent had 96 GiB allocated of a 100 GiB virtual disk. `discard='unmap'` alone never
reclaimed it. With `detect_zeroes='unmap'` in place, run in the guest:
```powershell
Optimize-Volume -DriveLetter C -ReTrim -Verbose
```
Check the result on the host with `sudo qemu-img info <image>.qcow2` (disk size vs virtual size).

### 5. CPU pinning on Zen 1
Cross-CCX access is this CPU's weak spot, so each VM gets its own CCX and one core pair is left
per CCX for the host, emulator and iothread:

| VM | vCPU pins (vcpu→host cpu) | emulator + iothread |
|---|---|---|
| TIAv20 | 0→0, 1→8, 2→1, 3→9, 4→2, 5→10 (CCX0) | `3,11` |
| win10-ent | 0→4, 1→12, 2→5, 3→13, 4→6, 5→14 (CCX1) | `7,15` |

Guest `cores='3' threads='2'` matches the host sibling pairs, so guest SMT siblings are real
host SMT siblings. The two sets are disjoint — both VMs can run concurrently.

### 6. Smaller fixes applied
- `<input type='tablet' bus='usb'/>` on both — only PS/2 mouse existed, so absolute pointer
  depended entirely on the SPICE guest agent.
- virtio-rng added to TIAv20 (win10-ent already had it) — Windows entropy starvation slows boot/TLS.
- `<driver name='vhost' queues='4'/>` on the NICs (must stay ≤ vCPU count). If networking
  misbehaves after a driver change, this single line is the thing to remove.
- TIAv20's install DVD detached; an empty SATA cdrom remains. The ISO lived in `~/Downloads`
  on the 99 %-full root fs. Keep ISOs on `/mnt/virtdata`.
- TIAv20 RAM 8 → 16 GiB. Siemens recommends 16 GB for recent TIA versions — *general guidance,
  not verified against the V20 readme.*

### 7. Harmless noise — don't chase it
```
qemu-system-x86_64: -device virtio-net-pci: Issue while setting TUNSETSTEERINGEBPF: Invalid argument
```
Benign: macvtap + vhost eBPF steering is simply unavailable. Not an error.

## Known-open items (deliberately NOT in the XML)

**Networking — macvtap means no host↔guest traffic.** `setup_bridge.sh` in this folder was
never applied (no `br0` exists). Consequences today: no RDP/SMB between host and guests, and
guest traffic leaves via `enp8s0` directly, **bypassing the ProtonVPN killswitch** (fine if
deliberate for PLC access). Script defects to fix before using it:
- hardcodes `192.168.88.7/24` while the host is on DHCP `.222`
- gateway `192.168.88.100` looks wrong — verify with `ip route` (MikroTik default is `.1`)
- `dns-search sysguides.com` is copy-paste from the source tutorial
- never disables/deletes the existing `enp8s0` profile → it fights the bridge slave at boot
- missing `bridge.stp no` → 15 s forwarding delay on every boot

Lighter alternative for host↔guest file transfer: keep macvtap and add **virtiofs**
(`virtiofsd` installed; guest needs virtio-win + WinFsp).

**Secure Boot is inert.** Both VMs have `secure-boot=yes` but `enrolled-keys='no'`, with nvram
templated from plain `OVMF_VARS.4m.fd`. Arch's `edk2-ovmf` no longer ships a pre-enrolled VARS
file; enrol manually if wanted:
```bash
virt-fw-vars --input /usr/share/edk2/x64/OVMF_VARS.4m.fd --enroll-redhat --secure-boot \
             --output /var/lib/libvirt/qemu/nvram/<vm>_VARS.fd
```
⚠ If BitLocker is enabled in the guest, replacing nvram changes TPM measurements → recovery-key
prompt. Confirm BitLocker status first.

**QEMU runs as root, no security driver.** `/etc/libvirt/qemu.conf` is empty of settings.
Dropping to `user`/`group = "libvirt-qemu"` (uid 954 exists and already owns the images) would
shrink the blast radius of two internet-facing Windows VMs. Requires chowning nvram and ISOs.

**No backups, no snapshots.** `/mnt/virtdata` has 253 G free vs 228 G of virtual disk — a full
copy won't reliably fit there. Use the 5.5 T HDD:
```bash
qemu-img convert -c -O qcow2 /mnt/virtdata/images/win10-ent.qcow2 \
  /run/media/martin/LinuxData/vm-backup/win10-ent-$(date +%F).qcow2   # VM must be shut off
```

**Storage tier.** Images sit on the SATA 850 EVO while the NVMe is 99 % full. Freeing the NVMe
(31 G of it is `~/Downloads`) and moving the images there is the single biggest available
performance win for TIA Portal.

**`kvm_amd.avic=1`** — could help interrupt-heavy Windows guests, but Zen 1 AVIC has errata and
historically conflicts with nested virt (win10-ent needs `svm`). Left off deliberately.

## Working commands

```bash
# All virsh here is system connection; VMs are NOT in qemu:///session
virsh -c qemu:///system list --all
virsh -c qemu:///system dumpxml --inactive TIAv20

# Apply the XML in this folder (VMs must be shut off; back up first)
virsh -c qemu:///system dumpxml --inactive TIAv20 > TIAv20.orig.xml
virsh -c qemu:///system define TIAv20.xml
virsh -c qemu:///system define TIAv20.orig.xml     # rollback

# Validate XML without touching libvirt
virt-xml-validate TIAv20.xml domain

# Inspect the exact qemu command line / warnings of the last run
sudo grep -E '^-(cpu|smp|m |machine|blockdev|netdev)' /var/log/libvirt/qemu/<vm>.log

# Attach install media to the empty cdrom
virsh -c qemu:///system change-media TIAv20 sda /mnt/virtdata/iso/foo.iso --update

# Image state (images are 0640 libvirt-qemu — needs sudo)
sudo qemu-img info /mnt/virtdata/images/win10-ent.qcow2
```

Storage pools defined: `default` → `/var/lib/libvirt/images`, `pool` → `/mnt/virtdata/images`,
`Downloads` → `/home/martin/Downloads` (the last one is a bad idea — it points at the full root fs).

## Gotchas for future edits

- Changing vCPU count / RAM alters the Windows hardware hash → retail keys may want
  reactivation. Volume/KMS (win10-ent) is unaffected.
- Machine type upgrades (`pc-q35-10.1` → newer) make Windows re-detect hardware. Do it
  deliberately, not casually.
- Adding devices without `<address>` is fine — libvirt assigns PCI slots at define time.
- XML comments cannot contain `--` (breaks the XML parser), which bites when documenting
  command-line flags in a comment.
