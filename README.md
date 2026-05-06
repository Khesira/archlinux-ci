# Arch Linux CI/CD - Automated Cloud Image Builder

This repository provides an automated pipeline to build a customized, bootable Arch Linux Cloud Image (`.qcow2`) using GitHub Actions.  
The resulting image is optimized for virtualization platforms like Proxmox, QEMU, or KVM and features full Cloud-Init support.

## Features

- **Automated Builds**: Triggered by Git tags, running in a privileged Docker environment.
- **Optimized Image**: Converts raw builds to compressed `qcow2` format.
- **Cloud-Init Ready**: Pre-installed `cloud-init`, `qemu-guest-agent`, and `cloud-guest-utils`.
- **UEFI Boot**: Configured with `systemd-boot` and proper EFI system partitions.
- **Portable UUIDs**: Uses strict UUID-based mounting in `fstab` and bootloader entries to ensure bootability across different virtual hardware.
- **Unified Releases**: Automatically uploads the latest build to GitHub Releases with a static download link for easy infrastructure automation.

## Project Structure

- `build.sh`: The core build script. It handles disk partitioning (GPT), formatting, `pacstrap`, and system configuration within a chroot environment.
- `release.sh`: A local helper script to automate version tagging based on the current date and build count.
- `.github/workflows/build.yml`: The GitHub Actions workflow that orchestrates the build process.

## Getting Started

### Prerequisites

- For local builds: A Linux environment with `qemu-img`, `sfdisk`, and `arch-install-scripts`.
- For CI: A GitHub repository with Actions enabled.

### Customization

To set your own timezone, locale, keymap, hostname, and preferred image size, edit copy the .env.exampe to .env and modify the variables accordingly.
```bash
cp .env.example .env
```

### Building Locally

To build the image manually on your machine:

```bash
sudo ./build.sh
```

---

# Automation & Tagging

To trigger a new build and release, use the provided release script. It automatically calculates the next version tag for the current day (e.g., release-04-25-2026-01):

```bash
chmod +x release.sh
./release.sh
```

---

# Usage in Virtualization

## Proxmox / KVM

You can download the latest image directly to your storage node using the static GitHub release link:

```
wget https://github.com/Khesira/archlinux-ci/releases/latest/download/arch-linux-x86_64-cloudinit-ext4.qcow2
```

---

# Cloud-Init Configuration

Since this image is prepared for Cloud-Init, you can provide User-Data, Meta-Data, and Network-Config via your virtualization platform to:

- Set up SSH keys.
- Create user accounts.
- Configure network interfaces (IPv4/IPv6).
- Run post-installation commands.

---

# Technical Details

- File System: Ext4 (Root), VFAT (EFI).
- Initramfs: Customized mkinitcpio hooks using systemd and block for faster and more reliable booting in virtualized environments.
- Networking: Managed by systemd-networkd and systemd-resolved.

---

# Debugging

If you encounter boot issues, check the following:

- UUIDs: Ensure cat /etc/fstab and the bootloader entries match the actual partition UUIDs (provided by blkid).
- Initramfs: The build process ensures VirtIO drivers are included to prevent "waiting for device" errors in QEMU/Proxmox.

---
Created with Arch Linux focus. Simple, clean, and automated.
