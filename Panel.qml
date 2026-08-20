pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

// The pet's home: a card with the pet front and center, its needs as bars,
// and the care actions. Every action maps to real system maintenance.
Panel {
  id: root
  moduleName: "slcode777.omagotchi"

  // One panel instance exists per bar; only the largest screen's instance
  // claims the IPC target, so `qs ipc call slcode777.omagotchi toggle` acts
  // on a predictable panel instead of whichever instance registered first.
  readonly property var panelScreen: anchorItem && anchorItem.QsWindow.window
    ? anchorItem.QsWindow.window.screen : null
  readonly property var mainScreen: {
    var best = null
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (!best || screens[i].width * screens[i].height > best.width * best.height)
        best = screens[i]
    }
    return best
  }
  ipcTarget: panelScreen && panelScreen === mainScreen ? moduleName : ""

  property var anchorItem: null
  property var hostWidget: null
  property var petService: null
  readonly property var barIdentity: hostWidget || root

  readonly property bool ready: !!petService && petService.initialized === true
  // Out roaming = not home: the plate stays empty while it plays outside.
  readonly property bool petIsOut: ready && petService.roaming === true
  readonly property color foreground: Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var needs: ready ? [
    { label: "Hunger", value: petService.hunger,
      hint: petService.pendingUpdates > 0
        ? "rising faster: " + petService.pendingUpdates + " updates pending"
        : "rises over time",
      action: "feed", actionLabel: "Feed", needsHome: true,
      actionTip: petIsOut ? "It's out playing — call it home first"
        : "A good meal, hunger back to zero" },
    { label: "Hygiene", value: petService.dirtiness,
      hint: petIsOut ? "wash it at home: press and scrub it with your mouse"
        : "press and scrub it with your mouse to wash it",
      action: "", actionLabel: "", actionTip: "" },
    { label: "Energy", value: petService.tiredness,
      hint: petService.sleeping ? "recovering — Zzz…" : "naps when exhausted",
      action: "", actionLabel: "", actionTip: "" },
    { label: "Fun", value: petService.boredom, hint: "roaming cures boredom",
      action: "roam",
      actionLabel: petService.settings.roamEnabled === true ? "Come home" : "Go play",
      actionTip: petService.canRoam
        ? "Let the pet roam and climb your windows"
        : "Too young to go out alone" },
    { label: "Affection", value: petService.loneliness, hint: "click the pet!",
      action: "", actionLabel: "", actionTip: "" }
  ] : []

  function runAction(kind) {
    if (!ready) return
    if (kind === "feed") petService.feedNow()
    else if (kind === "roam")
      petService.setRoamEnabled(!(petService.settings.roamEnabled === true))
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    padding: Style.space(14)
    contentWidth: panel.fittedContentWidth(Style.space(410))
    // The card sizes itself from the actual content, plus breathing room at
    // the bottom. fittedContentHeight adds the card's own padding and border
    // inset — contentHeight includes them, so feeding it a raw content height
    // silently shaves that inset off the content area instead.
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight + Style.space(16))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // --- the pet -------------------------------------------------------

        Rectangle {
          width: parent.width
          height: Style.space(150)
          radius: Style.cornerRadius > 0 ? Style.space(10) : 0
          color: Qt.alpha(Color.accent, 0.08)
          border.width: 1
          border.color: Qt.alpha(Color.accent, 0.25)

          Text {
            anchors.centerIn: parent
            visible: root.petIsOut
            text: "Out playing…"
            color: Qt.alpha(root.foreground, 0.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            renderType: Text.NativeRendering
          }

          PetSprite {
            id: bigPet
            anchors.centerIn: parent
            visible: !root.petIsOut
            width: Style.space(80)
            height: Style.space(80)
            form: root.ready ? root.petService.form : "egg"
            anim: {
              if (!root.ready) return "idle"
              if (root.petService.transientAnim !== "") return root.petService.transientAnim
              // Teens hanging out in their room are on their laptop, obviously.
              if (root.petService.stage === "teen" && root.petService.stateAnim === "idle")
                return "laptop"
              return root.petService.stateAnim
            }
            frameMs: 600
            tint: Color.accent

            // Being scrubbed is wobbly business.
            SequentialAnimation {
              running: petArea.pressed && petArea.scrubbing
              loops: Animation.Infinite
              NumberAnimation { target: bigPet; property: "rotation"; to: -7; duration: 90 }
              NumberAnimation { target: bigPet; property: "rotation"; to: 7; duration: 90 }
              onStopped: bigPet.rotation = 0
            }
          }

          // Click = pet; press and rub = scrub the dirt off. Same
          // click-vs-gesture threshold as the roam grab.
          MouseArea {
            id: petArea
            anchors.fill: bigPet
            enabled: !root.petIsOut
            cursorShape: pressed && scrubbing ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            property real lastX: 0
            property real lastY: 0
            property real travel: 0
            property bool scrubbing: false

            onPressed: function(mouse) {
              lastX = mouse.x
              lastY = mouse.y
              travel = 0
              scrubbing = false
            }
            property real travelSinceSparkle: 0
            property int sparkleIndex: 0

            onPositionChanged: function(mouse) {
              if (!pressed) return
              var moved = Math.abs(mouse.x - lastX) + Math.abs(mouse.y - lastY)
              lastX = mouse.x
              lastY = mouse.y
              travel += moved
              if (!scrubbing && travel > 12) scrubbing = true
              if (scrubbing && root.ready && root.petService.dirtiness > 0) {
                root.petService.scrub(moved * 0.03)
                travelSinceSparkle += moved
                if (travelSinceSparkle > 50) {
                  travelSinceSparkle = 0
                  var item = sparkles.itemAt(sparkleIndex % sparkles.count)
                  if (item) item.pop(bigPet.x + mouse.x, bigPet.y + mouse.y)
                  sparkleIndex += 1
                }
              }
            }
            onReleased: {
              if (scrubbing) {
                if (root.ready) root.petService.flushPet()
              } else {
                if (root.ready) root.petService.petThePet()
                panelHeart.pop()
              }
            }
          }

          // Soap sparkles while scrubbing: a small pool of them popping in
          // round-robin around the cursor, so a vigorous scrub foams visibly.
          Repeater {
            id: sparkles
            model: 4

            Text {
              id: sparkleItem
              text: "✦"
              color: Color.accent
              font.pixelSize: Style.space(18)
              opacity: 0

              function pop(cx, cy) {
                x = cx - width / 2 + (Math.random() * 44 - 22)
                y = cy - height / 2 + (Math.random() * 28 - 14)
                sparkleAnimation.restart()
              }

              ParallelAnimation {
                id: sparkleAnimation
                NumberAnimation {
                  target: sparkleItem; property: "y"
                  from: sparkleItem.y; to: sparkleItem.y - Style.space(22)
                  duration: 600
                }
                NumberAnimation {
                  target: sparkleItem; property: "rotation"
                  from: 0; to: Math.random() < 0.5 ? -40 : 40; duration: 600
                }
                SequentialAnimation {
                  NumberAnimation { target: sparkleItem; property: "opacity"; from: 0; to: 1; duration: 100 }
                  NumberAnimation { target: sparkleItem; property: "opacity"; to: 0; duration: 500 }
                }
              }
            }
          }

          // Same recipe as the roaming view: three letters and a slow pulse.
          Text {
            id: panelZzz
            visible: !root.petIsOut && root.ready && root.petService.sleeping
            text: "z z Z"
            color: Color.accent
            font.pixelSize: Style.space(16)
            anchors.left: bigPet.right
            anchors.leftMargin: -Style.space(6)
            anchors.bottom: bigPet.top
            anchors.bottomMargin: -Style.space(12)

            SequentialAnimation {
              running: panelZzz.visible
              loops: Animation.Infinite
              NumberAnimation { target: panelZzz; property: "opacity"; from: 0.25; to: 1; duration: 1300 }
              NumberAnimation { target: panelZzz; property: "opacity"; from: 1; to: 0.25; duration: 1300 }
            }
          }

          // The emote bubble, floating at the pet's shoulder when it is home.
          Item {
            id: panelEmote
            visible: !root.petIsOut && root.ready
              && root.petService.emoteName !== ""
              && root.petService.transientAnim === ""
              && panelEmoteImage.status === Image.Ready
            width: Style.space(32)
            height: width
            anchors.left: bigPet.right
            anchors.leftMargin: -Style.space(10)
            anchors.bottom: bigPet.top
            anchors.bottomMargin: -Style.space(14)

            property real bob: 0
            SequentialAnimation on bob {
              running: panelEmote.visible
              loops: Animation.Infinite
              NumberAnimation { from: 0; to: -3; duration: 900; easing.type: Easing.InOutQuad }
              NumberAnimation { from: -3; to: 0; duration: 900; easing.type: Easing.InOutQuad }
            }
            transform: Translate { y: panelEmote.bob }

            Image {
              id: panelEmoteImage
              anchors.fill: parent
              source: root.ready && root.petService.emoteName !== ""
                ? Qt.resolvedUrl("assets/sprites/" + root.petService.emoteName + ".png") : ""
              smooth: false
              mipmap: false
              fillMode: Image.PreserveAspectFit
              visible: false
            }

            MultiEffect {
              anchors.fill: panelEmoteImage
              source: panelEmoteImage
              colorization: 1
              // Same tint as the pet in the panel.
              colorizationColor: Color.accent
            }
          }

          Text {
            id: panelHeart
            text: "♥"
            color: Color.accent
            font.pixelSize: Style.space(20)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            opacity: 0

            function pop() { panelHeartAnimation.restart() }

            ParallelAnimation {
              id: panelHeartAnimation
              NumberAnimation {
                target: panelHeart; property: "anchors.verticalCenterOffset"
                from: -Style.space(20); to: -Style.space(50); duration: 700
              }
              SequentialAnimation {
                NumberAnimation { target: panelHeart; property: "opacity"; from: 0; to: 1; duration: 150 }
                NumberAnimation { target: panelHeart; property: "opacity"; to: 0; duration: 550 }
              }
            }
          }
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.ready ? root.petService.moodLabel : "Waking up…"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
          renderType: Text.NativeRendering
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.ready
            ? root.petService.stageLabel + " · "
              + Math.floor(root.petService.ageMinutes / 60) + "h"
              + Math.floor(root.petService.ageMinutes % 60) + "m old"
              + (root.petService.generation > 1
                ? " · Gen " + root.petService.generation : "")
            : ""
          color: Qt.alpha(root.foreground, 0.6)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          renderType: Text.NativeRendering
        }

        Button {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.ready && root.petService.stage === "adult"
          text: "Let it go"
          tooltipText: "Say goodbye — a new egg will appear (Gen "
            + (root.ready ? root.petService.generation + 1 : 2) + ")"
          fontFamily: root.fontFamily
          onClicked: farewellConfirm.opened = true
        }

        // --- needs ---------------------------------------------------------

        Column {
          width: parent.width
          spacing: Style.space(8)

          Repeater {
            model: root.needs

            // One row per need: the gauge block on the left, its care button
            // (when the need has one) right next to it. A fixed action slot
            // on every row keeps all the gauges the same length.
            Row {
              id: needRow
              required property var modelData
              width: parent.width
              spacing: Style.space(10)

              readonly property real actionSlot: Style.space(104)

              Column {
                width: needRow.width - needRow.actionSlot - needRow.spacing
                spacing: Style.space(3)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: needRow.modelData.label
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  renderType: Text.NativeRendering
                }

                Rectangle {
                  width: parent.width
                  height: Style.space(6)
                  radius: height / 2
                  color: Qt.alpha(root.foreground, 0.15)

                  Rectangle {
                    // The bar shows wellbeing, so a rising need drains it.
                    width: parent.width * (1 - needRow.modelData.value / 100)
                    height: parent.height
                    radius: parent.radius
                    color: needRow.modelData.value >= 60
                      ? Color.urgent : Color.accent

                    Behavior on width { NumberAnimation { duration: 300 } }
                  }
                }

                Text {
                  text: needRow.modelData.hint
                  color: Qt.alpha(root.foreground, 0.6)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption !== undefined ? Style.font.caption : Style.font.bodySmall
                  renderType: Text.NativeRendering
                }
              }

              Item {
                width: needRow.actionSlot
                height: needRow.height
                anchors.verticalCenter: parent.verticalCenter

                Button {
                  anchors.centerIn: parent
                  visible: needRow.modelData.action !== ""
                  text: needRow.modelData.actionLabel
                  tooltipText: needRow.modelData.actionTip
                  fontFamily: root.fontFamily
                  enabled: root.ready
                    && (needRow.modelData.action !== "roam" || root.petService.canRoam)
                    && (needRow.modelData.needsHome !== true || !root.petIsOut)
                  opacity: enabled ? 1 : 0.4
                  onClicked: root.runAction(needRow.modelData.action)
                }
              }
            }
          }
        }

      }

      ConfirmDialog {
        id: farewellConfirm
        anchors.fill: parent
        message: "Let your companion go? It will fly home, and a new egg will appear."
        confirmText: "Say goodbye"
        onConfirmed: {
          opened = false
          if (root.ready) root.petService.sendOff()
        }
        onCanceled: opened = false
      }
    }
  }
}
