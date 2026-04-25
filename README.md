# Arch Linux Cloud-Init Image Builder

This project provides a Bash script for building a bootable **Arch Linux cloud image** in both `raw` and `qcow2` format.

The generated image is intended for virtualized environments such as **QEMU/KVM**, **libvirt**, **Proxmox**, or other platforms that support cloud-init based provisioning.

## Features

The script automatically creates an Arch Linux image with:

- GPT partition table
- EFI System Partition
- ext4 root filesystem
- `systemd-boot` bootloader
- Linux kernel
- Intel and AMD microcode
- `cloud-init`
- OpenSSH
- QEMU Guest Agent
- `cloud-guest-utils`
- `systemd-networkd`
- `systemd-resolved`
- German console keymap
- English UTF-8 locale
- Default hostname: `archlinux-ci`

The image is cleaned up before export by removing package caches, logs, temporary files, and zero-filling free space to improve compression.

## Requirements

Run the script on an Arch Linux system or an Arch-based environment.

Required host packages:

- `bash`
- `arch-install-scripts`
- `dosfstools`
- `e2fsprogs`
- `util-linux`
- `qemu-img`
- `systemd`
- `pacman`

Install the required packages with:

bash sudo pacman -S arch-install-scripts dosfstools e2fsprogs qemu-img util-linux systemd

## Usage

Make the script executable:

Run it with `sudo`:

bash sudo ./build.sh

The script must be started with root privileges because it creates loop devices, partitions disks, formats filesystems, mounts filesystems, and performs a chroot installation.

## Output

After a successful run, the following files are created:

archlinux-cloud-init-ext4-MM-DD-YYYY.raw  
archlinux-cloud-init-ext4-MM-DD-YYYY.qcow2

Example:

archlinux-cloud-init-ext4-04-25-2026.raw  
archlinux-cloud-init-ext4-04-25-2026.qcow2

The `raw` image is created first and then converted into a compressed `qcow2` image.

## Image Size

The default image size is: text 20G

You can change it in `build.sh` by modifying:

For example:

IMAGE_SIZE=40G

## Installed Packages

The generated image includes the following packages:

- `base`
- `linux`
- `amd-ucode`
- `intel-ucode`
- `cloud-init`
- `qemu-guest-agent`
- `cloud-guest-utils`
- `openssh`
- `efibootmgr`
- `vim`

## Default Configuration

| Setting | Value |
|---|---|
| Console keymap | `de-latin1` |
| Locale | `en_US.UTF-8 UTF-8` |
| Time zone | `Europe/Berlin` |
| Hostname | `archlinux-ci` |
| Bootloader | `systemd-boot` |
| Root filesystem | `ext4` |
| Image formats | `raw`, `qcow2` |
| Default image size | `20G` |

## Enabled Services

The image enables the following services:

- `systemd-networkd.service`
- `systemd-resolved.service`
- `cloud-init.target`
- `cloud-init-local.service`
- `cloud-init-main.service`
- `cloud-config.service`
- `cloud-final.service`
- `sshd`
- `qemu-guest-agent`

## Partition Layout

The image uses a GPT partition table.

| Partition | Type | Size | Purpose |
|---|---|---|---|
| 1 | EFI System Partition | 524288 sectors, approximately 256 MiB | Boot partition |
| 2 | Linux root partition | Remaining disk space | Root filesystem |

## Bootloader

The image uses `systemd-boot`.

The loader configuration is written to: /boot/loader/loader.conf

The Arch Linux boot entry is written to: /boot/loader/entries/arch.conf

The root filesystem is referenced by UUID in the boot entry.

## Cloud-Init

The image includes `cloud-init` and is ready for first-boot provisioning.

Typical cloud-init use cases include:

- Creating users
- Injecting SSH keys
- Configuring networking
- Setting the hostname
- Installing additional packages
- Running initialization commands on first boot

> Note: The image does not define a default user or password. Users and SSH keys should be provided through cloud-init.

## Example: Run with QEMU

bash qemu-system-x86_64
-enable-kvm
-m 2048
-cpu host
-drive file=archlinux-cloud-init-ext4-MM-DD-YYYY.qcow2,format=qcow2
-net nic
-net user,hostfwd=tcp::2222-:22
-bios /usr/share/edk2/x64/OVMF.fd

Then connect via SSH, assuming a user was provisioned through cloud-init:

bash ssh -p 2222 user@localhost

## Example: Import into Proxmox

Copy the generated `qcow2` image to your Proxmox host and import it:

bash qm create 9000 --name archlinux-cloudinit --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 qm importdisk 9000 archlinux-cloud-init-ext4-MM-DD-YYYY.qcow2 local-lvm qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0 qm set 9000 --boot c --bootdisk scsi0 qm set 9000 --ide2 local-lvm:cloudinit qm set 9000 --serial0 socket --vga serial0 qm template 9000

You can then clone the template and configure the VM using Proxmox Cloud-Init settings.

## Cleanup

During image creation, the script performs cleanup inside the image:

- Clears the package cache
- Removes log files
- Removes temporary files
- Zero-fills free space before converting to `qcow2`

This helps reduce the final compressed image size.

## Troubleshooting

### Script was not started with sudo

Error: This script must be started using sudo

Solution: sudo ./build.sh

### `pacstrap` not found

Install `arch-install-scripts`: sudo pacman -S arch-install-scripts

### `qemu-img` not found

Install QEMU image tools: sudo pacman -S qemu-img

Depending on your system, `qemu-img` may also be included in a broader `qemu` package.

### Loop device is still attached

If the script is interrupted, a loop device may remain attached.

List loop devices: losetup -a  
Detach the relevant loop device: sudo losetup -d /dev/loopX

Replace `/dev/loopX` with the actual loop device.

### Mount directory is still mounted

If the script is interrupted, unmount the filesystems manually:

sudo umount mnt/boot sudo umount mnt

## Notes

- Run the script only on a system where you understand the impact of loop devices, partitioning, and mounting.
- The generated image is designed for UEFI boot.
- The image does not contain preconfigured credentials.
- Access should be configured through cloud-init.
- Existing output files with the same name may be overwritten or cause command failures depending on the current filesystem state.

## License

Add your project license here.