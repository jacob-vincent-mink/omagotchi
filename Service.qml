import QtQuick
import Quickshell
import Quickshell.Io

// Headless pet brain. Loaded once at shell startup, independent of the bar
// widget, so the pet keeps living (and roaming) with the panel closed.
//
// Needs follow the classic loop: they rise with active shell time so there is
// always something to do, whatever the hardware. System state only flavors the
// pace — pending updates make it hungrier faster, orphaned packages make it
// get dirty faster. Nothing here depends on absolute machine performance.
//
// Commands executed (all fixed argv, read-only, no interpolation):
//   checkupdates              pending official updates
//   pacman -Qdtq              orphaned packages
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
    roamScale: 3,
    soundEnabled: true
  })
  property var settings: defaultSettings

  // --- persistent pet facts --------------------------------------------------

  property double hatchedAtMs: 0
  property double lastPetMs: 0

  // Growth, Gen1-chart style: the stage advances with active shell minutes,
  // and the branch taken depends on average happiness over the stage.
  property string stage: "egg"     // egg | baby | child | teen | adult
  property string form: "egg"      // sprite prefix in assets/sprites/
  property real ageMinutes: 0
  property real careSum: 0
  property int careCount: 0
  property int generation: 1

  // Need levels, 0 = fine, 100 = critical. All persisted.
  property real hungerLevel: 0
  property real dirtLevel: 0
  property real tirednessLevel: 0
  property real boredomLevel: 0
  property real lonelinessLevel: 0
  property bool sleeping: false

  readonly property var knownForms: ["egg", "baby", "child", "teen_neat",
    "teen_scruffy", "adult_ace", "adult_ok", "adult_gremlin"]

  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || ""
  readonly property string notificationExecutable: omarchyPath !== ""
    ? omarchyPath + "/bin/omarchy-notification-send"
    : "omarchy-notification-send"

  // --- probe results ---------------------------------------------------------

  property int pendingUpdates: 0
  property int orphanCount: 0
  property double nowMs: Date.now()

  property bool initialized: false
  property bool settingsFileLoaded: false
  property bool petFileLoaded: false
  property string loadedSettingsText: ""
  property string loadedPetText: ""

  // --- derived needs ---------------------------------------------------------

  readonly property real hunger: Math.max(0, Math.min(100, hungerLevel))
  readonly property real dirtiness: Math.max(0, Math.min(100, dirtLevel))
  readonly property real tiredness: Math.max(0, Math.min(100, tirednessLevel))
  readonly property real boredom: Math.max(0, Math.min(100, boredomLevel))
  // Affection is a cuddle-session need: it fills over active time and each
  // petting only takes a bite out of it — a truly lonely pet wants a real
  // fuss, not a single tap.
  readonly property real loneliness: Math.max(0, Math.min(100, lonelinessLevel))

  readonly property bool roaming: canRoam && settings.roamEnabled === true

  readonly property real worstNeed: Math.max(hunger, dirtiness, tiredness,
    boredom, loneliness)
  readonly property real happiness: Math.round(100 - worstNeed)

  readonly property real careAverage: careCount > 0 ? careSum / careCount : 100
  readonly property bool canRoam: stage !== "egg" && stage !== "baby"
  readonly property string stageLabel: ({
    egg: "Egg", baby: "Baby", child: "Child", teen: "Teen", adult: "Adult"
  })[stage] || stage

  // Where the pet left its panel, in screen coordinates (center x, feet y),
  // so the roaming window can pick up the fall right under the card. Negative
  // x means "no handoff": spawn at the usual floor spot.
  property real handoffX: -1
  property real handoffY: -1
  property string handoffScreen: ""

  // Set by the panel to call the pet home through the tractor beam; the roam
  // window beams it up to the handoff spot, then clears this and fires
  // arrivedHome so the panel can play the entrance.
  property bool returnRequested: false
  signal arrivedHome()

  // Short-lived animation for a care action ("eat", "wash"), shown by the
  // panel and the roaming pet, then cleared.
  property string transientAnim: ""
  Timer {
    id: transientTimer
    interval: 2500
    onTriggered: root.transientAnim = ""
  }

  // The shared emote bubbles, one glyph per complaining need. When several
  // needs complain at once the bubble cycles through them every few seconds.
  // Views hide the bubble when the file doesn't exist yet.
  readonly property var activeEmotes: {
    if (!initialized || sleeping || stage === "egg") return []
    var list = []
    if (hunger >= 60) list.push("emote_hungry")
    if (dirtiness >= 60) list.push("emote_dirty")
    if (tiredness >= 60) list.push("emote_sleepy")
    if (boredom >= 60) list.push("emote_bored")
    if (loneliness >= 60) list.push("emote_sad")
    return list
  }
  property int emoteCycle: 0
  readonly property string emoteName: activeEmotes.length === 0
    ? "" : activeEmotes[emoteCycle % activeEmotes.length]

  Timer {
    interval: 3000
    running: root.initialized && root.activeEmotes.length > 1
    repeat: true
    onTriggered: root.emoteCycle += 1
  }

  // The idle-state animation views should show (falls back to plain idle in
  // PetSprite when the dedicated sprite doesn't exist yet).
  readonly property string stateAnim: {
    if (!initialized || stage === "egg") return "idle"
    if (sleeping) return "sleep"
    switch (mood) {
    case "hungry": return "hungry"
    case "dirty": return "dirty"
    case "sleepy": return "sleepy"
    case "bored": return "bored"
    case "lonely": return "sad"
    default: return "idle"
    }
  }

  // Priority order: sleep is a state, then the loudest complaint wins.
  readonly property string mood: {
    if (!initialized) return "sleeping"
    if (stage === "egg") return "egg"
    if (sleeping) return "sleeping"
    if (hunger >= 60) return "hungry"
    if (dirtiness >= 60) return "dirty"
    if (tiredness >= 60) return "sleepy"
    if (boredom >= 60) return "bored"
    if (loneliness >= 60) return "lonely"
    if (worstNeed >= 35) return "meh"
    return "happy"
  }

  readonly property string moodLabel: {
    switch (mood) {
    case "egg": return "An egg. Something wiggles inside…"
    case "sleeping": return "Zzz…"
    case "hungry": return pendingUpdates > 0
      ? "Hungry — and those " + pendingUpdates + " pending updates smell delicious"
      : "Hungry — feed me!"
    case "dirty": return orphanCount > 0
      ? "Feeling gross — the " + orphanCount + " orphaned packages don't help"
      : "Feeling gross — bath time?"
    case "sleepy": return "Sleepy — about to doze off…"
    case "bored": return "Bored — let me out to play!"
    case "lonely": return "Lonely — pet me!"
    case "meh": return "Doing okay"
    case "happy": return "Happy!"
    default: return "Omagotchi"
    }
  }

  // --- the minute tick -------------------------------------------------------

  // Per-stage personalities: babies nap constantly, children burst with
  // energy and want out, teens raid the fridge and stay in. See ROADMAP §3.
  readonly property var stageRates: ({
    baby:  { hunger: 1.5, dirt: 1, tired: 2.0, fun: 0.5 },
    child: { hunger: 1,   dirt: 1, tired: 1,   fun: 1.5 },
    teen:  { hunger: 2,   dirt: 1, tired: 0.8, fun: 0.5 },
    adult: { hunger: 1,   dirt: 1, tired: 1,   fun: 1 }
  })

  // Per-active-minute rates. System state flavors the pace: pending updates
  // and orphans speed up hunger/dirt, roaming is fun but tiring.
  function applyMinute() {
    if (stage === "egg") return // an egg has no needs yet
    var rates = stageRates[stage] || stageRates.adult

    hungerLevel = Math.min(100,
      hungerLevel + (pendingUpdates > 0 ? 0.5 : 0.33) * rates.hunger)
    dirtLevel = Math.min(100,
      dirtLevel + (orphanCount > 0 ? 0.33 : 0.21) * rates.dirt)

    if (sleeping) {
      tirednessLevel = Math.max(0, tirednessLevel - 2.2)
      if (tirednessLevel <= 5) sleeping = false
    } else {
      tirednessLevel = Math.min(100,
        tirednessLevel + (roaming ? 0.55 : 0.28) * rates.tired)
      if (tirednessLevel >= 90) {
        sleeping = true
        playSound("sleep")
      }
    }

    boredomLevel = roaming
      ? Math.max(0, boredomLevel - 2.0)
      : Math.min(100, boredomLevel + 0.45 * rates.fun)

    // Full in ~14 active hours; each petting takes 10 off.
    lonelinessLevel = Math.min(100, lonelinessLevel + 0.12)
  }

  // --- growth ----------------------------------------------------------------

  function maybeEvolve() {
    if (stage === "egg" && ageMinutes >= 5)
      return evolve("baby", "baby", "The egg hatched!")
    if (stage === "baby" && ageMinutes >= 70)
      return evolve("child", "child", "Your baby grew into a child!")
    if (stage === "child" && ageMinutes >= 550)
      return evolve("teen", careAverage >= 55 ? "teen_neat" : "teen_scruffy",
        "Your child is a teen now. Interesting haircut.")
    if (stage === "teen" && ageMinutes >= 1510) {
      var neat = form === "teen_neat"
      var next = "adult_gremlin"
      if (careAverage >= 75) next = neat ? "adult_ace" : "adult_ok"
      else if (careAverage >= 40) next = neat ? "adult_ok" : "adult_gremlin"
      return evolve("adult", next, "Your teen is all grown up.")
    }
  }

  function evolve(nextStage, nextForm, message) {
    stage = nextStage
    form = nextForm
    careSum = 0
    careCount = 0
    flushPet()
    playSound(nextStage === "baby" ? "hatch" : "evolve")
    notify("Omagotchi", message)
  }

  // --- sounds ----------------------------------------------------------------

  // One short clip per event, named after the event so better sounds can be
  // dropped in without touching code. The current set is placeholders reused
  // from the tomato-timer plugin's library — see CREDITS.md.
  readonly property var eventSounds: ({
    hatch: "hatch.mp3",
    evolve: "evolve.mp3",
    eat: "eat.wav",
    wash: "wash.mp3",
    pet: "pet.mp3",
    sleep: "sleep.wav",
    stun: "stun.wav",
    farewell: "farewell.wav"
  })

  // pw-play wants a filesystem path, not a file:// URL.
  function soundPath(relativePath) {
    var url = Qt.resolvedUrl(relativePath).toString()
    if (url.indexOf("file://") === 0) url = url.substring(7)
    return decodeURIComponent(url)
  }

  function playSound(event) {
    if (settings.soundEnabled !== true) return
    var file = eventSounds[event]
    if (!file) return
    Quickshell.execDetached(["pw-play", "--volume", "0.5",
      soundPath("sounds/" + file)])
  }

  function notify(title, body) {
    Quickshell.execDetached([
      notificationExecutable,
      "--app-name", "omagotchi",
      "-u", "normal",
      title,
      body
    ])
  }

  // --- actions ---------------------------------------------------------------

  function feedNow() {
    hungerLevel = 0
    transientAnim = "eat"
    transientTimer.restart()
    playSound("eat")
    flushPet()
  }

  // Washing is a scrubbing gesture: the panel feeds it mouse travel and the
  // dirt comes off progressively. Persisted by the caller on gesture end.
  function scrub(amount) {
    if (dirtLevel <= 0) return
    dirtLevel = Math.max(0, dirtLevel - amount)
    transientAnim = "wash"
    transientTimer.restart()
    // The reward chime marks the moment it comes out all clean.
    if (dirtLevel === 0) {
      playSound("wash")
      flushPet()
    }
  }

  // The Tamagotchi farewell: the adult flies home, a new egg appears, and
  // the generation counter carries the legacy.
  function sendOff() {
    if (stage !== "adult") return
    generation += 1
    stage = "egg"
    form = "egg"
    ageMinutes = 0
    careSum = 0
    careCount = 0
    hungerLevel = 0
    dirtLevel = 0
    tirednessLevel = 0
    boredomLevel = 0
    lonelinessLevel = 0
    sleeping = false
    hatchedAtMs = Date.now()
    lastPetMs = hatchedAtMs
    flushPet()
    playSound("farewell")
    notify("Omagotchi", "Your companion waved goodbye and flew home… a new egg appeared! (Gen " + generation + ")")
  }

  function petThePet() {
    lastPetMs = Date.now()
    nowMs = lastPetMs
    lonelinessLevel = Math.max(0, lonelinessLevel - 10)
    boredomLevel = Math.max(0, boredomLevel - 10)
    playSound("pet")
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
      lastPetMs: lastPetMs,
      stage: stage,
      form: form,
      ageMinutes: ageMinutes,
      careSum: careSum,
      careCount: careCount,
      generation: generation,
      hungerLevel: hungerLevel,
      dirtLevel: dirtLevel,
      tirednessLevel: tirednessLevel,
      boredomLevel: boredomLevel,
      lonelinessLevel: lonelinessLevel,
      sleeping: sleeping
    }, null, 2) + "\n")
  }

  // --- init ------------------------------------------------------------------

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
      stage = typeof pet.stage === "string" ? pet.stage : "egg"
      form = typeof pet.form === "string" ? pet.form : "egg"
      ageMinutes = Number(pet.ageMinutes) > 0 ? Number(pet.ageMinutes) : 0
      careSum = Number(pet.careSum) > 0 ? Number(pet.careSum) : 0
      careCount = Number(pet.careCount) > 0 ? Math.round(Number(pet.careCount)) : 0
      generation = Number(pet.generation) >= 1 ? Math.round(Number(pet.generation)) : 1
      hungerLevel = Number(pet.hungerLevel) > 0 ? Number(pet.hungerLevel) : 0
      dirtLevel = Number(pet.dirtLevel) > 0 ? Number(pet.dirtLevel) : 0
      tirednessLevel = Number(pet.tirednessLevel) > 0 ? Number(pet.tirednessLevel) : 0
      boredomLevel = Number(pet.boredomLevel) > 0 ? Number(pet.boredomLevel) : 0
      if (pet.lonelinessLevel !== undefined) {
        lonelinessLevel = Number(pet.lonelinessLevel) > 0 ? Number(pet.lonelinessLevel) : 0
      } else {
        // Soft migration from the old wall-clock model: seed the stored level
        // from the time since the last petting.
        var hours = Number(pet.lastPetMs) > 0
          ? Math.max(0, (Date.now() - Number(pet.lastPetMs)) / 3600000) : 0
        lonelinessLevel = Math.min(100, hours / 24 * 100)
      }
      sleeping = pet.sleeping === true
    } catch (petError) { hatchedAtMs = 0; lastPetMs = 0 }
    // A corrupt or hand-edited form falls back to a fresh egg rather than a
    // broken sprite path.
    if (knownForms.indexOf(form) < 0) {
      stage = "egg"
      form = "egg"
      ageMinutes = 0
      careSum = 0
      careCount = 0
    }
    if (hatchedAtMs === 0) {
      hatchedAtMs = Date.now()
      lastPetMs = hatchedAtMs
      hatch = true
    }

    initialized = true
    if (hatch) flushPet()

    updatesProc.running = true
    orphansProc.running = true
  }

  function updateSettingsInMemory(parsed) {
    var merged = {}
    for (var key in defaultSettings) merged[key] = defaultSettings[key]
    for (var loaded in parsed) merged[loaded] = parsed[loaded]
    settings = merged
  }

  // --- probes ----------------------------------------------------------------

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

  // The heartbeat: needs, age, care sampling and evolution, every minute.
  Timer {
    interval: 60 * 1000
    running: root.initialized
    repeat: true
    onTriggered: {
      root.nowMs = Date.now()
      root.applyMinute()
      root.ageMinutes += 1
      root.careSum += root.happiness
      root.careCount += 1
      root.maybeEvolve()
      if (root.careCount % 5 === 0) root.flushPet()
    }
  }
  Timer {
    interval: 5 * 60 * 1000
    running: root.initialized
    repeat: true
    onTriggered: orphansProc.running = true
  }
  // checkupdates syncs its own db copy, so only every 30 minutes.
  Timer {
    interval: 30 * 60 * 1000
    running: root.initialized
    repeat: true
    onTriggered: updatesProc.running = true
  }

  // --- roaming ---------------------------------------------------------------

  // Deliberately a static window with a visibility binding, not a Loader:
  // dynamically created windows leak a zombie layer surface across the shell's
  // plugin hot-reload, which then wedges screencopy (grim) on that output.
  RoamWindow {
    petService: root
    visible: root.initialized && root.roaming
  }

  // --- persistence -----------------------------------------------------------

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
