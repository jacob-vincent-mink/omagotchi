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
  SignalSpy { id: closeSpy; target: keys; signalName: "closeRequested" }
  SignalSpy { id: tabSpy; target: keys; signalName: "tabRequested" }

  TestCase {
    name: "OmagotchiLocalHelpers"
    when: windowShown

    function init() {
      closeSpy.clear()
      tabSpy.clear()
      keys.forceActiveFocus()
    }

    function test_panelKeys() {
      keyClick(Qt.Key_Escape)
      compare(closeSpy.count, 1)
      keyClick(Qt.Key_Tab)
      compare(tabSpy.count, 1)
    }

  }
}
