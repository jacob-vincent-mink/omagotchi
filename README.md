# Omagotchi

A 1-bit desktop pet for [Omarchy](https://omarchy.org), in the spirit of the
1997 originals. It lives in your bar — and its wellbeing is your machine's
maintenance. There is no fake game loop: every need maps to a real, universal
Arch signal, and every care action is real system care.

| Need | Rises | You fix it by |
| --- | --- | --- |
| Hunger | over time — faster while updates are pending | the Feed button (only when it's home) |
| Hygiene | over time — faster while orphaned packages linger | pressing and **scrubbing it with your mouse** in its room — it wobbles, soap sparkles fly |
| Energy | over time — faster while roaming | letting it nap: it falls asleep on its own when exhausted, wherever it is |
| Fun | over time | letting it out to roam |
| Affection | over time | petting it — each click takes a bite out of the need, so a lonely pet wants a proper cuddle session, not a single tap |

When several needs complain at once, the emote bubble above its head cycles
through them. Care happens at home: while it's out roaming, the panel shows
an empty room and feeding/washing wait until you call it back.

Needs rise with active shell time, never with hardware performance: the pet
plays the same on a ten-year-old laptop as on a fresh build, and there is
always something to do. Your actual system state only flavors the pace —
pending updates make it hungrier faster, orphans make it grubbier faster.

## Growth

The pet grows through the classic stages — egg, baby, child, teen, adult — as
a tribute to the 1997 growth charts (structure only: every creature here is
original). Age counts **active shell minutes**, so a machine that sleeps does
not starve anyone, and the branch you get depends on your average care over
the stage:

- The egg hatches after 5 minutes; the baby becomes a child after 65 more
  (yes, those numbers).
- After ~8 active hours the child becomes a **neat teen** (average care ≥ 55)
  or a **scruffy teen**.
- After ~16 more, the teen settles into one of three adults: the **ace**, the
  **easygoing one**, or the **gremlin** — a scruffy teen can never quite reach
  ace, just like in the old charts.

Evolutions are announced with a desktop notification. Care average resets at
each stage, so a rough childhood can still turn into a fine adulthood.

Click "Go play" and the pet leaves its panel to wander the bottom edge of the
screen — and to **climb your windows**: any window whose top border leaves
enough headroom becomes a platform. It walks to a window's side, scales the
wall, strolls along the top, rides the window if you move it, and hops back
down (or falls, if you close the window under its feet). Window geometry comes
from the Hyprland IPC through Quickshell; the overlay is fully click-through
except the pet itself, which you can pet mid-stroll. Roaming keeps boredom
down, but it is tiring — an exhausted pet naps on the spot, wherever it is.

You can also **pick it up**: press and drag to carry it by the scruff (legs
wiggling in protest), then drop it anywhere — on a window top, on the floor —
and it falls and lands where you left it. A plain click is still a petting.

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
strings, and none of them elevate privileges:

- `checkupdates` — read-only, every 30 minutes (need-pace flavor)
- `pacman -Qdtq` — read-only, every 5 minutes (need-pace flavor)
- `omarchy-notification-send` — evolution announcements

Window positions for climbing are read from the Hyprland IPC socket via
Quickshell's Hyprland module — no shell commands involved. No network access,
no credentials, no daemons, no sudoers rules.

## Drawing new sprites

Sprites are plain text grids in `tools/sprites/*.txt` — 16 lines of 16
characters, `X` for a pixel, `.` for transparency. Regenerate the PNGs with
`tools/gen-sprites.sh` (needs ImageMagick) and commit both. Pull requests with
new animations are very welcome: no drawing software required, any editor
works.

## License

MIT — see [LICENSE](LICENSE).
