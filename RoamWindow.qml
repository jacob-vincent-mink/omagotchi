import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

// The pet's playground: a transparent full-screen overlay where it wanders the
// bottom edge, climbs up the sides of windows whose top border leaves enough
// headroom, walks along their tops, and hops back down. Everything is
// click-through except the pet itself (mask), so the desktop stays usable.
//
// Window geometry comes from the Hyprland IPC via Quickshell — no shell
// commands. Coordinates are used as-is, which is correct at monitor scale 1;
// fractional scaling support is a known TODO.
PanelWindow {
  id: root

  required property var petService

  // The playground lives on the largest screen for now; a per-monitor pet (or
  // a screen setting) is a possible follow-up.
  screen: {
    var best = null
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (!best || screens[i].width * screens[i].height > best.width * best.height)
        best = screens[i]
    }
    return best
  }

  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "omagotchi"
  mask: Region { item: sprite }

  readonly property int petScale: {
    var value = petService && petService.settings
      ? Number(petService.settings.roamScale) : 3
    return value >= 2 && value <= 6 ? Math.round(value) : 3
  }
  readonly property int spriteSize: 16 * petScale
  // Headroom above a platform so the pet never pokes off-screen.
  readonly property int headroom: spriteSize + 12

  readonly property var hyprMonitor: Hyprland.monitorFor(root.screen)

  // The bar's reserved strip, so the floor sits above a bottom bar.
  readonly property real floorY: {
    var ipc = hyprMonitor ? hyprMonitor.lastIpcObject : null
    var reservedBottom = ipc && ipc.reserved && ipc.reserved.length > 3
      ? Number(ipc.reserved[3]) : 0
    return height - reservedBottom
  }

  // --- world model -----------------------------------------------------------

  // Walkable surfaces: window tops as {x1, x2, y, address}. The floor is the
  // implicit surface with address "".
  property var platforms: []
  // Current support: null = floor, else a platform object out of `platforms`.
  property var support: null

  function rebuildPlatforms() {
    if (!hyprMonitor) { platforms = []; validateSupport(); return }
    var ws = hyprMonitor.activeWorkspace ? hyprMonitor.activeWorkspace.id : -1
    var list = []
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      var ipc = toplevel.lastIpcObject
      if (!ipc || !ipc.at || !ipc.size) continue
      if (!toplevel.workspace || toplevel.workspace.id !== ws) continue
      if (ipc.hidden === true || ipc.mapped === false) continue
      if (ipc.fullscreen) continue
      var y = ipc.at[1] - hyprMonitor.y
      var x1 = ipc.at[0] - hyprMonitor.x
      var x2 = x1 + ipc.size[0]
      // Keep only tops the pet can stand on without leaving the screen, and
      // that are actually above the floor.
      if (y < root.headroom || y > root.floorY - 10) continue
      x1 = Math.max(0, x1)
      x2 = Math.min(root.width, x2)
      if (x2 - x1 < root.spriteSize * 2) continue
      list.push({ x1: x1, x2: x2, y: y, address: toplevel.address })
    }
    platforms = list
    validateSupport()
  }

  // The world changed under the pet's feet: follow the window it stands on
  // (windows are rideable!), or fall if it vanished or slid away.
  function validateSupport() {
    if (!support) return
    for (var i = 0; i < platforms.length; i++) {
      var p = platforms[i]
      if (p.address === support.address) {
        support = p
        if (action !== "climb" && action !== "fall") {
          petY = p.y
          if (petX < p.x1 || petX + spriteSize > p.x2) startFall()
        }
        return
      }
    }
    support = null
    if (action !== "fall") startFall()
  }

  // --- pet state -------------------------------------------------------------

  property real petX: 0
  property real petY: 0            // the pet's feet line
  property string action: "idle"   // idle | walk | climb | fall
  property real targetX: 0
  property real targetY: 0
  property var pendingClimb: null  // {wallX, platform} after the walk phase
  property bool facingLeft: false

  readonly property real walkSpeed: petScale * 22   // px/s
  readonly property real climbSpeed: petScale * 16
  readonly property real fallSpeed: petScale * 110

  function currentSurfaceBounds() {
    return support
      ? { x1: support.x1, x2: support.x2 }
      : { x1: 0, x2: root.width }
  }

  function landingBelow(x, fromY) {
    var best = { y: floorY, platform: null }
    var center = x + spriteSize / 2
    for (var i = 0; i < platforms.length; i++) {
      var p = platforms[i]
      if (p.y > fromY + 1 && p.y < best.y && center >= p.x1 && center <= p.x2)
        best = { y: p.y, platform: p }
    }
    return best
  }

  // Falls from higher than this fraction of the screen leave the pet seeing
  // stars for a few seconds.
  readonly property real stunFallFraction: 0.4
  property real fallStartY: 0

  function startFall() {
    pendingClimb = null
    if (action !== "fall") fallStartY = petY
    action = "fall"
  }

  Timer {
    id: stunTimer
    interval: 3000
    onTriggered: if (root.action === "stunned") root.action = "idle"
  }

  function startWalkTo(x, climb) {
    var bounds = currentSurfaceBounds()
    targetX = Math.max(bounds.x1, Math.min(bounds.x2 - spriteSize, x))
    pendingClimb = climb || null
    facingLeft = targetX < petX
    action = "walk"
  }

  // Climbable walls from here: edges of platforms strictly above whose base
  // is reachable by walking on the current surface.
  function climbCandidates() {
    var bounds = currentSurfaceBounds()
    var found = []
    for (var i = 0; i < platforms.length; i++) {
      var p = platforms[i]
      if (support && p.address === support.address) continue
      if (p.y >= petY - spriteSize) continue
      if (p.x1 >= bounds.x1 && p.x1 <= bounds.x2 - spriteSize)
        found.push({ wallX: p.x1, platform: p })
      else if (p.x2 - spriteSize >= bounds.x1 && p.x2 <= bounds.x2)
        found.push({ wallX: p.x2 - spriteSize, platform: p })
    }
    return found
  }

  // --- physics ---------------------------------------------------------------

  Timer {
    id: physics
    interval: 40
    running: root.visible
    repeat: true
    onTriggered: {
      var dt = interval / 1000
      if (root.action === "walk") {
        var step = root.walkSpeed * dt
        if (Math.abs(root.targetX - root.petX) <= step) {
          root.petX = root.targetX
          if (root.pendingClimb) {
            root.targetY = root.pendingClimb.platform.y
            root.action = "climb"
          } else {
            root.action = "idle"
          }
        } else {
          root.petX += root.petX < root.targetX ? step : -step
        }
      } else if (root.action === "climb") {
        var rise = root.climbSpeed * dt
        if (root.petY - root.targetY <= rise) {
          root.petY = root.targetY
          root.support = root.pendingClimb ? root.pendingClimb.platform : root.support
          root.pendingClimb = null
          root.action = "idle"
        } else {
          root.petY -= rise
        }
      } else if (root.action === "fall") {
        var landing = root.landingBelow(root.petX, root.petY)
        var drop = root.fallSpeed * dt
        if (landing.y - root.petY <= drop) {
          root.petY = landing.y
          root.support = landing.platform
          if (root.petY - root.fallStartY > root.height * root.stunFallFraction) {
            root.action = "stunned"
            stunTimer.restart()
          } else {
            root.action = "idle"
          }
        } else {
          root.petY += drop
        }
      }
    }
  }

  // --- the wandering brain ---------------------------------------------------

  Timer {
    id: brain
    interval: 1500
    running: root.visible && root.action === "idle"
      && !(root.petService && root.petService.sleeping)
    repeat: true
    onTriggered: {
      interval = 2500 + Math.floor(Math.random() * 5000)
      var roll = Math.random()
      var climbs = root.climbCandidates()

      if (roll < 0.25 && climbs.length > 0) {
        var pick = climbs[Math.floor(Math.random() * climbs.length)]
        root.startWalkTo(pick.wallX, pick)
      } else if (roll < 0.40 && root.support) {
        // Hop off the current window.
        root.startFall()
      } else if (roll < 0.85) {
        var bounds = root.currentSurfaceBounds()
        var span = Math.max(0, bounds.x2 - bounds.x1 - root.spriteSize)
        root.startWalkTo(bounds.x1 + Math.random() * span, null)
      }
      // else: lazing around is also living.
    }
  }

  // --- keeping up with the compositor ---------------------------------------

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      switch (event.name) {
      case "openwindow":
      case "closewindow":
      case "movewindow":
      case "movewindowv2":
      case "resizewindow":
      case "workspace":
      case "workspacev2":
      case "changefloatingmode":
      case "fullscreen":
      case "focusedmon":
        refreshDebounce.restart()
      }
    }
  }

  Timer {
    id: refreshDebounce
    interval: 250
    onTriggered: {
      Hyprland.refreshToplevels()
      rebuildDelay.restart()
    }
  }
  // lastIpcObject updates arrive shortly after the refresh request.
  Timer {
    id: rebuildDelay
    interval: 350
    onTriggered: root.rebuildPlatforms()
  }
  // Fallback sweep for anything the event filter misses.
  Timer {
    interval: 7000
    running: root.visible
    repeat: true
    onTriggered: refreshDebounce.restart()
  }

  function resetPosition() {
    petX = Math.max(0, width / 2 - spriteSize / 2)
    petY = floorY
    support = null
    pendingClimb = null
    action = "idle"
    refreshDebounce.restart()
  }

  // The window can be born visible, so onVisibleChanged alone never fires;
  // and the real height only arrives once the surface is mapped, so the floor
  // glue keeps the pet grounded instead of hovering at y 0.
  Component.onCompleted: resetPosition()
  onVisibleChanged: if (visible) resetPosition()
  onFloorYChanged: {
    if (action === "idle" && !support && Math.abs(petY - floorY) > 1)
      petY = floorY
  }

  // --- the pet ---------------------------------------------------------------

  PetSprite {
    id: sprite
    width: root.spriteSize
    height: root.spriteSize
    x: root.petX
    y: root.petY - height
    rotation: root.action === "climb" ? -90 : (root.action === "held" ? 12 : 0)
    Behavior on rotation { NumberAnimation { duration: 150 } }

    readonly property bool asleep: root.petService && root.petService.sleeping
    form: root.petService.form
    anim: {
      if (asleep) return "sleep"
      switch (root.action) {
      case "walk":
      case "fall":
      case "held": return "walk" // held: legs kicking in protest
      case "climb": return "climb"
      case "stunned": return "stunned"
      default: return root.petService.transientAnim !== ""
        ? root.petService.transientAnim
        : root.petService.stateAnim
      }
    }
    // A climb without its dedicated sprite reuses the walk frames (rotated).
    fallbackAnim: root.action === "climb" ? "walk" : "idle"
    frameMs: asleep ? 1200 : (root.action === "idle" ? 500 : 220)
    tint: Color.foreground
    mirrored: root.facingLeft

    // Click = pet; press-and-move = pick it up by the scruff and carry it.
    // Once pressed, the Wayland implicit grab keeps pointer events coming to
    // this surface even when the cursor leaves the click mask, so the drag
    // survives crossing other windows.
    MouseArea {
      id: grabArea
      anchors.fill: parent
      // A stunned pet is too dizzy to be petted or picked up.
      enabled: root.action !== "stunned"
      cursorShape: root.action === "held" ? Qt.ClosedHandCursor : Qt.PointingHandCursor

      property real grabDx: 0
      property real grabDy: 0
      property real pressGlobalX: 0
      property real pressGlobalY: 0
      property bool dragging: false

      onPressed: function(mouse) {
        var p = mapToItem(root.contentItem, mouse.x, mouse.y)
        pressGlobalX = p.x
        pressGlobalY = p.y
        grabDx = p.x - root.petX
        grabDy = p.y - (root.petY - root.spriteSize)
        dragging = false
      }
      onPositionChanged: function(mouse) {
        if (!pressed) return
        var p = mapToItem(root.contentItem, mouse.x, mouse.y)
        if (!dragging) {
          if (Math.abs(p.x - pressGlobalX) < 8 && Math.abs(p.y - pressGlobalY) < 8) return
          dragging = true
          root.action = "held"
          root.pendingClimb = null
          root.support = null
        }
        root.petX = Math.max(0, Math.min(root.width - root.spriteSize, p.x - grabDx))
        root.petY = Math.max(root.headroom,
          Math.min(root.floorY, p.y - grabDy + root.spriteSize))
      }
      onReleased: {
        if (dragging) {
          dragging = false
          // A small lift so a drop aimed at a window border lands on it
          // instead of slipping just past its top edge.
          root.petY = Math.max(root.headroom, root.petY - 6)
          root.startFall()
        } else {
          if (root.petService) root.petService.petThePet()
          heart.pop()
        }
      }
    }
  }

  // The shared emote bubble: one 16x16 white glyph per state, floating above
  // the head, tinted urgent when the need turns critical. A missing emote
  // file simply hides the bubble (Image.Error), so they can land one by one.
  readonly property string emoteName: {
    if (!petService) return ""
    if (action === "stunned") return "emote_stun"
    return petService.emoteName
  }

  Item {
    id: emote
    visible: root.emoteName !== "" && root.action !== "held"
      && emoteImage.status === Image.Ready
    width: Math.round(root.spriteSize * 0.75)
    height: width
    x: root.petX + Math.round(root.spriteSize * 0.7)
    y: root.petY - root.spriteSize - height + bob

    property real bob: 0
    SequentialAnimation on bob {
      running: emote.visible
      loops: Animation.Infinite
      NumberAnimation { from: 0; to: -4; duration: 900; easing.type: Easing.InOutQuad }
      NumberAnimation { from: -4; to: 0; duration: 900; easing.type: Easing.InOutQuad }
    }

    Image {
      id: emoteImage
      anchors.fill: parent
      source: root.emoteName !== ""
        ? Qt.resolvedUrl("assets/sprites/" + root.emoteName + ".png") : ""
      smooth: false
      mipmap: false
      fillMode: Image.PreserveAspectFit
      visible: false
    }

    MultiEffect {
      anchors.fill: emoteImage
      source: emoteImage
      colorization: 1
      // Same tint as the pet, one creature one color.
      colorizationColor: Color.foreground
    }
  }

  Text {
    text: "z z Z"
    visible: root.petService && root.petService.sleeping
    color: Color.foreground
    font.pixelSize: Math.max(11, root.spriteSize / 3)
    x: root.petX + root.spriteSize
    y: root.petY - root.spriteSize - height / 2

    SequentialAnimation on opacity {
      running: visible
      loops: Animation.Infinite
      NumberAnimation { from: 0.25; to: 1; duration: 1300 }
      NumberAnimation { from: 1; to: 0.25; duration: 1300 }
    }
  }

  // A small thank-you heart when petted. The overlay is full-screen now, so
  // it has all the headroom it wants.
  Text {
    id: heart
    text: "♥"
    color: Color.accent
    font.pixelSize: Math.max(12, root.spriteSize / 3)
    x: root.petX + root.spriteSize / 2 - width / 2
    opacity: 0

    property real rise: 0
    y: root.petY - root.spriteSize - height - rise

    function pop() { heartAnimation.restart() }

    ParallelAnimation {
      id: heartAnimation
      NumberAnimation { target: heart; property: "rise"; from: 0; to: root.spriteSize; duration: 700 }
      SequentialAnimation {
        NumberAnimation { target: heart; property: "opacity"; from: 0; to: 1; duration: 150 }
        NumberAnimation { target: heart; property: "opacity"; to: 0; duration: 550 }
      }
    }
  }
}
