# Omagotchi sandbox port

This review branch targets `jacob-vincent-mink/omagotchi:master`, not the original repository. It depends on the independent Rust sandbox runtime in [the Omarchy fork PR](https://github.com/jacob-vincent-mink/omarchy/pull/3).

## Changes to the plugin

The manifest requires private persistent storage so the pet's care, age and generation survive restart. Notifications, read-only desktop geometry, audio playback and the two package-query exec grants are optional and independently selected: the pet still works without alerts, sound, roaming or package observations. `audioPlayback` permits playback only: no microphone, system-output recording or direct PipeWire access. `checkupdates:pending-updates` admits no arguments; `pacman:orphan-packages` admits exactly `-Qdtq`. Download/install/remove flags and trailing arguments are not admitted. The checker refreshes its temporary package database; it does not install updates.

The host-facing calls change in `Service.qml`:

- `playSound()` uses owner-bound `runtime.start()` and `omarchy-plugin-play <local-file> <volume>`. FFmpeg decodes the bundled asset locally; Ward transfers only S16LE/48 kHz/stereo PCM to its admitted endpoint, while YOLO uses ordinary host audio. No staged host asset or per-file exec grant is needed.
- `notify()` uses the same owned helper route with `omarchy-plugin-request --notify <title> <body>`. Ward permission and identity still belong to the broker.
- The two package probes use `qs.Plugin.Process` with their original `checkupdates` and `pacman -Qdtq` argv. Omarchy's generic declared-command adapters select the named resources. Counts start unknown (`-1`); declined or failed queries retain the previous observation. A silent `pacman` exit 1 still means no matching orphans; stderr errors do not.

No plugin-owned PATH shim, replacement service or host adapter is added. Roaming imports shared `qs.Ward.Desktop`, backed by Ward's admitted observations or the host's one detached geometry observer in YOLO. The service and panel explain unavailable observations and disable departure when geometry is absent. The API exposes no compositor socket, titles, raw addresses or window-control methods. The original needs model, evolution, save/load, sprites, care handlers and roaming physics remain in place.

## Portable runtime

The same revision now runs in Ward or an explicitly trusted YOLO installation. Both use private paths from `shell.runtime`; process wrappers defer startup until runtime injection. YOLO remains arbitrary same-account code and does not enforce Ward permissions. The host-owned installation record chooses mode, not the manifest.

Production-code churn relative to the original `master` rises from 122 to 135 changed lines in the previous Ward-only port comparison (additions plus deletions; manifest, docs and tests excluded). The extra process/runtime plumbing removes worker-only calls and supports both modes. Unlike the other three winner ports, this individual port is slightly larger.

A fresh external private-display trial installed, enabled and opened this revision in both modes with disposable pet state. Both displayed the original egg and care panel; declined Ward package queries remained explicitly unavailable. These current render/startup checks do not rerun the historical care, roaming or audio matrices below, and never load the user's pet.

## Paths and permissions

The service takes its state directory from `shell.runtime.statePath` in both modes; the original save filenames and serialization stay unchanged. In Ward, persistent storage is mounted as the private worker home. In YOLO, the runtime provides private paths without changing the desktop shell's global home. `OMARCHY_PLUGIN_PATH` and `OMARCHY_PLUGIN_DATA` remain host-side exec argument tokens when those resources are admitted, not paths for the local save writer or sound decoder. They do not mount the rest of the host filesystem into the worker.

The manifest requests permissions; it does not approve them. Select `--allow-storage` to satisfy the required persistence request; denying it prevents activation of this revision. Select `--allow-audio-playback` separately to allow sounds. Neither capture permission is requested or needed. Declined playback has no reachable playback endpoint and the helper fails without a host stream. Ward permits two concurrent playback streams per plugin, with bounded buffering; stopping or revoking the plugin terminates its streams. Revoking storage removes access but retains saved data; reapproval restores access to the same pet identity. Ward's generic ephemeral-home behavior does not allow this storage-required revision to start without that grant. Package-query exec grants and notifications remain independent of playback.

## Verification and remaining work

The updated PCM path passed a fresh private-display trial with the matching native runtime and staged adapter. The original `playSound("pet")` decoded its bundled asset at volume 0.5 and delivered nonzero samples to a private synthetic PipeWire output, with no host-exec grant. Two bar placements shared the one service; removing one left the other active. With playback declined, the same sound attempt created no audio backend and the synthetic output stayed silent. Revocation removed every tracked process in the denied trial. The rendered egg panel was inspected. No real speakers or microphone were used.

The older audio observations below describe the former host-exec version; they are not a new all-assets matrix for PCM playback. The unrelated care, persistence and roaming evidence remains applicable to those unchanged paths.

The runtime's maintained storage test verifies real worker/controller restarts, atomic save replacement, an ungranted ephemeral home, and access to the original saved data after regranting. Exec tests verify tree matching, path resolution, denied arguments, job bounds and revocation. These are runtime tests, not proof of the complete pet experience.

The private-display trial loaded the original baby, room and needs with synthetic generation-three data and muted sound. With package exec access declined, both observations stayed unknown and the rendered status text fit without overlap. With both exact query leaves granted, the original Process handlers received successful observations from the installed tools. The Feed button changed hunger from 70 to zero and the original atomic save writer persisted it. A fresh worker then restored zero hunger, generation three, the baby stage and the mute setting from the two original files. None of these tests loads the user's pet.

The earlier `checkupdates` failure is resolved by Ward's generic host-job change: delegated child cgroups supervise jobs without replacing the host user/group namespace. The installed checker now returns the same exit status and output through the broker as a direct invocation, and the original QML handler updates its observation. This does not broaden its zero-argument grant or install system packages.

Sound was checked separately at volume 0.25 with fresh synthetic data. The original Feed action invoked the installed `pw-play` against the immutable staged `eat.wav`; a private PipeWire server, with no hardware modules or session manager, captured nonzero audio. With sound declined, the same Feed action completed and saved but created no playback stream and the capture remained silent. Both panel captures were inspected. The worker receives no PipeWire socket. This exposed a generic executable-alias bug in Ward: the runtime now preserves the requested invocation name while pinning and checking the resolved executable bytes, so installed symlink aliases work without a plugin-specific exception. This verifies one event's audio path, not every sound, real-speaker output, notifications triggered by this port or full care/evolution behavior.

The installed live bar now hosts a fresh, muted child test pet. Feed, affection, persistence across shell restarts, departure/beam-down, walking and return home were exercised without loading or replacing an existing pet save. Full live scrubbing and reliable pickup/drop still need their final desktop checks.

An external private-display trial with the admitted geometry adapter passed original platform climbing, riding a moved window, falling after removal, click-to-pet, pickup/drag/drop, high-fall stun and recovery, tired roaming nap/wake and return home. It waits for the rendered landed sprite before clicking; reading the model alone was too early for the matching frame and input mask. Held, stunned and sleeping render states were inspected. No production change was needed for these interactions.

A separate private trial scrubbed dirt from 40 to zero through the actual pointer handler and verified persistence. It seeded disposable age/care values immediately below and at growth boundaries, exercised both teen paths and all three adults through the original evolution function, and inspected their rendered sprites and decor. The original farewell button and confirmation sent the gremlin adult out, through its corner goodbye and off-screen walk, producing a saved generation-four egg with roaming disabled. These bounded trials do not simulate days of heartbeat timing, exercise every farewell sound variant or verify notification delivery. They used muted disposable state; the concrete experiments remain outside both repositories.

All sixteen original WAV/MP3 assets subsequently produced nonzero audio through the selected `pw-play` leaf at volume 0.25 into private PipeWire capture. Each playback graph identified the expected immutable staged asset, including both petting and all farewell variants. The private servers had no hardware modules or session manager. Declining the leaf produced no playback node and an entirely silent capture. This matrix verifies asset transport and decoding; the original Feed event was tested separately above, and timing of every event or physical speaker output is not implied.

The original hatch, ace farewell and corrupt-save notification callbacks passed through Ward and the real notification helper into a private D-Bus recorder. The received records carried the fixed plugin identity, text-only content, no actions, low urgency and a five-second expiry. Declining notifications produced no record without blocking evolution. The ace farewell also produced its next-generation egg. No notification was sent to the live desktop.

Remaining live interaction and physical output checks still prevent a full feature-parity claim. Gesture-gated Tab/Backtab panel switching has passed Ward's synthetic integration test, but its latest runtime build is not yet deployed on the live desktop. The concrete experiments remain external; this branch commits their results, not a plugin-specific test harness.

Run `node tests/probes.test.mjs` for focused regression checks of the actual QML handler bodies, fixed manifest requests, unknown/empty results and retained failure state. The native parser also accepted the port manifest. These checks do not replace actual broker/worker or visual testing.
