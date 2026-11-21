<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->
# Hardware (always check it live)

| What | Command |
|---|---|
| Summary | `fastfetch`, `hostnamectl` |
| CPU | `lscpu` |
| Memory | `free -h` |
| GPUs and their drivers | `lspci -nnk \| grep -A3 -E 'VGA\|3D\|Display'` |
| NVIDIA GPU, VRAM, load | `nvidia-smi` (only with the NVIDIA driver) |
| Vulkan / OpenGL | `vulkaninfo --summary`, `glxinfo -B` |
| Disks and partitions (read-only) | `lsblk -f`, `df -h` |
| USB devices | `lsusb` |
| Network | `ip -br a`, `nmcli device` |
| Kernel | `uname -r` |
| Secure Boot | `mokutil --sb-state` |
| Live usage | Mission Center (Ctrl+Shift+Esc), `top` |

## Drivers

```bash
ubuntu-drivers list            # the drivers Ubuntu recommends for this hardware
sudo ubuntu-drivers install    # install them
```

Reboot after installing drivers. With Secure Boot on, a new driver may ask to enrol a MOK key at
the next start.
