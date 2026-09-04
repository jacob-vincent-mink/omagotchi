import QtQuick

// One animated 1-bit sprite: the two frames (a/b) of `anim` for `form`,
// tinted live with the theme's colors. If an animation's frames are not in
// assets/sprites/ yet, it falls back (to `fallbackAnim`, then to the form's
// idle, which always exists) — so sprites can land in the repo gradually
// without ever breaking a view.
Item {
  id: root

  property string form: "egg"
  property string anim: "idle"
  // What to try when `anim`'s frames are missing (e.g. "walk" for a climb).
  property string fallbackAnim: "idle"
  property int frameMs: 500
  property bool playing: true
  property color tint: "white"
  property bool mirrored: false

  property int frame: 0
  // The animation actually shown once fallbacks are applied.
  property string resolvedAnim: anim

  function restart() {
    resolvedAnim = anim
    frame = 0
  }

  function applyFallback() {
    if (image.status !== Image.Error) return
    if (resolvedAnim !== fallbackAnim) resolvedAnim = fallbackAnim
    else if (resolvedAnim !== "idle") resolvedAnim = "idle"
  }

  onAnimChanged: restart()
  onFormChanged: restart()

  Image {
    id: image
    anchors.fill: parent
    source: Qt.resolvedUrl("assets/sprites/" + root.form + "_" + root.resolvedAnim
      + "_" + (root.frame === 0 ? "a" : "b") + ".png")
    // Nearest-neighbour scaling keeps the pixels crisp.
    smooth: false
    mipmap: false
    fillMode: Image.PreserveAspectFit
    mirror: root.mirrored
    visible: false

    // Deferred: writing resolvedAnim during the source evaluation that
    // triggered the status change would be a binding loop.
    onStatusChanged: if (status === Image.Error) Qt.callLater(root.applyFallback)
    onSourceChanged: {
      sprite.loadImage(source)
      sprite.requestPaint()
    }
  }

  Canvas {
    id: sprite
    anchors.fill: parent
    renderTarget: Canvas.Image
    renderStrategy: Canvas.Immediate

    onImageLoaded: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: loadImage(image.source)

    onPaint: {
      var context = getContext("2d")
      context.clearRect(0, 0, width, height)
      if (!isImageLoaded(image.source)) return
      context.save()
      if (root.mirrored) {
        context.translate(width, 0)
        context.scale(-1, 1)
      }
      context.drawImage(image.source, 0, 0, width, height)
      context.restore()
      context.globalCompositeOperation = "source-in"
      context.fillStyle = root.tint
      context.fillRect(0, 0, width, height)
      context.globalCompositeOperation = "source-over"
    }
  }

  onTintChanged: sprite.requestPaint()
  onMirroredChanged: sprite.requestPaint()

  Timer {
    interval: root.frameMs
    running: root.playing && root.visible
    repeat: true
    onTriggered: root.frame = root.frame === 0 ? 1 : 0
  }
}
