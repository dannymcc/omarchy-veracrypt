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

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color rowFill: Style.hoverFillFor(foreground, Color.accent)
  readonly property color mountedFill: Style.selectedFillFor(foreground, Color.accent)

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
        spacing: Style.space(12)

        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: "VeraCrypt"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            width: parent.width - refreshButton.width - Style.space(8)
            elide: Text.ElideRight
          }

          Button {
            id: refreshButton
            text: "Refresh"
            foreground: root.foreground
            fontFamily: root.fontFamily
            bordered: true
            enabled: !root.busy
            onClicked: root.refresh()
          }
        }

        Text {
          width: parent.width
          text: root.message
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          visible: root.message.length > 0
        }

        Text {
          width: parent.width
          text: "No vaults configured"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          horizontalAlignment: Text.AlignHCenter
          visible: root.vaults.length === 0
        }

        ListView {
          id: vaultList
          width: parent.width
          height: Math.min(Style.space(360), count * (Style.space(66) + Style.space(8)))
          visible: count > 0
          clip: true
          model: root.vaults
          spacing: Style.space(8)

          delegate: Rectangle {
            width: vaultList.width
            height: Style.space(66)
            radius: Style.cornerRadius
            color: modelData.mounted ? root.mountedFill : root.rowFill
            border.width: 1
            border.color: modelData.mounted ? Color.accent : Util.alpha(root.foreground, 0.18)

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(10)

              Column {
                width: parent.width - mountButton.width - openButton.width - Style.space(20)
                spacing: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: modelData.name
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: modelData.mounted ? modelData.mountPoint : modelData.container
                  color: modelData.containerExists ? root.dim : root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideMiddle
                  width: parent.width
                }
              }

              Button {
                id: mountButton
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.mounted ? "Unmount" : "Mount"
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                enabled: !root.busy && (modelData.mounted || modelData.containerExists)
                onClicked: root.runAction(modelData.mounted ? "unmount" : "mount", modelData.name)
              }

              Button {
                id: openButton
                anchors.verticalCenter: parent.verticalCenter
                text: "Open"
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                enabled: !root.busy && modelData.mounted
                onClicked: root.runAction("open", modelData.name)
              }
            }
          }
        }
      }
    }
  }
}
