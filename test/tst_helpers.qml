import QtQuick
import QtTest
import ".."
import Omarchy.PluginPresentation 1.0 as Presentation

Item {
  width: 320
  height: 180

  Presentation.PanelKeyCatcher {
    id: keys
    width: 100
    height: 80
  }
  Presentation.PanelSlider {
    id: slider
    y: 100
    width: 200
    minimum: 0
    maximum: 1
    step: 0.05
    value: 0.2
  }

  SignalSpy { id: closeSpy; target: keys; signalName: "closeRequested" }
  SignalSpy { id: tabSpy; target: keys; signalName: "tabRequested" }
  SignalSpy { id: releaseSpy; target: slider; signalName: "released" }

  TestCase {
    name: "OmagotchiLocalHelpers"
    when: windowShown

    function init() {
      closeSpy.clear()
      tabSpy.clear()
      releaseSpy.clear()
      keys.forceActiveFocus()
    }

    function test_panelKeys() {
      keyClick(Qt.Key_Escape)
      compare(closeSpy.count, 1)
      keyClick(Qt.Key_Tab)
      compare(tabSpy.count, 1)
    }

    function test_volumeSliderSnapsAndReleases() {
      var area = findChild(slider, "mouseArea")
      verify(area !== null)
      mousePress(area, 103, area.height / 2, Qt.LeftButton)
      compare(slider.liveValue, 0.5)
      mouseMove(area, 151, area.height / 2)
      compare(slider.liveValue, 0.75)
      mouseRelease(area, 151, area.height / 2, Qt.LeftButton)
      compare(releaseSpy.count, 1)
      compare(releaseSpy.signalArguments[0][0], 0.75)
    }
  }
}
