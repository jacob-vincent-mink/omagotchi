pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui

// The pet's home: a card with the pet front and center, its needs as bars,
// and the care actions. Every action maps to real system maintenance.
Panel {
  id: root
  moduleName: "slcode777.omagotchi"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var petService: null
  readonly property var barIdentity: hostWidget || root

  readonly property bool ready: !!petService && petService.initialized === true
  readonly property color foreground: Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var needs: ready ? [
    { label: "Hunger", value: petService.hunger, hint: petService.pendingUpdates + " pending updates" },
    { label: "Grooming", value: petService.dirtiness, hint: petService.orphanCount + " orphaned packages" },
    { label: "Sleep", value: petService.tiredness, hint: Math.round(petService.uptimeHours) + "h uptime" },
    { label: "Affection", value: petService.loneliness, hint: "click the pet!" }
  ] : []

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    padding: Style.space(14)
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.cappedContentHeight(Style.space(400))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        anchors.fill: parent
        spacing: Style.space(12)

        // --- the pet -------------------------------------------------------

        Rectangle {
          width: parent.width
          height: Style.space(120)
          radius: Style.cornerRadius > 0 ? Style.space(10) : 0
          color: Qt.alpha(Color.accent, 0.08)
          border.width: 1
          border.color: Qt.alpha(Color.accent, 0.25)

          PetSprite {
            id: bigPet
            anchors.centerIn: parent
            width: Style.space(80)
            height: Style.space(80)
            frames: ["idle_a.png", "idle_b.png"]
            frameMs: 600
            tint: Color.accent
          }

          MouseArea {
            anchors.fill: bigPet
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.ready) root.petService.petThePet()
              panelHeart.pop()
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

        // --- needs ---------------------------------------------------------

        Column {
          width: parent.width
          spacing: Style.space(8)

          Repeater {
            model: root.needs

            Column {
              id: needRow
              required property var modelData
              width: parent.width
              spacing: Style.space(3)

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
                    ? Color.error : Color.accent

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
          }
        }

        // --- care actions ----------------------------------------------------

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(8)

          Button {
            text: "Feed"
            tooltipText: "Run the Omarchy update in a terminal"
            fontFamily: root.fontFamily
            enabled: root.ready
            onClicked: root.petService.feed()
          }

          Button {
            text: "Groom"
            tooltipText: "Remove orphaned packages in a terminal"
            fontFamily: root.fontFamily
            enabled: root.ready && root.petService.orphanCount > 0
            opacity: enabled ? 1 : 0.4
            onClicked: root.petService.groom()
          }

          Button {
            text: root.ready && root.petService.settings.roamEnabled === true
              ? "Come home" : "Go play"
            tooltipText: "Let the pet roam along the bottom of the screen"
            fontFamily: root.fontFamily
            enabled: root.ready
            onClicked: root.petService.setRoamEnabled(
              !(root.petService.settings.roamEnabled === true))
          }
        }
      }
    }
  }
}
