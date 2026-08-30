import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "io.github.dannymcc.veracrypt-vaults"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool popoutSwitchClosing: false
  property var vaults: []
  property string message: ""
  property bool busy: false

  function open() {
    root.controller.show()
    refresh()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function closeForPopoutSwitch() {
    popoutSwitchClosing = true
    close()
    Qt.callLater(function() { root.popoutSwitchClosing = false })
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function refresh() {
    if (!busy)
      statusProcess.running = true
  }

  function runAction(action, name) {
    busy = true
    message = action + " " + name + "..."
    actionProcess.command = [
      "sh",
      "-c",
      "exec \"$HOME/.config/omarchy/plugins/io.github.dannymcc.veracrypt-vaults/scripts/veracrypt-vaults\" \"$1\" \"$2\"",
      "veracrypt-vaults",
      action,
      name
    ]
    actionProcess.running = true
  }

  Timer {
    interval: 8000
    running: root.opened
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
          root.vaults = data.vaults || []
          root.message = data.ok ? "" : (data.error || "Could not read vaults")
        } catch (e) {
          root.message = "Could not parse VeraCrypt status"
        }
      }
    }
  }

  Process {
    id: actionProcess
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text)
          root.message = data.message || data.error || ""
        } catch (e) {
          root.message = text.trim()
        }
      }
    }

    onExited: {
      root.busy = false
      root.refresh()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(420)
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r") root.refresh()
      }

      Column {
        id: content
        width: parent.width
        spacing: 12

      Row {
        width: parent.width
        spacing: 8

        Text {
          text: "VeraCrypt"
          color: Color.foreground
          font.pixelSize: 18
          font.bold: true
          verticalAlignment: Text.AlignVCenter
          width: parent.width - refreshButton.width - 8
          elide: Text.ElideRight
        }

        Button {
          id: refreshButton
          text: "Refresh"
          enabled: !root.busy
          onClicked: root.refresh()
        }
      }

      Text {
        width: parent.width
        text: root.message
        color: Color.muted
        font.pixelSize: 12
        wrapMode: Text.Wrap
        visible: root.message.length > 0
      }

      ListView {
        id: vaultList
        width: parent.width
        height: Math.min(360, Math.max(72, count * 74))
        clip: true
        model: root.vaults
        spacing: 8

        delegate: Rectangle {
          width: vaultList.width
          height: 66
          radius: 8
          color: Color.surface
          border.color: modelData.mounted ? Color.accent : Color.border

          Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Column {
              width: parent.width - 172
              spacing: 4
              anchors.verticalCenter: parent.verticalCenter

              Text {
                text: modelData.name
                color: Color.foreground
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: modelData.mounted ? modelData.mountPoint : modelData.container
                color: modelData.containerExists ? Color.muted : Color.urgent
                font.pixelSize: 11
                elide: Text.ElideMiddle
                width: parent.width
              }
            }

            Button {
              width: 76
              text: modelData.mounted ? "Unmount" : "Mount"
              enabled: !root.busy && modelData.containerExists
              onClicked: root.runAction(modelData.mounted ? "unmount" : "mount", modelData.name)
            }

            Button {
              width: 66
              text: "Open"
              enabled: !root.busy && modelData.mounted
              onClicked: root.runAction("open", modelData.name)
            }
          }
        }

        Text {
          anchors.centerIn: parent
          text: "No vaults configured"
          color: Color.muted
          font.pixelSize: 13
          visible: vaultList.count === 0
        }
      }
    }
  }
  }
}
