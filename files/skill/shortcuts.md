<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->
# Keyboard shortcuts

Configured by @APP_NAME@. Super+K shows this list on screen.

| Group | Shortcut | Action |
|---|---|---|
@TABLE@

## How they are set

- App shortcuts are custom keybindings at
  `/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/@APP_ID@-N/` that run
  `@LAUNCHER@ <terminal|files|browser|agent|monitor|dictation|emoji|keys|welcome|zen>`.
- The rest are GNOME keys such as `/org/gnome/desktop/wm/keybindings/close`.
- @APP_NAME@ re-applies them on every run and `--update`, and they win: a GNOME key or one of
  the user's own custom shortcuts that uses the same keys loses them (the run warns about it).
  Custom shortcuts on other keys are kept. Never give the user's shortcuts Kinobu's keys: pick
  free ones. For a permanent change, edit the SHORTCUTS table of the @APP_NAME@ script.

```bash
dconf dump /org/gnome/settings-daemon/plugins/media-keys/
gsettings get org.gnome.desktop.wm.keybindings close
```
