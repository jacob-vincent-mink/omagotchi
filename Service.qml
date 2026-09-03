import QtQuick
import QtQml as Qml
import Omarchy.PluginPresentation 1.0 as Presentation

// Headless pet brain. Loaded once per sandbox generation and shared by the
// declared surfaces, so the pet keeps living with the panel closed.
//
// Needs follow the classic loop: they rise with active runtime time so there
// is always something to do. System state still flavors the pace through the
// bounded package summary; without that optional provider, counts stay neutral.
Item {
  id: root

  readonly property var defaultSettings: ({
    roamEnabled: false,
    roamScale: 3,
    // The host projects only bounded connected-output names. Empty follows
    // the output of the authenticated Go play / Come home source surface.
    roamScreen: "",
    soundVolume: 0.5
  })
  // Effects volume, 0 (mute) to 1.
  readonly property real soundVolume: {
    var v = Number(settings.soundVolume)
    return isFinite(v) ? Math.max(0, Math.min(1, v)) : 0.5
  }
  property var settings: defaultSettings

  // --- persistent pet facts --------------------------------------------------

  property double hatchedAtMs: 0
  property double lastPetMs: 0

  // Growth, Gen1-chart style: the stage advances with active runtime minutes,
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

  Presentation.PrivateStorage {
    id: storage
    quotaBytes: 1048576
    itemBytes: root.maxStateBytes
  }

  property var pendingCalls: ({})
  property var compositorSnapshot: ({ width: 0, height: 0, reservedBottom: 0, windows: [] })
  property var connectedOutputs: []
  property string requestedRoamOutput: ""
  property bool compositorObservationPending: false
  property bool packageSummaryPending: false
  readonly property bool compositorObservationAvailable: {
    return runtime.hasPermission("system.observe", "observe")
  }
  readonly property string compositorObservationState:
    runtime.permissionState("system.observe", "observe")
  function broker(capability, operation, arguments, completed) {
    var call = runtime.invoke(capability, operation, arguments || {})
    if (!call) { if (completed) completed(false, null); return }
    pendingCalls[call.correlation] = completed || null
    if (call.finished) finishBrokerCall(call)
  }
  function finishBrokerCall(call) {
    var completed = pendingCalls[call.correlation]
    delete pendingCalls[call.correlation]
    if (completed) completed(call.ok, call.value, call)
  }
  function refreshCompositorSnapshot(output) {
    if (!compositorObservationAvailable || compositorObservationPending) {
      if (!compositorObservationAvailable)
        compositorSnapshot = { width: 0, height: 0, reservedBottom: 0, windows: [] }
      return
    }
    compositorObservationPending = true
    broker("system.observe", "observe", {
      demandScope: '{"datasets":["compositor.window-rectangles"]}',
      payload: {
        dataset: "compositor.window-rectangles",
        output: typeof output === "string" ? output : requestedRoamOutput
      }
    }, function(ok, value, call) {
      compositorObservationPending = false
      if (!ok || !call) {
        compositorSnapshot = { width: 0, height: 0, reservedBottom: 0, windows: [] }
        return
      }
      try {
        var decoded = JSON.parse(call.utf8Text)
        if (!decoded.ok || !Array.isArray(decoded.windows)
            || !Array.isArray(decoded.outputs)) throw new Error("invalid snapshot")
        connectedOutputs = decoded.outputs
        compositorSnapshot = decoded
      } catch (error) {
        compositorSnapshot = { width: 0, height: 0, reservedBottom: 0, windows: [] }
      }
    })
  }
  function refreshPackageSummary() {
    if (!runtime.hasPermission("system.observe", "observe") || packageSummaryPending)
      return
    packageSummaryPending = true
    broker("system.observe", "observe", {
      demandScope: '{"datasets":["packages.summary"]}',
      payload: { dataset: "packages.summary" }
    }, function(ok, value, call) {
      packageSummaryPending = false
      if (!ok || !call) return
      try {
        var decoded = JSON.parse(call.utf8Text)
        if (!decoded.ok) return
        var updates = Number(decoded.pendingUpdates)
        var orphans = Number(decoded.orphanCount)
        if (Number.isInteger(updates) && updates >= 0 && updates <= 100000)
          pendingUpdates = updates
        if (Number.isInteger(orphans) && orphans >= 0 && orphans <= 100000)
          orphanCount = orphans
      } catch (error) {
        // Keep the last good bounded observation.
      }
    })
  }
  Qml.Connections {
    target: runtime
    function onCallFinished(call) { root.finishBrokerCall(call) }
  }
  // --- probe results ---------------------------------------------------------

  property int pendingUpdates: 0
  property int orphanCount: 0
  property double nowMs: Date.now()

  property bool initialized: false
  // Brokered state reads are bounded before they enter QML. The plugin writes
  // only a few hundred bytes; anything hitting this stricter parser cap is
  // treated as corrupt.
  readonly property int maxStateBytes: 65536
  property bool settingsFileLoaded: false
  property bool petFileLoaded: false
  property string loadedSettingsText: ""
  property string loadedPetText: ""
  property string petReadProblem: ""

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

  // Surface-local coordinates are intentionally shared as normalized values:
  // the sandbox knows each allocation, while the host keeps global placement.
  property real handoffXRatio: -1
  property real handoffYRatio: -1
  property bool returnRequested: false
  signal arrivedHome()

  // Short-lived animation for a care action ("eat", "wash"), shown by the
  // panel and the roaming pet, then cleared.
  property string transientAnim: ""
  Timer {
    id: transientTimer
    interval: 2500
    onTriggered: root.endCare()
  }

  function endCare() {
    transientAnim = ""
    // Woken up for a meal or a bath? It stays up a little while, then goes
    // back to bed if it is still sleepy. The flag survives until the pet
    // actually dozes back off, so chained cares (feed then wash) re-arm it.
    if (wokenForCare) resleepTimer.restart()
  }
  Timer {
    id: resleepTimer
    interval: 30000
    onTriggered: {
      // Mid-meal or mid-scrub: stay up, endCare re-arms the timer.
      if (root.sleeping || root.eating || root.transientAnim !== "") return
      root.wokenForCare = false
      if (root.tirednessLevel < 60 || root.roaming) return
      root.sleeping = true
      root.playSound("sleep")
      root.flushPet()
    }
  }

  // A meal is eaten bite by bite: hunger drains over ~6 s from full while
  // the eat frames play, then a last chew before the animation ends.
  readonly property bool eating: eatTimer.running
  Timer {
    id: eatTimer
    interval: 100
    repeat: true
    onTriggered: {
      root.hungerLevel = Math.max(0, root.hungerLevel - 100 / 60)
      if (root.hungerLevel > 0) return
      stop()
      transientTimer.interval = 600
      transientTimer.restart()
      root.flushPet()
    }
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

    // Out and about, it hums to itself once or twice an hour.
    if (roaming && !sleeping && Math.random() < 1.5 / 60) playSound("hum")

    hungerLevel = Math.min(100,
      hungerLevel + (pendingUpdates > 0 ? 0.5 : 0.33) * rates.hunger)
    dirtLevel = Math.min(100,
      dirtLevel + (orphanCount > 0 ? 0.33 : 0.21) * rates.dirt)

    if (sleeping) {
      tirednessLevel = Math.max(0, tirednessLevel - 2.2)
      if (tirednessLevel <= 5) {
        sleeping = false
        // A little hum tells the user it woke up on its own.
        playSound("hum")
      }
    } else {
      tirednessLevel = Math.min(100,
        tirednessLevel + (roaming ? 0.55 : 0.28) * rates.tired)
      if (tirednessLevel >= 90) {
        sleeping = true
        playSound("sleep")
      } else if (tirednessLevel >= 60 && !roaming && !resleepTimer.running) {
        // Sleepy at home with nothing better to do: doze off shortly.
        // The timer re-checks (eating, care animation) before committing.
        resleepTimer.restart()
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

  // The manifest names every cue this state machine may request. Calls fail
  // closed when the optional audio permission or provider is unavailable.
  readonly property var eventCues: ({
    hatch: "hatch",
    evolve: "evolve",
    eat: "eat",
    wash: "wash",
    pet: ["pet", "pet2"],
    hum: "humming",
    grab: "grab",
    sleep: "sleep",
    stun: "stun",
    land: "fall",
    beamCharge: "subbass",
    beam: "tractorbeam",
    ball: "balloon",
    farewell_ace: "farewell_ace",
    farewell_ok: "farewell_ok",
    farewell_gremlin: "farewell_gremlin"
  })

  function playSound(event) {
    if (soundVolume <= 0) return
    var cue = eventCues[event]
    if (Array.isArray(cue)) cue = cue[Math.floor(Math.random() * cue.length)]
    if (!cue) return
    if (runtime.hasPermission("audio.play-cue", "play"))
      broker("audio.play-cue", "play", { cue: String(cue) })
  }

  function notify(title, body) {
    if (runtime.hasPermission("notifications.send", "send"))
      broker("notifications.send", "send", { category: "pet-care", title: title, body: body })
  }

  // --- actions ---------------------------------------------------------------

  // Care wakes a sleeping pet first; once the fuss is over it dozes back
  // off if it is still sleepy (see transientTimer).
  property bool wokenForCare: false

  function wakeForCare() {
    // A pending doze interrupted by more care still counts as one to resume.
    if (resleepTimer.running) wokenForCare = true
    resleepTimer.stop()
    if (!sleeping) return
    sleeping = false
    wokenForCare = true
  }

  function feedNow() {
    if (eating) return
    wakeForCare()
    transientAnim = "eat"
    transientTimer.stop()
    playSound("eat")
    if (hungerLevel > 0) eatTimer.restart()
    else {
      // Nothing to eat: a polite nibble, then back to whatever it was doing.
      transientTimer.interval = 1200
      transientTimer.restart()
    }
  }

  // Washing is a scrubbing gesture: the panel feeds it mouse travel and the
  // dirt comes off progressively. Persisted by the caller on gesture end.
  function scrub(amount) {
    if (dirtLevel <= 0) return
    wakeForCare()
    dirtLevel = Math.max(0, dirtLevel - amount)
    transientAnim = "wash"
    transientTimer.interval = 2500
    transientTimer.restart()
    if (dirtLevel === 0) flushPet()
  }

  // The Tamagotchi farewell: the adult sets off into the world, a new egg appears, and
  // the generation counter carries the legacy.
  // Letting go is a little ceremony: the adult leaves its room (if home),
  // walks to the nearest screen corner, says goodbye in its own voice and
  // walks off the screen. Only then does the new egg appear.
  property bool farewellPending: false

  function beginFarewell() {
    if (stage !== "adult" || farewellPending) return
    wakeUp()
    farewellPending = true
  }

  function farewellSoundEvent() {
    return "farewell_" + form.replace("adult_", "")
  }

  function sendOff() {
    if (stage !== "adult") return
    farewellPending = false
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
    // The adult may leave from outdoors; the egg must not inherit a stale
    // "out playing" state (disabled Come home button, surprise exit at
    // the child stage).
    updateSettings({ roamEnabled: false })
    flushPet()
    notify("Omagotchi", "Your companion said goodbye and walked off into the world… a new egg appeared! (Gen " + generation + ")")
  }

  // A deliberate wake-up — petting, grabbing, or sending it out — unlike
  // wakeForCare it does not tuck the pet back in afterwards.
  function wakeUp() {
    if (!sleeping) return
    resleepTimer.stop()
    sleeping = false
    wokenForCare = false
    flushPet()
  }

  function petThePet() {
    wakeUp()
    lastPetMs = Date.now()
    nowMs = lastPetMs
    lonelinessLevel = Math.max(0, lonelinessLevel - 10)
    if (!canRoam) boredomLevel = Math.max(0, boredomLevel - 10)
    playSound("pet")
    flushPet()
  }

  function setRoamEnabled(value) {
    updateSettings({ roamEnabled: value === true })
    // Brought home already sleepy? It settles in for a moment, then dozes
    // off — no need to hit rock bottom first.
    if (value !== true && !sleeping && tirednessLevel >= 60)
      resleepTimer.restart()
  }

  // A big fall hurts its feelings too: the inverse of a petting.
  // A big fall: the thud first, the dizzy jingle right after it.
  function stunShock() {
    lonelinessLevel = Math.min(100, lonelinessLevel + 10)
    playSound("land")
    stunSoundTimer.restart()
    flushPet()
  }
  Timer {
    id: stunSoundTimer
    interval: 450
    onTriggered: root.playSound("stun")
  }

  // The tractor beam: a low thrum powering up, then the beam itself. On the
  // way home it is mirrored: the beam plays out (~2.7 s), then the thrum.
  function playBeamSound(homeward) {
    beamSoundTimer.second = homeward ? "beamCharge" : "beam"
    beamSoundTimer.interval = homeward ? 2700 : 650
    playSound(homeward ? "beam" : "beamCharge")
    beamSoundTimer.restart()
  }
  Timer {
    id: beamSoundTimer
    property string second: "beam"
    onTriggered: root.playSound(second)
  }

  function updateSettings(patch) {
    var merged = {}
    for (var key in defaultSettings) merged[key] = defaultSettings[key]
    // Only known keys survive a write: retired settings (soundEnabled…) drop
    // out of the file on their own.
    for (var current in settings) if (current in merged) merged[current] = settings[current]
    for (var change in patch) if (change in merged) merged[change] = patch[change]
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
    } catch (error) {
      console.warn("omagotchi: settings file unreadable (" + error + "), using defaults")
      settings = defaultSettings
    }

    var hatch = false
    var saveProblem = petReadProblem
    // Persisted numbers must be finite and non-negative; anything else
    // (NaN, Infinity, negatives, strings) reads as 0.
    function num(v) { var n = Number(v); return isFinite(n) && n > 0 ? n : 0 }
    try {
      var pet = loadedPetText !== "" ? JSON.parse(loadedPetText) : {}
      hatchedAtMs = num(pet.hatchedAtMs)
      lastPetMs = num(pet.lastPetMs)
      stage = typeof pet.stage === "string" ? pet.stage : "egg"
      form = typeof pet.form === "string" ? pet.form : "egg"
      ageMinutes = num(pet.ageMinutes)
      careSum = num(pet.careSum)
      careCount = Math.round(num(pet.careCount))
      generation = Math.max(1, Math.round(num(pet.generation)))
      hungerLevel = num(pet.hungerLevel)
      dirtLevel = num(pet.dirtLevel)
      tirednessLevel = num(pet.tirednessLevel)
      boredomLevel = num(pet.boredomLevel)
      if (pet.lonelinessLevel !== undefined) {
        lonelinessLevel = num(pet.lonelinessLevel)
      } else {
        // Soft migration from the old wall-clock model: seed the stored level
        // from the time since the last petting.
        var hours = Number(pet.lastPetMs) > 0
          ? Math.max(0, (Date.now() - Number(pet.lastPetMs)) / 3600000) : 0
        lonelinessLevel = Math.min(100, hours / 24 * 100)
      }
      sleeping = pet.sleeping === true
    } catch (petError) {
      hatchedAtMs = 0; lastPetMs = 0
      saveProblem = "not valid JSON (" + petError + ")"
    }
    // A corrupt or hand-edited form or stage falls back to a fresh egg
    // rather than a broken sprite path or NaN-poisoned need rates.
    if (knownForms.indexOf(form) < 0
        || ["egg", "baby", "child", "teen", "adult"].indexOf(stage) < 0) {
      if (saveProblem === "") saveProblem = "unknown stage/form " + stage + "/" + form
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
    if (saveProblem !== "") {
      console.warn("omagotchi: private state " + saveProblem + " — starting over")
      notify("Omagotchi couldn't read its private state",
             "It was corrupt or oversized, so a fresh egg takes over.")
    }
    if (hatch) flushPet()

    updatesProc.running = true
    orphansProc.running = true
  }

  function updateSettingsInMemory(parsed) {
    var merged = {}
    for (var key in defaultSettings) merged[key] = defaultSettings[key]
    for (var loaded in parsed) if (loaded in merged) merged[loaded] = parsed[loaded]
    settings = merged
  }

  // --- probes ----------------------------------------------------------------

  QtObject {
    id: updatesProc
    property bool running: false
    onRunningChanged: if (running) {
      root.refreshPackageSummary()
      running = false
    }
  }

  QtObject {
    id: orphansProc
    property bool running: false
    onRunningChanged: if (running) {
      root.refreshPackageSummary()
      running = false
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
  // Both bounded probes only flavor the pace, so every 30 minutes is plenty.
  Timer {
    interval: 30 * 60 * 1000
    running: root.initialized
    repeat: true
    onTriggered: orphansProc.running = true
  }
  Timer {
    interval: 30 * 60 * 1000
    running: root.initialized
    repeat: true
    onTriggered: updatesProc.running = true
  }

  // --- persistence -----------------------------------------------------------

  Qml.Timer {
    interval: 0
    running: true
    repeat: false
    onTriggered: {
      root.refreshCompositorSnapshot()
      storage.readText("settings", function(text) {
        root.loadedSettingsText = text || ""
        root.settingsFileLoaded = true
        root.initializeIfReady()
      }, function() {
        root.loadedSettingsText = ""
        root.settingsFileLoaded = true
        root.initializeIfReady()
      })
      storage.readText("pet-state", function(text) {
        root.loadedPetText = text || ""
        root.petFileLoaded = true
        root.initializeIfReady()
      }, function() {
        root.loadedPetText = ""
        root.petFileLoaded = true
        root.initializeIfReady()
      })
    }
  }

  // These tiny adapters keep persistence call sites local while all durable
  // writes remain broker operations.
  QtObject {
    id: settingsFile
    function setText(text) { storage.writeText("settings", text, function() {}, function() {}) }
  }

  QtObject {
    id: petFile
    function setText(text) { storage.writeText("pet-state", text, function() {}, function() {}) }
  }
}
