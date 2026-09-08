# Omagotchi sandbox port

This review branch targets `jacob-vincent-mink/omagotchi:master`, not the original repository. It depends on the independent Rust sandbox runtime in [the Omarchy fork PR](https://github.com/jacob-vincent-mink/omarchy/pull/3).

## Changes to the plugin

The manifest adds three optional requests: notifications, private persistent storage, and an exec grant named `pw-play`. The exec tree admits only `--volume`, a bounded volume, and one of the exact sixteen shipped sound filenames under `$OMARCHY_PLUGIN_PATH/sounds/`. It does not admit arbitrary commands or paths.

Two source functions change in `Service.qml`:

- `playSound()` sends `/bootstrap --exec pw-play --volume <volume> <assets>/sounds/<file>`. The worker has no PipeWire socket; the broker checks the selected exec tree and runs the admitted host command in a supervised job.
- `notify()` sends `/bootstrap --notify <title> <body>`. Notification permission and identity belong to the host broker; the worker does not invoke an unprovided desktop helper.

No PATH shim, replacement service, or plugin-specific host adapter is added. The original needs model, save/load code, sprites, panel and bar widget remain unchanged.

## Paths and permissions

`OMARCHY_PLUGIN_PATH` is the host-real path to the worker's staged read-only assets, available when an exec grant is admitted. `OMARCHY_PLUGIN_DATA` is the host-real path to its persistent per-identity directory, available only with storage access. Both can be used as tokens in manifest exec trees; the broker resolves them and rejects traversal. The storage directory is mounted at the worker's private home, so the existing save/load paths need no source changes. These host path strings do not mount the rest of the host filesystem into the worker.

The manifest requests capabilities; it does not approve them. The user must select the relevant grants. With no admitted exec grant, no asset path is provided and sound is skipped. A rejected sound leaf is denied at the broker. Revoking storage removes access but retains saved data; subsequent ungranted workers receive an ephemeral home.

## Verification and remaining work

The runtime's maintained storage test verifies real worker/controller restarts, atomic save replacement, an ungranted ephemeral home, and access to the original saved data after regranting. Exec tests verify tree matching, path resolution, denied arguments, job bounds and revocation. These are runtime tests, not proof of the complete pet experience.

Earlier private-display preparation rendered the original egg, needs, room and panel without loading the user's pet. Actual audible playback, notifications triggered by this port, and restart recovery through the original pet UI still need end-to-end verification.

The package probes (`checkupdates` and `pacman -Qdtq`) have no host observation grants yet. Their fallback zero values must not be presented as real package state. Roaming still needs detached monitor/window geometry and correct host placement. Real bar-slot placement and full desktop acceptance remain unfinished. This is a draft integration port, not a feature-parity claim.
