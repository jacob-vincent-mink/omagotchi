#!/bin/bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MANIFEST="$ROOT/manifest.json"

jq -e '
  .schemaVersion == 2 and
  .id == "slcode777.omagotchi" and
  .runtime.apiVersion == 1 and
  .runtime.qml == "Panel.qml" and
  .runtime.surfaceQml == {panel: "Panel.qml", barWidget: "BarWidget.qml", roam: "RoamWindow.qml"} and
  .author == "SLcode777" and
  .license == "MIT" and
  .description == "A 1-bit desktop pet in your bar, in the spirit of the 1997 originals: feed it, scrub it clean, cuddle it, and let it out to roam your screen and climb your windows. It hatches, grows, and evolves with the care you give." and
  .surfaces.panel.role == "panel" and
  .surfaces.panel.inputRegions == "dynamic-bounded" and
  .surfaces.barWidget.role == "bar-embedded" and
  .surfaces.roam.role == "desktop-overlay" and
  .surfaces.roam.initiallyVisible == true and
  .surfaces.roam.inputRegions == "dynamic-bounded" and
  (has("ipc") | not) and
  (.permissions.required | length) == 0 and
  ([.permissions.optional[].capability] ==
    ["storage.private", "notifications.send", "audio.play-cue", "system.observe"]) and
  (.permissions.optional[] | select(.capability == "storage.private") |
    .quotaBytes == 1048576) and
  (.permissions.optional[] | select(.capability == "notifications.send") |
    .categories == ["pet-care"]) and
  (.permissions.optional[] | select(.capability == "audio.play-cue") |
    (.cues | index("eat") != null and index("pet2") != null and
      index("tractorbeam") != null and index("farewell_gremlin") != null and
      index("grab") != null)) and
  (.permissions.optional[] | select(.capability == "system.observe") |
    .definitionGeneration == 1 and
    .definitionDigest == "59af09ff1dd91191a3dcfb7917fd6bebc7aaac91a892c69cbd329bd45e4df520" and
    .operations == ["observe"] and
    .datasets == ["compositor.window-rectangles", "packages.summary"])
' "$MANIFEST" >/dev/null

if rg -n 'import (Quickshell|qs\.)|Process\s*\{|FileView\s*\{|execDetached|Qt\.openUrlExternally' \
    "$ROOT/Panel.qml" "$ROOT/Service.qml" "$ROOT/BarWidget.qml" "$ROOT/RoamWindow.qml"; then
  echo "secured entrypoint contains ambient host authority" >&2
  exit 1
fi

if rg -n 'onPermissionsChanged|\bLoader\s*\{' \
    "$ROOT/Panel.qml" "$ROOT/Service.qml" "$ROOT/BarWidget.qml" "$ROOT/RoamWindow.qml"; then
  echo "secured surfaces still use an obsolete host presentation or permission API" >&2
  exit 1
fi
if rg -n 'stateHome|stateDir|settingsPath|petPath|omarchyPath|notificationExecutable|soundPath|eventSounds|property var shell|property var manifest|single-surface|checkupdates|pacman -Qdtq|pw-play' \
    "$ROOT/Service.qml"; then
  echo "secured service retained a dead shell-era property or comment" >&2
  exit 1
fi

