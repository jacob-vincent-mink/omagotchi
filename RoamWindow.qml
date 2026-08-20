import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// The stroll strip: a transparent, input-passthrough band along the bottom of
// the screen where the pet wanders. exclusiveZone 0 makes layer-shell place it
// above a bottom bar's reserved zone automatically, or on the bare screen edge
// when the bar lives elsewhere. Only the sprite itself is clickable (mask).
PanelWindow {
  id: root

  required property var petService

  readonly property int scale: {
    var value = petService && petService.settings
      ? Number(petService.settings.roamScale) : 3
    return value >= 2 && value <= 6 ? Math.round(value) : 3
  }
  readonly property int spriteSize: 16 * scale

  anchors {
    left: true
    right: true
    bottom: true
  }
  implicitHeight: spriteSize
  color: "transparent"
  exclusiveZone: 0
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "omagotchi"
  mask: Region { item: sprite }

  PetSprite {
    id: sprite
    width: root.spriteSize
    height: root.spriteSize
    y: parent.height - height
    x: 0

    readonly property bool walking: moveAnimation.running
    frames: walking ? ["walk_a.png", "walk_b.png"] : ["idle_a.png", "idle_b.png"]
    frameMs: walking ? 220 : 500
    tint: Color.foreground

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (root.petService) root.petService.petThePet()
        heart.pop()
      }
    }

    // A small thank-you heart when petted.
    Text {
      id: heart
      text: "♥"
      color: Color.accent
      font.pixelSize: Math.max(12, root.spriteSize / 3)
      anchors.horizontalCenter: parent.horizontalCenter
      opacity: 0

      function pop() { heartAnimation.restart() }

      ParallelAnimation {
        id: heartAnimation
        NumberAnimation { target: heart; property: "y"; from: 0; to: -root.spriteSize / 2; duration: 700 }
        SequentialAnimation {
          NumberAnimation { target: heart; property: "opacity"; from: 0; to: 1; duration: 150 }
          NumberAnimation { target: heart; property: "opacity"; to: 0; duration: 550 }
        }
      }
    }
  }

  NumberAnimation {
    id: moveAnimation
    target: sprite
    property: "x"
    easing.type: Easing.Linear
  }

  // The wandering brain: every few seconds, maybe pick a new spot and stroll
  // over at a fixed pixels-per-second pace. Doing nothing sometimes is what
  // makes it feel alive rather than scripted.
  Timer {
    id: brain
    interval: 1500
    running: root.visible
    repeat: true
    onTriggered: {
      interval = 2000 + Math.floor(Math.random() * 6000)
      if (moveAnimation.running) return
      if (Math.random() < 0.35) return // lazing around

      var range = Math.max(0, root.width - sprite.width)
      var target = Math.random() * range
      if (Math.abs(target - sprite.x) < sprite.width) return

      sprite.mirrored = target < sprite.x
      moveAnimation.to = target
      moveAnimation.duration = Math.abs(target - sprite.x) / (root.scale * 20) * 1000
      moveAnimation.restart()
    }
  }
}
