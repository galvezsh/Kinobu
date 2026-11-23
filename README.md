<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/kinobu-dark.svg">
    <img alt="Kinobu" src="assets/kinobu-light.svg" width="640">
  </picture>
</p>

# Kinobu

> **Stable roots, endless growth.**

**The agentic Ubuntu desktop.** One script that turns a fresh Ubuntu 26.04 LTS into a computer ready to work with AI: the apps, the development tools, AI agents truly integrated into the system, a voice assistant and a familiar, good-looking desktop where everything works together from the first minute.

By **Alberto Gálvez** ([agalvezsh](https://github.com/agalvezsh)) · version **0.3.2** (in development) · [AGPL-3.0-or-later](LICENSE)

> [!WARNING]
> Kinobu 0.3.2 is in development. It has been installed and updated on its author's computer, and otherwise run in simulation (see the [Roadmap](ROADMAP.md)): do not use it on a computer you care about yet.

## Why it exists

Installing an AI agent is easy. **Truly integrating it into the system** is not: it has to be set up to measure, and almost nothing gives you that done, and done well.

[Omarchy](https://omarchy.org) does, but on Arch and Hyprland: a base that changes every day and a desktop you have to learn from scratch. Kinobu brings the idea to a base that is **stable for years** and to a desktop **you already know**, made for real work and programming, with no fear of an update breaking it.

## The name

**Ki** + g**no**me + u**bu**ntu = **Kinobu**

Like Omarchy, the name says what it is made of: **GNOME** and **Ubuntu** are the base. *Ki* means "tree" in Japanese and *nobu*, "to grow": **the tree grows**. A tree is not replaced: it keeps its roots and its trunk and grows on them. Kinobu does not reinvent Ubuntu or GNOME; it improves what already works.

The logo is a trunk seen from above: the thick outer ring is the base, the inner rings are what Kinobu adds, and the centre takes your accent colour. Each major version will be a new ring, named after a fruit.

## What you get

- **A desktop you already know.** A dock at the bottom, four workspaces, shortcuts that are easy to guess and **Trail**, the cheat sheet on **Super+K**.
- **AI agents, integrated.** Claude Code opens with **Super+Shift+Enter**, knows this system through Kinobu's skill, builds programs the right way (git checkpoints, a context that survives a new conversation, an architecture that can grow), can ask a read-only investigator for help and notifies you when it finishes or needs your permission. More agents will follow once this one is complete.
- **Talk to your computer.** **Willow** (Super+Shift+Space) listens and answers aloud with voices that run on your computer. It changes the volume, the theme or the music, sets reminders, looks at your screen when you ask, checks things in the background and hands real work to your agent. **Handy** (Super+Space) types what you dictate.
- **Your look, your way.** **Seasons** changes the whole look at once with eight themes (Kinobu, Tokyo Night, Catppuccin with Dracula, Nord, Gruvbox, Rosé Pine, Windows and macOS), each with at least two dark and two light palettes: app colours, icons, cursor, terminal and window buttons. Pick your own icons, cursor, fonts and a wallpaper per workspace, and they stay when you change themes; make a theme of your own from any other and change its colours. The login screen wears Kinobu's own background, without Ubuntu's logo, Kinobu's small rings turn under the maker's logo while the computer starts, and a soft chord greets you when you log in (or a sound of your own, or none). With Papirus icons, the folders take the theme's colour.
- **Easy to follow.** A quick check of your computer, menus to choose your software and a clean screen that shows each step, made for people who are new to the terminal.
- **For every user of the computer.** Kinobu installs itself once for the whole system; each user gets their own part at their first login.
- **Done right, then left alone.** Run it again at any time: it only does what is missing. It saves your GNOME settings first, logs every run and never touches disks or partitions.

## Quick start

```bash
git clone <this-repo> kinobu
cd kinobu
bash kinobu.sh --install
```

Run it **as your normal user** (not with `sudo`), **from a terminal in the GNOME desktop**, on Ubuntu 26.04 LTS (amd64) with about 25 GB free and an internet connection. It checks the computer, lets you choose your software, tells you what it is going to do and asks before changing anything.

| Command | What it does |
|---|---|
| `bash kinobu.sh` | Shows the help |
| `bash kinobu.sh --check` | Only checks this computer; nothing is changed |
| `bash kinobu.sh --install` | Sets this computer up |
| `bash kinobu.sh --update` | After `git pull`: updates everything and keeps your look |
| `bash kinobu.sh --manual` | Lets you choose which parts to run |
| `kinobu --user` | Sets Kinobu up for another user (runs by itself at their first login) |

## Learn more

- **[Guide](GUIDE.md)**: how it works inside, what each part does, the files it touches and how to undo things.
- **[Roadmap](ROADMAP.md)**: what is still to do.
- **[Changelog](CHANGELOG.md)**: what changed in each version.
- **[Licence](LICENSE)**: GNU AGPL-3.0-or-later.