rg -Fq 'import Omarchy.PluginPresentation 1.0 as Presentation' "$ROOT/Panel.qml"
rg -Fq 'Presentation.Panel {' "$ROOT/Panel.qml"
rg -Fq 'id: settingsControl' "$ROOT/Panel.qml"
rg -Fq 'Presentation.PanelSlider {' "$ROOT/Panel.qml"
test ! -e "$ROOT/PanelSlider.qml"
test ! -e "$ROOT/PanelKeyCatcher.qml"
rg -Fq 'property var inputRegions' "$ROOT/Panel.qml"
rg -Fq 'runtime.invoke(capability, operation, arguments' "$ROOT/Service.qml"
rg -Fq 'runtime.hasPermission("audio.play-cue", "play")' "$ROOT/Service.qml"
rg -Fq 'runtime.hasPermission("notifications.send", "send")' "$ROOT/Service.qml"
rg -Fq 'runtime.permissionState("system.observe", "observe")' "$ROOT/Service.qml"
rg -Fq 'compositor.window-rectangles' "$ROOT/Service.qml"
rg -Fq 'packages.summary' "$ROOT/Service.qml"
rg -Fq 'PrivateStorage {' "$ROOT/Service.qml"
rg -Fq 'storage.readText("settings"' "$ROOT/Service.qml"
rg -Fq 'storage.writeText("pet-state"' "$ROOT/Service.qml"
rg -Fq 'function feedNow()' "$ROOT/Service.qml"
rg -Fq 'function scrub(amount)' "$ROOT/Service.qml"
rg -Fq 'function petThePet()' "$ROOT/Service.qml"
rg -Fq 'function setRoamEnabled(value)' "$ROOT/Service.qml"
rg -Fq 'property var inputRegions' "$ROOT/BarWidget.qml"
rg -Fq 'tooltipText: serviceReady ? petService.moodLabel : "Omagotchi"' "$ROOT/BarWidget.qml"
rg -Fq 'runtime.requestSurfaceIntent("panel", "toggle")' "$ROOT/BarWidget.qml"
rg -Fq 'onPressed: function(mouse)' "$ROOT/BarWidget.qml"
rg -Uq '(?s:onPressed: function\(mouse\) \{.{0,512}runtime\.requestSurfaceIntent\("panel", "toggle"\))' \
  "$ROOT/BarWidget.qml"
rg -Fq 'property var inputRegions' "$ROOT/RoamWindow.qml"
rg -Fq 'petX = Math.max(0, w / 2 - spriteSize / 2)' "$ROOT/RoamWindow.qml"
rg -Fq 'property real handoffXRatio: -1' "$ROOT/Service.qml"
rg -Fq 'function startReturn()' "$ROOT/RoamWindow.qml"
rg -Fq 'function finishReturn()' "$ROOT/RoamWindow.qml"
rg -Fq 'root.ageLabel(root.petService.ageMinutes)' "$ROOT/Panel.qml"
rg -Fq 'root.petService.playSound("grab")' "$ROOT/RoamWindow.qml"
rg -Fq 'function receiveSurfaceIntent(data)' "$ROOT/RoamWindow.qml"
rg -Fq 'runtime.requestSurfaceIntent("roam", "open",' "$ROOT/Panel.qml"
rg -Fq 'root.petService.connectedOutputs.length > 1' "$ROOT/Panel.qml"
rg -Fq 'var outputs = root.petService.connectedOutputs' "$ROOT/Panel.qml"
rg -Fq 'output: root.petService.settings.roamScreen || ""' "$ROOT/Panel.qml"
rg -Fq 'output: ""' "$ROOT/Panel.qml"
rg -Fq 'onPressedChanged:' "$ROOT/Panel.qml"
rg -Uq '(?s:onPressedChanged: \{.{0,1024}runtime\.requestSurfaceIntent\("roam", "open",)' "$ROOT/Panel.qml"
if rg -U 'onClicked\s*:[^{\n]*(?:\{[^}]{0,1024})?requestSurfaceIntent' \
    "$ROOT/Panel.qml" "$ROOT/BarWidget.qml"; then
  echo "surface intent moved outside synchronous pointer-down authority" >&2
  exit 1
fi
if rg -n 'Keys\..*requestSurfaceIntent|Keys\.onEscape' "$ROOT/Panel.qml"; then
  echo "keyboard dismissal bypasses the accepted pointer authority path" >&2
  exit 1
fi
rg -Fq 'next.push({x1: x1, x2: x2, y: y, address: String(window.id)})' "$ROOT/RoamWindow.qml"
rg -Fq 'property var petService: SharedService' "$ROOT/Panel.qml"
rg -Fq 'readonly property var petService: SharedService' "$ROOT/BarWidget.qml"
rg -Fq 'property var petService: SharedService' "$ROOT/RoamWindow.qml"
rg -Fq 'pragma Singleton' "$ROOT/SharedService.qml"
rg -Fq 'singleton SharedService 1.0 SharedService.qml' "$ROOT/qmldir"

test -f "$ROOT/assets/sprites/child_walk_a.png"
test -f "$ROOT/BarWidget.qml"
test -f "$ROOT/RoamWindow.qml"
test -f "$ROOT/PetSprite.qml"
test ! -e "$ROOT/secure/lab-manifest.json"
test ! -e "$ROOT/secure/ui/OmagotchiLabProof.qml"

echo "secure Omagotchi compatibility contract: PASS"
