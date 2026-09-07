import QtQuick
import QtTest
TestCase {
  id: testRoot
  name: "SecurePersistence"
  when: windowShown

  QtObject {
    id: runtime
    readonly property var permissions: ({})
    readonly property int permissionGeneration: 1
    property var invocations: []
    property bool observeGranted: false
    property string observeResponse: ""
    signal callFinished(var call)
    function invoke(capability, operation, arguments) {
      invocations = invocations.concat([{ capability: capability, operation: operation, arguments: arguments }])
      if (capability === "system.observe" && observeGranted)
        return { correlation: "observe", finished: true, ok: true, value: null,
          utf8Text: observeResponse }
      return { correlation: capability + operation + JSON.stringify(arguments || {}),
        finished: true, ok: false, value: null, utf8Text: "" }
    }
    function hasPermission(capability, operation) {
      return capability === "system.observe" && operation === "observe" && observeGranted
    }
    function permissionState(capability, operation) { return "denied" }
    function requestSurfaceIntent(surface, action) { return false }
  }

  Loader {
    id: petLoader
    source: "../Service.qml"
  }
  readonly property var pet: petLoader.item

  function test_surfacesLoad_data() {
    return [{ tag: "panel", source: "../Panel.qml" },
      { tag: "roaming", source: "../RoamWindow.qml" }]
  }

  function test_surfacesLoad(data) {
    var component = Qt.createComponent(data.source)
    compare(component.status, Component.Ready, component.errorString())
    var surface = createTemporaryObject(component, testRoot, { petService: pet })
    verify(surface !== null)
    verify(surface.width > 0 && surface.height > 0)
  }

  function init() {
    pet.initialized = false
    pet.settingsFileLoaded = false
    pet.petFileLoaded = false
    pet.loadedSettingsText = ""
    pet.loadedPetText = ""
    pet.generation = 1
    pet.hungerLevel = 0
    pet.settings = pet.defaultSettings
    runtime.invocations = []
    runtime.observeGranted = false
    runtime.observeResponse = ""
  }

  function test_restoresPrivateStateText() {
    var state = JSON.stringify({generation: 7, ageMinutes: 12, hunger: 61,
      stage: "child", form: "child", hungerLevel: 61, dirtLevel: 22,
      tirednessLevel: 33, boredomLevel: 44, lonelinessLevel: 55,
      sleeping: false})
    pet.loadedPetText = state
    pet.settingsFileLoaded = true
    pet.petFileLoaded = true
    pet.initializeIfReady()
    compare(pet.generation, 7)
    compare(pet.hunger, 61)
    compare(pet.form, "child")
  }

  function test_rejectsMalformedAndOutOfBoundsState() {
    var bounded = JSON.stringify({generation: 7, ageMinutes: 12,
      stage: "child", form: "child", hungerLevel: 101, dirtLevel: 22,
      tirednessLevel: 33, boredomLevel: 44, lonelinessLevel: 55,
      sleeping: false})
    pet.loadedPetText = bounded
    pet.settingsFileLoaded = true
    pet.petFileLoaded = true
    pet.initializeIfReady()
    compare(pet.hunger, 100)
  }

  function test_restartPreservesRoaming() {
    pet.loadedSettingsText = JSON.stringify({ roamEnabled: true, roamScale: 4 })
    pet.loadedPetText = JSON.stringify({ generation: 3, stage: "child",
      form: "child" })
    pet.settingsFileLoaded = true
    pet.petFileLoaded = true
    pet.initializeIfReady()

    compare(pet.settings.roamEnabled, true)
    compare(pet.settings.roamScale, 4)
    var writes = runtime.invocations.filter(function(invocation) {
      return invocation.capability === "storage.private" && invocation.operation === "write"
        && invocation.arguments.key === "settings"
    })
    compare(writes.length, 0)
  }

  function test_packageSummaryUsesBoundedProviderProjection() {
    runtime.observeGranted = true
    runtime.observeResponse = JSON.stringify({ok: true, pendingUpdates: 17, orphanCount: 3})
    pet.refreshPackageSummary()
    compare(pet.pendingUpdates, 17)
    compare(pet.orphanCount, 3)
    compare(runtime.invocations[runtime.invocations.length - 1].arguments.dataset,
      "packages.summary")

    runtime.observeResponse = JSON.stringify({ok: true, pendingUpdates: -1, orphanCount: 100001})
    pet.refreshPackageSummary()
    compare(pet.pendingUpdates, 17)
    compare(pet.orphanCount, 3)
  }
}
