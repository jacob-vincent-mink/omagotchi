import QtQuick
import Quickshell
import Quickshell.Io

// Headless pet brain. Loaded once at shell startup, independent of the bar
// widget, so the pet keeps living (and roaming) with the panel closed.
//
// Design rule: needs rise with time and universal Arch signals (pending
// updates, orphans, uptime), never with absolute hardware performance, so the
// pet plays the same on a 10-year-old laptop and a fresh build.
//
// Commands executed (all fixed argv, no interpolation):
//   checkupdates              read-only, pending official updates
//   pacman -Qdtq              read-only, orphaned packages
//   cat /proc/uptime          read-only
//   omarchy-launch-floating-terminal-with-presentation omarchy-update
//                             feed action: user drives the update themselves
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
    || ((Quickshell.env("HOME") || "") + "/.local/state")
  readonly property string stateDir: stateHome + "/omarchy"
  readonly property string settingsPath: stateDir + "/omagotchi-settings.json"
  readonly property string petPath: stateDir + "/omagotchi-state.json"

  readonly property var defaultSettings: ({
    roamEnabled: false,
    roamScale: 3
  })
  property var settings: defaultSettings

  // --- persistent pet facts --------------------------------------------------

  property double hatchedAtMs: 0
  property double lastPetMs: 0

  // --- probe results -----------------------------------------------------------

  property int pendingUpdates: 0
  property int orphanCount: 0
  property real uptimeHours: 0
  property double nowMs: Date.now()

  property bool initialized: false
  property bool settingsFileLoaded: false
  property bool petFileLoaded: false
  property string loadedSettingsText: ""
  property string loadedPetText: ""

  // --- needs, 0 = fine, 100 = critical ----------------------------------------

  // 25 pending updates = starving.
  readonly property real hunger: Math.min(100, pendingUpdates * 4)
  // 8 orphaned packages = filthy.
  readonly property real dirtiness: Math.min(100, orphanCount * 12.5)
  // A full week without a reboot = exhausted.
  readonly property real tiredness: Math.min(100, uptimeHours / 168 * 100)
  // A day without affection = lonely. Roaming keeps it half-entertained.
  readonly property real loneliness: {
    var hours = lastPetMs > 0 ? Math.max(0, (nowMs - lastPetMs) / 3600000) : 0
    var value = Math.min(100, hours / 24 * 100)
    return settings.roamEnabled === true ? Math.min(50, value) : value
  }

  readonly property real worstNeed: Math.max(hunger, dirtiness, tiredness, loneliness)
  readonly property real happiness: Math.round(100 - worstNeed)

  // Priority order: the loudest body complaint wins over feelings.
  readonly property string mood: {
    if (!initialized) return "sleeping"
    if (hunger >= 60) return "hungry"
    if (dirtiness >= 60) return "dirty"
    if (tiredness >= 60) return "sleepy"
    if (loneliness >= 60) return "lonely"
    if (worstNeed >= 35) return "meh"
    return "happy"
  }

  readonly property string moodLabel: {
    switch (mood) {
    case "hungry": return "Hungry — " + pendingUpdates + " updates would taste great"
    case "dirty": return "Feeling gross — " + orphanCount + " orphaned packages itch"
    case "sleepy": return "Sleepy — up for " + Math.round(uptimeHours) + "h, a reboot would help"
    case "lonely": return "Lonely — pet me!"
    case "meh": return "Doing okay"
    case "happy": return "Happy!"
    default: return "Omagotchi"
    }
  }

  // --- actions -----------------------------------------------------------------

  function feed() {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"])
    reprobeTimer.restart()
  }

  function groom() {
    // Fixed literal handed to the standard Omarchy terminal wrapper; the user
    // confirms and types their password in the terminal, never here.
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation",
      "sudo pacman -Rns $(pacman -Qdtq)"])
    reprobeTimer.restart()
  }

  function petThePet() {
    lastPetMs = Date.now()
    nowMs = lastPetMs
    flushPet()
  }

  function setRoamEnabled(value) {
    updateSettings({ roamEnabled: value === true })
  }

  function updateSettings(patch) {
    var merged = {}
    for (var key in defaultSettings) merged[key] = defaultSettings[key]
    for (var current in settings) merged[current] = settings[current]
    for (var change in patch) merged[change] = patch[change]
    settings = merged
    settingsFile.setText(JSON.stringify(settings, null, 2) + "\n")
  }

  function flushPet() {
    petFile.setText(JSON.stringify({
      hatchedAtMs: hatchedAtMs,
      lastPetMs: lastPetMs
    }, null, 2) + "\n")
  }

  // --- init --------------------------------------------------------------------

  function initializeIfReady() {
    if (initialized || !settingsFileLoaded || !petFileLoaded) return

    try {
      var parsedSettings = loadedSettingsText !== "" ? JSON.parse(loadedSettingsText) : {}
      updateSettingsInMemory(parsedSettings)
    } catch (error) { settings = defaultSettings }

    var hatch = false
    try {
      var pet = loadedPetText !== "" ? JSON.parse(loadedPetText) : {}
      hatchedAtMs = Number(pet.hatchedAtMs) > 0 ? Number(pet.hatchedAtMs) : 0
      lastPetMs = Number(pet.lastPetMs) > 0 ? Number(pet.lastPetMs) : 0
    } catch (petError) { hatchedAtMs = 0; lastPetMs = 0 }
    if (hatchedAtMs === 0) {
      hatchedAtMs = Date.now()
      lastPetMs = hatchedAtMs
      hatch = true
    }

    initialized = true
    if (hatch) flushPet()

    updatesProc.running = true
    orphansProc.running = true
    uptimeProc.running = true
  }

  function updateSettingsInMemory(parsed) {
    var merged = {}
    for (var key in defaultSettings) merged[key] = defaultSettings[key]
    for (var loaded in parsed) merged[loaded] = parsed[loaded]
    settings = merged
  }

  // --- probes --------------------------------------------------------------------

  Process {
    id: updatesProc
    command: ["checkupdates"]
    stdout: StdioCollector { id: updatesOut }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        var text = updatesOut.text.trim()
        root.pendingUpdates = text === "" ? 0 : text.split("\n").length
      } else if (exitCode === 2) {
        root.pendingUpdates = 0
      }
      // exit 1 = error (offline, db lock): keep the previous value.
    }
  }

  Process {
    id: orphansProc
    command: ["pacman", "-Qdtq"]
    stdout: StdioCollector { id: orphansOut }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        var text = orphansOut.text.trim()
        root.orphanCount = text === "" ? 0 : text.split("\n").length
      } else {
        root.orphanCount = 0
      }
    }
  }

  Process {
    id: uptimeProc
    command: ["cat", "/proc/uptime"]
    stdout: StdioCollector { id: uptimeOut }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      var seconds = parseFloat(uptimeOut.text)
      if (!isNaN(seconds)) root.uptimeHours = seconds / 3600
    }
  }

  // Loneliness ticks by the minute; light local probes every 5; checkupdates
  // (which syncs its own db copy) only every 30.
  Timer {
    interval: 60 * 1000
    running: root.initialized
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }
  Timer {
    interval: 5 * 60 * 1000
    running: root.initialized
    repeat: true
    onTriggered: { orphansProc.running = true; uptimeProc.running = true }
  }
  Timer {
    interval: 30 * 60 * 1000
    running: root.initialized
    repeat: true
    onTriggered: updatesProc.running = true
  }
  // After a feed/groom the user may finish in a minute or ten; probe twice.
  Timer {
    id: reprobeTimer
    interval: 2 * 60 * 1000
    repeat: true
    onTriggered: {
      updatesProc.running = true
      orphansProc.running = true
      if (interval >= 10 * 60 * 1000) stop()
      else interval = 10 * 60 * 1000
    }
  }

  // --- roaming -------------------------------------------------------------------

  LazyLoader {
    active: root.initialized && root.settings.roamEnabled === true
    RoamWindow { petService: root }
  }

  // --- persistence -----------------------------------------------------------------

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root.loadedSettingsText = text()
      root.settingsFileLoaded = true
      root.initializeIfReady()
    }
    onLoadFailed: {
      root.loadedSettingsText = ""
      root.settingsFileLoaded = true
      root.initializeIfReady()
    }
  }

  FileView {
    id: petFile
    path: root.petPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root.loadedPetText = text()
      root.petFileLoaded = true
      root.initializeIfReady()
    }
    onLoadFailed: {
      root.loadedPetText = ""
      root.petFileLoaded = true
      root.initializeIfReady()
    }
  }
}
