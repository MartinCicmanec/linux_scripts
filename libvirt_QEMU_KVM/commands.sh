# Shink image
qemu-img convert -c -O qcow2 /home/martin/Downloads/Win11SandboxBckp.qcow2 /home/martin/Downloads/Win11Sandbox.qcow2
# Another variant of shrinking
sudo apt install libguestfs-tools
virt-sparsify --compress /home/martin/Downloads/Win11SandboxBckp.qcow2 /home/martin/Downloads/Win11Sandbox.qcow2
# Create 100MB virtual disk to be mounted into vrt system.
qemu-img create -f qcow2 lic.img 100m
