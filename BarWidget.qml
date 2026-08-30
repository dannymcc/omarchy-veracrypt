import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "io.github.dannymcc.veracrypt-vaults"

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false
  readonly property int pollMs: Math.max(3, Number(root.setting("pollSeconds", 8))) * 1000
  property int mountedCount: 0
  property int totalCount: 0
  property string statusText: "Vaults"
  property bool busy: false
  readonly property string vaultIcon: "󰌾"

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
    panelLoader.item.bar = root.bar
  }

  onBarChanged: injectPanel()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function refresh() {
    statusProcess.running = true
    if (panelLoader.item) panelLoader.item.refresh()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  Component.onCompleted: refresh()

  Timer {
    interval: root.pollMs
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProcess
    command: ["sh", "-c", "exec \"$HOME/.config/omarchy/plugins/io.github.dannymcc.veracrypt-vaults/scripts/veracrypt-vaults\" status"]
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text)
          root.mountedCount = data.mounted || 0
          root.totalCount = data.total || 0
          root.statusText = root.totalCount > 0
            ? root.mountedCount + "/" + root.totalCount
            : "Vaults"
        } catch (e) {
          root.statusText = "Vaults"
        }
      }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? root.vaultIcon : root.vaultIcon + " " + root.statusText
    tooltipText: "Open VeraCrypt vaults"
    fixedWidth: root.vertical ? root.barSize : -1
    fixedHeight: root.barSize
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.MiddleButton) root.refresh()
    }
  }
}
