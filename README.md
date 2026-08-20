# Omagotchi

A 1-bit desktop pet for [Omarchy](https://omarchy.org), in the spirit of the
1997 originals. It lives in your bar — and its wellbeing is your machine's
maintenance. There is no fake game loop: every need maps to a real, universal
Arch signal, and every care action is real system care.

| Need | Rises with | You fix it by |
| --- | --- | --- |
| Hunger | pending official updates (`checkupdates`) | feeding it = running the Omarchy update |
| Grooming | orphaned packages (`pacman -Qdtq`) | grooming it = pruning the orphans |
| Sleep | uptime since last boot | rebooting once in a while |
| Affection | time since you last petted it | clicking it, in the bar panel or on the loose |

Needs rise with time and package churn, never with hardware performance: the
pet plays the same on a ten-year-old laptop as on a fresh build.

Click "Go play" and the pet leaves its panel to wander along the bottom edge
of the screen (above your bar if the bar lives down there — layer-shell
exclusive zones handle that automatically). The strip is fully click-through
except the pet itself, which you can pet mid-stroll. A roaming pet never gets
more than half-lonely.

The sprites are 16×16, one-bit, and tinted live with your theme's colors —
switch themes and the pet molts.

## Install

Standard Omarchy plugin install:

```bash
omarchy plugin add https://github.com/SLcode777/omagotchi --enable
```

## Remove

```bash
omarchy plugin remove slcode777.omagotchi
```

State files (safe to delete) live at:

- `~/.local/state/omarchy/omagotchi-settings.json`
- `~/.local/state/omarchy/omagotchi-state.json`

## Dependencies

- `pacman-contrib` for `checkupdates` (preinstalled on Omarchy)
- `coreutils`, `pacman`, `systemd` (base system)

## What it executes, exactly

All commands run with fixed argument lists, never through interpolated shell
strings, and none of them elevate privileges by themselves:

- `checkupdates` — read-only, every 30 minutes
- `pacman -Qdtq` — read-only, every 5 minutes
- `cat /proc/uptime` — read-only, every 5 minutes
- Feed: `omarchy-launch-floating-terminal-with-presentation omarchy-update` —
  opens the standard Omarchy update in a terminal; you drive it and type your
  own password there
- Groom: `omarchy-launch-floating-terminal-with-presentation "sudo pacman -Rns $(pacman -Qdtq)"`
  — a fixed literal handed to the same terminal wrapper; you confirm in the
  terminal

No network access of its own, no credentials, no daemons, no sudoers rules.

## Drawing new sprites

Sprites are plain text grids in `tools/sprites/*.txt` — 16 lines of 16
characters, `X` for a pixel, `.` for transparency. Regenerate the PNGs with
`tools/gen-sprites.sh` (needs ImageMagick) and commit both. Pull requests with
new animations are very welcome: no drawing software required, any editor
works.

## License

MIT — see [LICENSE](LICENSE).
