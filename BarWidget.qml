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
  // Closed padlock until something is mounted, open padlock once it is: the
  // bar carries one glyph, so the glyph has to carry the state.
  readonly property string vaultIcon: mountedCount > 0 ? "󰌿" : "󰌾"
  // Resolved from this file's own location rather than a hardcoded $HOME
  // path, so the plugin works wherever it is installed.
  readonly property string scriptPath: Qt.resolvedUrl("scripts/veracrypt-vaults")
    .toString().replace(/^file:\/\//, "")

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

  // Same open/close/toggle surface every first-party widget exposes, so the
  // dropdown can be driven from a keybinding or a script:
  //   omarchy-shell io.github.dannymcc.veracrypt-vaults toggle
  IpcHandler {
    target: "io.github.dannymcc.veracrypt-vaults"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.broadcast("refresh"); return "ok" }
    function status(): string { return root.statusText }
  }

  Timer {
    interval: root.pollMs
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProcess
    command: [root.scriptPath, "status"]
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
          root.mountedCount = 0
          root.totalCount = 0
          root.statusText = "Vaults"
        }
      }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vaultIcon
    tooltipText: root.totalCount === 0
      ? "VeraCrypt vaults"
      : root.mountedCount + " of " + root.totalCount + " vaults mounted"
    fixedWidth: root.vertical ? root.barSize : -1
    fixedHeight: root.barSize
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.MiddleButton) root.refresh()
    }
  }
}
