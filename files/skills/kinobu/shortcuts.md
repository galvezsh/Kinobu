<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->
# Keyboard shortcuts

Set by @APP_NAME@. Super+K shows them on screen.

| Group | Shortcut | Action |
|---|---|---|
@TABLE@

## How they work

- App shortcuts are custom keybindings at
  `/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/@APP_ID@-N/`, running
  `@LAUNCHER@ <action>`; the rest are GNOME keys such as `/org/gnome/desktop/wm/keybindings/close`.
- @APP_NAME@ applies them again on every update and they win: a GNOME key or a user's shortcut on
  the same keys loses them. So give the user's own shortcuts free keys (Settings > Keyboard >
  Custom Shortcuts): they are kept.

```bash
dconf dump /org/gnome/settings-daemon/plugins/media-keys/
gsettings get org.gnome.desktop.wm.keybindings close
```
