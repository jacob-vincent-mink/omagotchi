import QtQuick
import QtQuick.Effects

// One animated 1-bit sprite: cycles through white-on-transparent frames from
// assets/sprites/ and tints them, so the pet always wears the theme's colors.
Item {
  id: root

  // Frame file names inside assets/sprites/, e.g. ["idle_a.png", "idle_b.png"]
  property var frames: []
  property int frameMs: 500
  property bool playing: true
  property color tint: "white"
  property bool mirrored: false

  property int frame: 0

  onFramesChanged: frame = 0

  Image {
    id: image
    anchors.fill: parent
    source: root.frames.length > 0
      ? Qt.resolvedUrl("assets/sprites/" + root.frames[root.frame % root.frames.length])
      : ""
    // Nearest-neighbour scaling keeps the pixels crisp.
    smooth: false
    mipmap: false
    fillMode: Image.PreserveAspectFit
    mirror: root.mirrored
    visible: false
  }

  MultiEffect {
    anchors.fill: image
    source: image
    colorization: 1
    colorizationColor: root.tint
  }

  Timer {
    interval: root.frameMs
    running: root.playing && root.frames.length > 1 && root.visible
    repeat: true
    onTriggered: root.frame = (root.frame + 1) % root.frames.length
  }
}
