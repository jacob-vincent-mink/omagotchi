import QtQuick

// Bar button: the pet's face, breathing slowly. Left click opens its home,
// middle click is a quick pet on the head.
Item {
  id: root

  readonly property var petService: SharedService
  property var inputRegions: [{ x: 0, y: 0, width: width, height: height }]
  readonly property bool serviceReady: !!petService && petService.initialized === true
  readonly property string tooltipText: serviceReady ? petService.moodLabel : "Omagotchi"

  implicitWidth: 44
  implicitHeight: 44
  width: implicitWidth
  height: implicitHeight

  Rectangle {
    id: button
    anchors.fill: parent
    radius: 8
    color: pointer.containsMouse ? "#25344a" : "transparent"
    border.width: pointer.containsMouse ? 1 : 0
    border.color: "#5fa8ff"

    Item {
      id: content
      anchors.centerIn: parent
      width: 32
      height: 32

      PetSprite {
        anchors.fill: parent
        form: root.serviceReady ? root.petService.form : "egg"
        anim: root.serviceReady ? root.petService.stateAnim : "idle"
        // An unhappy pet fidgets in the bar to catch the eye.
        frameMs: root.serviceReady
          && root.petService.mood !== "happy" && root.petService.mood !== "egg"
          && root.petService.mood !== "sleeping"
          ? 350 : 900
        tint: root.serviceReady ? "#f4f7fb" : "#7c8796"
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
