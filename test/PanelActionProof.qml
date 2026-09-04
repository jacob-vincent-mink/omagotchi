import QtQuick
import ".."

Panel {
  id: root

  property string proofPhase: "WAITING"

  Component.onCompleted: open()

  Rectangle {
    x: 16
    y: 16
    width: 220
    height: 72
    z: 1000
    color: root.proofPhase === "COMPLETE" ? "#28523b" : "#59452b"

    Text {
      anchors.centerIn: parent
      text: root.proofPhase
      color: "white"
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.ready
      onClicked: {
        root.petService.hungerLevel = 25
        root.petService.dirtLevel = 25
        root.petService.lonelinessLevel = 25
        root.petService.boredomLevel = 25
        root.petService.feedNow()
        root.petService.scrub(25)
        root.petService.petThePet()
        root.petService.setRoamEnabled(true)
        root.proofPhase = root.petService.dirtiness === 0
          && root.petService.loneliness <= 15
          && root.petService.settings.roamEnabled === true
          ? "COMPLETE" : "FAILED"
      }
    }
  }
}
