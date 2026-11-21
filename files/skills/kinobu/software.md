<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->
# Software

## Where software comes from, in order

1. Ubuntu's repositories: `apt search <name>`, `sudo apt install <pkg>`, `sudo apt remove <pkg>`
2. Snap: `snap find <name>`, `sudo snap install <name>` (IDEs need `--classic`)
3. The vendor's official `.deb`: `sudo apt install ./file.deb` (it resolves dependencies)

What is installed: `dpkg -l | grep <name>`, `snap list`, `command -v <tool>`. Most apps were
chosen in menus at setup: never assume one is there.

Third-party repositories (`/etc/apt/sources.list.d/`, keys in `/usr/share/keyrings/` and
`/etc/apt/keyrings/`) exist only for the apps chosen at setup. Google Chrome's `.deb` adds its own.
With an x86-64-v3 CPU, `/etc/apt/apt.conf.d/99enable-amd64v3` makes APT prefer packages built for
it; removing that file goes back to plain amd64 ones.

## Updating

```bash
sudo apt update && sudo apt full-upgrade
sudo snap refresh
```

Security updates install themselves. After a kernel or driver update, `/run/reboot-required`
exists: reboot. Handy and LM Studio are `.deb` files from their vendors, outside APT: LM Studio
updates itself, @APP_NAME@'s update installs Handy's new releases.

## Docker

Check with `command -v docker`. To add it, use Docker's official repository
(docs.docker.com/engine/install/ubuntu), then:

```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Use `sudo docker …`. The `docker` group avoids sudo but equals passwordless root: only if the user
explicitly asks. GPUs inside containers also need the NVIDIA Container Toolkit.

## Virtual machines

virt-manager with QEMU and KVM, when chosen at setup: `virsh -c qemu:///system list --all`, disks
in `/var/lib/libvirt/images/`, NAT network `default`. @APP_NAME@ never adds the user to the
`libvirt` group (close to root), so virt-manager asks for the password. Never pass host disks or
devices (USB, GPU) to a VM without asking. If KVM is missing right after installing, log out and in.

## Languages and IDEs

- Java: GraalVM in `/opt/java/` (`echo $JAVA_HOME`).
- Node.js and npm from APT; global npm packages go to `~/.local` (no sudo).
- Python: `python3` with `pip` and `venv`; `uv` and `uvx` in `~/.local/bin`.
- IDEs (JetBrains, Android Studio, Eclipse…) are snaps when chosen: `snap list`.
