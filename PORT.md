# Omagotchi sandbox port

This review branch targets `jacob-vincent-mink/omagotchi:master`, not the original repository. It depends on the independent Rust sandbox runtime in [the Omarchy fork PR](https://github.com/jacob-vincent-mink/omarchy/pull/3).

## Changes to the plugin

The manifest requests optional notifications, private persistent storage, and three independently selected exec grants. `pw-play` admits only `--volume`, a bounded volume, and one of the exact sixteen shipped sound filenames under `$OMARCHY_PLUGIN_PATH/sounds/`. `checkupdates:pending-updates` admits no arguments; `pacman:orphan-packages` admits exactly `-Qdtq`. Download/install/remove flags and trailing arguments are not admitted. The checker refreshes its temporary package database; it does not install updates.

The host-facing calls change in `Service.qml`:

- `playSound()` sends `/bootstrap --exec pw-play --volume <volume> <assets>/sounds/<file>`. The worker has no PipeWire socket; the broker checks the selected exec tree and runs the admitted host command in a supervised job.
- `notify()` sends `/bootstrap --notify <title> <body>`. Notification permission and identity belong to the host broker; the worker does not invoke an unprovided desktop helper.
- The two package probes explicitly call `/bootstrap --exec`. Counts start unknown (`-1`); declined or failed queries retain the previous observation rather than inventing an empty list. The panel labels an unavailable initial observation. A silent `pacman` exit 1 still means no matching orphans; an error with stderr does not.

No PATH shim, replacement service, or plugin-specific host adapter is added. The original needs model, save/load code, sprites, panel and bar widget remain unchanged.

## Paths and permissions

`OMARCHY_PLUGIN_PATH` is the host-real path to the worker's staged read-only assets, available when an exec grant is admitted. `OMARCHY_PLUGIN_DATA` is the host-real path to its persistent per-identity directory, available only with storage access. Both can be used as tokens in manifest exec trees; the broker resolves them and rejects traversal. The storage directory is mounted at the worker's private home, so the existing save/load paths need no source changes. These host path strings do not mount the rest of the host filesystem into the worker.

The manifest requests capabilities; it does not approve them. The user must select the relevant grants. With no admitted exec grant, no asset path is provided and sound is skipped. A rejected sound leaf is denied at the broker. Revoking storage removes access but retains saved data; subsequent ungranted workers receive an ephemeral home.

## Verification and remaining work

The runtime's maintained storage test verifies real worker/controller restarts, atomic save replacement, an ungranted ephemeral home, and access to the original saved data after regranting. Exec tests verify tree matching, path resolution, denied arguments, job bounds and revocation. These are runtime tests, not proof of the complete pet experience.

The current private-display trial loaded the original baby, room and needs with synthetic generation-three data and muted sound. With package exec access declined, both observations stayed unknown and the rendered status text fit without overlap. With the exact orphan query granted, the original Process handler received the installed pacman's result. The Feed button changed hunger from 70 to zero and the original atomic save writer persisted it. A fresh worker then restored zero hunger, generation three, the baby stage and the mute setting from the two original files. None of these tests loads the user's pet. Actual audible playback, notifications triggered by this port and full care/evolution behavior remain unverified.

`checkupdates` has a confirmed runtime compatibility failure, despite its exact grant: it succeeds outside the host job, but its downloader cannot chown a temporary directory to the download user inside the job's user namespace (`Invalid argument`). The underlying command was reproduced against a separate test database; no system packages were changed. The port correctly keeps the result unavailable, but successful update observation is not yet proved. Do not remove the job boundary or broaden the command grant just to make that check pass.

Roaming still needs detached monitor/window geometry and correct host placement. Real bar-slot placement and full desktop acceptance remain unfinished. This is a draft integration port, not a feature-parity claim.

Run `node tests/probes.test.mjs` for focused regression checks of the actual QML handler bodies, fixed manifest requests, unknown/empty results and retained failure state. The native parser also accepted the port manifest. These checks do not replace actual broker/worker or visual testing.
