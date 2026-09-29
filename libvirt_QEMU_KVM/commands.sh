# Shink image
qemu-img convert -c -O qcow2 /home/martin/Downloads/Win11SandboxBckp.qcow2 /home/martin/Downloads/Win11Sandbox.qcow2
# Another variant of shrinking
sudo apt install libguestfs-tools
virt-sparsify --compress /home/martin/Downloads/Win11SandboxBckp.qcow2 /home/martin/Downloads/Win11Sandbox.qcow2
# Create 100MB virtual disk to be mounted into vrt system.
qemu-img create -f qcow2 lic.img 100m

# To install Windows XP: https://computernewb.com/wiki/QEMU/Guests/Windows_XP
# File from https://computernewb.com/isos/windows/?C=M&O=A

qemu-img create -f qcow2 winxp.qcow2 32G

# Install:
qemu-system-i386 -M q35,usb=on,acpi=on,hpet=off -global q35-pcihost.x-pci-hole64-fix=false -m 4G -cpu host -accel kvm -drive if=virtio,file=winxp.qcow2 -drive if=floppy,file=/home/martin/Downloads/xp_q35_x86.img,format=raw -device usb-tablet -device VGA,vgamem_mb=64 -nic user,model=virtio -monitor stdio -cdrom /home/martin/Downloads/en_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73974.iso -boot d

# Run
qemu-system-i386 -M q35,usb=on,acpi=on,hpet=off -global q35-pcihost.x-pci-hole64-fix=false -m 4G -cpu host -accel kvm -cdrom /home/martin/Downloads/virtio-win-0.1.285.iso -drive if=virtio,file=winxp.qcow2 -device usb-tablet -device VGA,vgamem_mb=64 -nic user,model=virtio -monitor stdio