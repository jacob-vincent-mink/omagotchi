import QtQuick
import Omarchy.PluginPresentation 1.0

// Bar button: the pet's face, breathing slowly. Left click opens its home,
// middle click is a quick pet on the head.
Item {
  id: root

  readonly property var petService: SharedService
  property var inputRegions: [{ x: 0, y: 0, width: width, height: height }]
  readonly property bool serviceReady: !!petService && petService.initialized === true
  readonly property string tooltipText: serviceReady ? petService.moodLabel : "Omagotchi"

  implicitWidth: Style.bar.statusSlot
  implicitHeight: Style.bar.size

  Rectangle {
    id: button
    anchors.fill: parent
    color: "transparent"

    Item {
      id: content
      anchors.centerIn: parent
      width: Style.font.icon
      height: Style.font.icon

      PetSprite {
        anchors.fill: parent
        form: root.serviceReady ? root.petService.form : "egg"
        anim: root.serviceReady ? root.petService.stateAnim : "idle"
        // An unhappy pet fidgets in the bar to catch the eye.
        frameMs: root.serviceReady
          && root.petService.mood !== "happy" && root.petService.mood !== "egg"
          && root.petService.mood !== "sleeping"
          ? 350 : 900
        tint: root.serviceReady ? Color.bar.text : Color.alpha(Color.bar.text, 0.45)
      }
    }

    MouseArea {
      id: pointer
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onPressed: function(mouse) {
        if (mouse.button === Qt.LeftButton)
          runtime.requestSurfaceIntent("panel", "toggle")
        else if (mouse.button === Qt.MiddleButton && root.serviceReady)
          root.petService.petThePet()
      }
    }
  }
}
