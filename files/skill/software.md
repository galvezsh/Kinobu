<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->
# Software

## Package sources, in order of preference

1. Ubuntu repositories: `apt search <name>`, `sudo apt install <pkg>`, `sudo apt remove <pkg>`
2. Snap: `snap find <name>`, `sudo snap install <name>` (IDEs need `--classic`)
3. Official vendor `.deb`: `sudo apt install ./file.deb` (resolves dependencies)

Check what is installed: `dpkg -l | grep <name>`, `snap list`, `command -v <tool>`.

Always installed by the setup: GNOME Contacts, Calendar, Weather, Clocks, Tweaks, Characters
and Geary, plus Node.js, build-essential, GraalVM and the command line tools. The rest was
chosen in menus at setup.

## Third-party repositories

In `/etc/apt/sources.list.d/`, only for the apps chosen at setup: Helium, Spotify, Visual Studio
Code, Cursor and Docker (keys in `/usr/share/keyrings/` and `/etc/apt/keyrings/`). Google Chrome's own
`.deb` adds its repository itself. Firefox (snap) always stays installed.

## Optimised packages

When the CPU supports x86-64-v3, `/etc/apt/apt.conf.d/99enable-amd64v3` makes APT prefer
packages built for it. Remove that file to go back to plain amd64 packages.

## Updating everything

```bash
sudo apt update && sudo apt full-upgrade
sudo snap refresh
```

Security updates install themselves (`unattended-upgrades`). Reboot after kernel or driver
updates (`/run/reboot-required` exists when needed).

## Docker

Installed only if it was chosen at setup (`command -v docker`). If not, the simplest way is to
run the Kinobu setup again (`bash kinobu.sh --install`) and tick Docker Engine. Otherwise add Docker's official
repository (docs.docker.com/engine/install/ubuntu) and run:

```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Then use `sudo docker ...`. Adding the user to the `docker` group avoids sudo but is
equivalent to passwordless root, so only do it if the user explicitly asks.
GPU access inside containers needs the NVIDIA Container Toolkit as well.

## Virtual machines

Offered at setup: GNOME Boxes (VMs run as the user: `virsh -c qemu:///session list --all`,
disks in `~/.local/share/gnome-boxes/images/`) and virt-manager (system service:
`virsh -c qemu:///system list --all`, disks in `/var/lib/libvirt/images/`, NAT network
`default`). Both use QEMU with KVM. The user is kept out of the `libvirt` group on purpose
(it is close to root), so virt-manager asks for the password. Check KVM with `ls -l /dev/kvm`.
Never pass host disks or devices (USB, GPU) to a VM without asking the user. If Boxes says KVM
is missing right after installing it, quit it fully (it keeps running in the background) or log
out and in.

## Java and IDEs

Handy (voice dictation, always installed: Zen listens through it) is a `.deb` from its GitHub
releases and LM Studio a `.deb` from lmstudio.ai: they are not in any APT repository, so
`apt upgrade` does not update them (LM Studio updates itself; `--update` installs the new Handy
release). Zen's voices and models live in `~/.local/share/kinobu/zen/` (each user's own) and are refreshed by
`--update` (Python packages through `uv`, Qwen3-TTS through llama.cpp's Vulkan build).

GraalVM JDK lives in `/opt/java/` (`echo $JAVA_HOME`). The JetBrains IDEs, Antigravity IDE,
Android Studio, Eclipse, Blender, Mission Center and OnlyOffice are snaps when they were chosen (`snap list`). Node.js and npm come from APT; global npm packages go to `~/.local`
(no sudo). Python tooling: `uv` / `uvx` in `~/.local/bin`.
