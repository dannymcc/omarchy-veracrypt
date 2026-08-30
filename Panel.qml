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

  // Whether the config file exists yet. An unconfigured machine gets the add
  // form rather than an error: hand-writing a TSV is not a prerequisite.
  property bool configured: false
  property string configPath: ""

  property bool addOpen: false
  property string newName: ""
  property string newContainer: ""
  property string newMount: ""
  // "" while the picker is closed, otherwise the field it will fill.
  property string browseTarget: ""
  property string browsePath: ""
  property string browseParent: ""
  property var browseEntries: []
  // -3 new folder, -2 use this folder, -1 "..", 0.. index into the visible
  // entries. The negative rows only exist in the mode that offers them.
  property int browseIndex: -1
  property bool browseCursorActive: false
  property bool showAllFiles: false
  property bool newFolderOpen: false
  property string newFolderName: ""

  // Containers have no magic bytes, so the extension is the only hint there
  // is. Everything else is still one click away behind "Show all files".
  readonly property var browseVisibleEntries: {
    if (browseTarget !== "container" || showAllFiles) return browseEntries
    return browseEntries.filter(function(e) { return e.dir === true || e.likely === true })
  }
  readonly property int hiddenFileCount: browseEntries.length - browseVisibleEntries.length

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color rowFill: Style.hoverFillFor(foreground, Color.accent)
  readonly property color mountedFill: Style.selectedFillFor(foreground, Color.accent)

  // Resolved from this file's own location, so the plugin keeps working
  // wherever it happens to be installed.
  readonly property string scriptPath: Qt.resolvedUrl("scripts/veracrypt-vaults")
    .toString().replace(/^file:\/\//, "")

  readonly property int mountedCount: {
    var n = 0
    for (var i = 0; i < vaults.length; i++) if (vaults[i].mounted) n++
    return n
  }

  readonly property bool addReady: newName.trim() !== ""
    && newContainer.trim() !== ""
    && newMount.trim() !== ""

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

  function runScript(args) {
    busy = true
    actionProcess.command = [root.scriptPath].concat(args)
    actionProcess.running = true
  }

  function runAction(action, name) {
    message = action + " " + name + "..."
    runScript([action, name])
  }

  function openAddForm() {
    closeBrowser()
    addOpen = true
    Qt.callLater(function() { nameField.forceActiveFocus() })
  }

  function cancelAdd() {
    addOpen = false
    closeBrowser()
    newName = ""
    newContainer = ""
    newMount = ""
  }

  function addVault() {
    if (!addReady || busy) return
    message = "Adding " + newName.trim() + "..."
    runScript(["add", newName.trim(), newContainer.trim(), newMount.trim()])
    cancelAdd()
  }

  function unmountAll() {
    if (busy) return
    message = "Unmounting all vaults..."
    runScript(["unmount-all"])
  }

  function removeVault(name) {
    if (busy) return
    message = "Removing " + name + "..."
    runScript(["remove", name])
  }

  // The picker lives inside the panel on purpose. An external chooser (zenity
  // and friends) is unusable here: the panel dismisses on any click outside
  // it, so the dialog takes the panel down with it before it can hand a path
  // back, losing the half-filled form.
  function browse(target) {
    browseTarget = target
    var seed = target === "container" ? newContainer.trim() : newMount.trim()
    // Start where the field already points, so a typo is a step away from a
    // fix rather than a walk back down from $HOME.
    listDirectory(seed !== "" ? seed.replace(/\/[^\/]*$/, "") : "")
    // The form's text field had the keys until now; the picker needs them for
    // its own arrow navigation.
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function listDirectory(path) {
    browseProcess.command = [root.scriptPath, "browse", path === "" ? "~" : path,
      browseTarget === "container" ? "files" : "dirs"]
    browseProcess.running = true
  }

  function closeBrowser() {
    var wasBrowsing = browseTarget
    if (addOpen && wasBrowsing !== "") {
      Qt.callLater(function() {
        if (wasBrowsing === "container") containerField.forceActiveFocus()
        else mountField.forceActiveFocus()
      })
    }
    browseTarget = ""
    browseEntries = []
    browseIndex = -1
    browseCursorActive = false
    showAllFiles = false
    newFolderOpen = false
    newFolderName = ""
  }

  function lowestBrowseIndex() {
    if (browseTarget === "mount") return -3
    return browseParent === "" ? 0 : -1
  }

  function moveBrowseCursor(dy) {
    browseCursorActive = true
    var lowest = lowestBrowseIndex()
    var next = browseIndex + dy
    // The ".." row does not exist at the filesystem root.
    if (next === -1 && browseParent === "") next = dy > 0 ? 0 : -2
    if (next < lowest) next = lowest
    if (next > browseVisibleEntries.length - 1) next = browseVisibleEntries.length - 1
    browseIndex = next
    if (next >= 0) entryList.positionViewAtIndex(next, ListView.Contain)
  }

  function activateBrowseCursor() {
    if (browseIndex === -3) {
      openNewFolder()
      return
    }
    if (browseIndex === -2) {
      useCurrentDirectory()
      return
    }
    if (browseIndex < 0) {
      if (browseParent !== "") listDirectory(browseParent)
      return
    }
    if (browseIndex < browseVisibleEntries.length) chooseEntry(browseVisibleEntries[browseIndex])
  }

  function chooseEntry(entry) {
    if (entry.dir && browseTarget === "container") {
      listDirectory(entry.path)
      return
    }
    if (entry.dir) {
      // A directory click in mount mode walks into it; "Use this folder"
      // is what picks one, so nested directories stay reachable.
      listDirectory(entry.path)
      return
    }
    root.newContainer = entry.path
    closeBrowser()
  }

  function openNewFolder() {
    newFolderName = ""
    newFolderOpen = true
    Qt.callLater(function() { newFolderField.forceActiveFocus() })
  }

  function createFolder() {
    if (newFolderName.trim() === "") return
    folderProcess.command = [root.scriptPath, "mkdir", browsePath, newFolderName.trim()]
    folderProcess.running = true
  }

  function useCurrentDirectory() {
    if (browseTarget !== "mount") return
    root.newMount = browsePath
    closeBrowser()
  }

  onOpenedChanged: {
    if (!opened) {
      // The draft survives a dismissal — closing the panel by clicking away
      // should not cost someone a path they just typed. Cancel and a
      // successful add are what clear it.
      closeBrowser()
      return
    }
    // With nothing configured, the form is the only useful thing the panel
    // has to offer, so it opens on that.
    if (vaults.length === 0 && !addOpen) openAddForm()
  }

  Timer {
    interval: 8000
    running: root.opened
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
          root.vaults = data.vaults || []
          root.configured = data.configured === true
          root.configPath = data.configPath || ""
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
      // Refresh through the widget so the bar's count follows the panel.
      if (root.hostWidget && typeof root.hostWidget.refresh === "function") root.hostWidget.refresh()
      else root.refresh()
    }
  }

  Process {
    id: folderProcess
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text)
          if (data.ok) {
            // Made it, so use it: that is what the folder was created for.
            root.newMount = data.path
            root.closeBrowser()
          } else {
            root.message = data.error || "Could not create the folder"
          }
        } catch (e) {
          root.message = "Could not create the folder"
        }
      }
    }
  }

  Process {
    id: browseProcess
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text)
          root.browsePath = data.path || ""
          root.browseParent = data.parent || ""
          root.browseEntries = data.entries || []
          root.newFolderOpen = false
          root.browseIndex = root.lowestBrowseIndex()
        } catch (e) {
          root.message = "Could not read that directory"
          root.closeBrowser()
        }
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: {
        if (root.browseTarget !== "") root.closeBrowser()
        else if (root.addOpen) root.cancelAdd()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (root.browseTarget !== "" && dy !== 0) root.moveBrowseCursor(dy)
      }
      onActivateRequested: if (root.browseTarget !== "") root.activateBrowseCursor()
      onTextKey: function(text) {
        if (root.addOpen || root.browseTarget !== "") return
        if (text === "r") root.refresh()
        else if (text === "a") root.openAddForm()
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

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

          PanelActionButton {
            id: refreshButton
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰑐"
            tooltipText: "Refresh"
            foreground: root.foreground
            fontFamily: root.fontFamily
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
          text: root.configured ? "No vaults configured" : "No vaults yet — add your first below."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          visible: root.vaults.length === 0 && root.browseTarget === ""
        }

        ListView {
          id: vaultList
          width: parent.width
          height: Math.min(Style.space(320), count * (Style.space(62) + Style.space(6)))
          visible: count > 0 && root.browseTarget === ""
          clip: true
          model: root.vaults
          spacing: Style.space(6)

          delegate: Rectangle {
            width: vaultList.width
            height: Style.space(62)
            radius: Style.cornerRadius
            color: modelData.mounted ? root.mountedFill : root.rowFill
            border.width: 1
            border.color: modelData.mounted ? Color.accent : Util.alpha(root.foreground, 0.18)

            // The name gets the whole row. Sharing the line with the buttons
            // cut it off after about a dozen characters in a panel this
            // narrow, and the name is the part you are reading.
            Column {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(3)

              Text {
                width: parent.width
                text: modelData.name
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - mountButton.width - openButton.width
                    - removeButton.width - Style.space(18)
                  text: modelData.mounted ? modelData.mountPoint : modelData.container
                  color: modelData.containerExists ? root.dim : root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideMiddle
                }

                Button {
                  id: mountButton
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.mounted ? "Unmount" : "Mount"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  fontSize: Style.font.bodySmall
                  bordered: true
                  enabled: !root.busy && (modelData.mounted || modelData.containerExists)
                  onClicked: root.runAction(modelData.mounted ? "unmount" : "mount", modelData.name)
                }

                PanelActionButton {
                  id: openButton
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: "󰝰"
                  tooltipText: "Open " + modelData.mountPoint
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  enabled: !root.busy && modelData.mounted
                  onClicked: root.runAction("open", modelData.name)
                }

                PanelActionButton {
                  id: removeButton
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: "󰅙"
                  tooltipText: modelData.mounted
                    ? "Unmount before removing"
                    : "Remove " + modelData.name + " from the config"
                  foreground: root.dim
                  hoverColor: root.urgent
                  fontFamily: root.fontFamily
                  enabled: !root.busy && !modelData.mounted
                  onClicked: root.removeVault(modelData.name)
                }
              }
            }
          }
        }

        PanelSeparator {
          width: parent.width
          visible: root.vaults.length > 0 && !root.addOpen && root.browseTarget === ""
        }

        Row {
          width: parent.width
          spacing: Style.space(6)
          visible: !root.addOpen && root.browseTarget === ""

          Button {
            text: "Add vault"
            iconText: "󰐕"
            foreground: root.busy ? root.dim : root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            bordered: true
            enabled: !root.busy
            onClicked: root.openAddForm()
          }

          // Only worth its space once there is more than one thing to close.
          Button {
            text: "Unmount all"
            iconText: "󰌾"
            foreground: root.busy ? root.dim : root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            bordered: true
            visible: root.mountedCount > 1
            enabled: !root.busy
            onClicked: root.unmountAll()
          }
        }

        Column {
          id: addForm
          width: parent.width
          spacing: Style.space(6)
          visible: root.addOpen && root.browseTarget === ""

          TextField {
            id: nameField
            width: containerField.width
            placeholderText: "Name"
            foreground: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            text: root.newName
            onTextChanged: if (text !== root.newName) root.newName = text
            onAccepted: containerField.forceActiveFocus()
            Keys.onEscapePressed: root.cancelAdd()
          }

          Row {
            width: parent.width
            spacing: Style.space(6)

            TextField {
              id: containerField
              width: parent.width - (containerBrowse.visible ? containerBrowse.width + Style.space(6) : 0)
              placeholderText: "Container file"
              foreground: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              text: root.newContainer
              onTextChanged: if (text !== root.newContainer) root.newContainer = text
              onAccepted: text.trim() === "" ? root.browse("container") : mountField.forceActiveFocus()
              Keys.onEscapePressed: root.cancelAdd()
            }

            PanelActionButton {
              id: containerBrowse
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰈔"
              tooltipText: "Choose a container file"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              enabled: root.browseTarget === ""
              onClicked: root.browse("container")
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(6)

            TextField {
              id: mountField
              width: parent.width - (mountBrowse.visible ? mountBrowse.width + Style.space(6) : 0)
              placeholderText: "Mount directory"
              foreground: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              text: root.newMount
              onTextChanged: if (text !== root.newMount) root.newMount = text
              onAccepted: text.trim() === "" ? root.browse("mount") : root.addVault()
              Keys.onEscapePressed: root.cancelAdd()
            }

            PanelActionButton {
              id: mountBrowse
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰉋"
              tooltipText: "Choose a mount directory"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              enabled: root.browseTarget === ""
              onClicked: root.browse("mount")
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(6)
            layoutDirection: Qt.RightToLeft

            Button {
              text: "Add"
              foreground: root.addReady && !root.busy ? root.foreground : root.dim
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              bordered: true
              enabled: root.addReady && !root.busy
              onClicked: root.addVault()
            }

            Button {
              text: "Cancel"
              foreground: root.dim
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              bordered: true
              onClicked: root.cancelAdd()
            }
          }
        }

        // ---------------------------------------------------------- picker
        Column {
          id: browser
          width: parent.width
          spacing: Style.space(6)
          visible: root.browseTarget !== ""

          Text {
            width: parent.width
            text: root.browseTarget === "container" ? "Choose a container file" : "Choose a mount directory"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            text: root.browsePath
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideMiddle
          }

          ListView {
            id: entryList
            width: parent.width
            height: Style.space(210)
            clip: true
            model: root.browseVisibleEntries
            spacing: Style.space(2)

            header: Column {
              width: entryList.width
              spacing: Style.space(2)

              CursorSurface {
                width: entryList.width - Style.space(2)
                height: Style.space(24)
                visible: root.browseTarget === "mount" && !root.newFolderOpen
                foreground: root.foreground
                fill: root.rowFill
                hasCursor: root.browseCursorActive && root.browseIndex === -3

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰝮  New folder here"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: { root.browseCursorActive = true; root.browseIndex = -3 }
                  onClicked: root.openNewFolder()
                }
              }

              Row {
                width: entryList.width - Style.space(2)
                spacing: Style.space(4)
                visible: root.newFolderOpen

                TextField {
                  id: newFolderField
                  width: parent.width - createFolderButton.width - Style.space(4)
                  placeholderText: "Folder name"
                  foreground: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  verticalPadding: Style.spacing.controlPaddingY
                  text: root.newFolderName
                  onTextChanged: if (text !== root.newFolderName) root.newFolderName = text
                  onAccepted: root.createFolder()
                  Keys.onEscapePressed: root.newFolderOpen = false
                }

                Button {
                  id: createFolderButton
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Create"
                  foreground: root.newFolderName.trim() === "" ? root.dim : root.foreground
                  fontFamily: root.fontFamily
                  fontSize: Style.font.bodySmall
                  bordered: true
                  enabled: root.newFolderName.trim() !== ""
                  onClicked: root.createFolder()
                }
              }

              CursorSurface {
                width: entryList.width - Style.space(2)
                height: Style.space(24)
                visible: root.browseTarget === "mount" && !root.newFolderOpen
                foreground: root.foreground
                fill: root.rowFill
                hasCursor: root.browseCursorActive && root.browseIndex === -2

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰄬  Use this folder"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: { root.browseCursorActive = true; root.browseIndex = -2 }
                  onClicked: root.useCurrentDirectory()
                }
              }

              CursorSurface {
                width: entryList.width - Style.space(2)
                height: Style.space(24)
                visible: root.browseParent !== ""
                foreground: root.foreground
                fill: root.rowFill
                hasCursor: root.browseCursorActive && root.browseIndex === -1

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰁭  .."
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: { root.browseCursorActive = true; root.browseIndex = -1 }
                  onClicked: root.listDirectory(root.browseParent)
                }
              }
            }

            delegate: CursorSurface {
              id: entryRow
              required property var modelData
              required property int index

              width: entryList.width - Style.space(2)
              height: Style.space(24)
              foreground: root.foreground
              fill: root.rowFill
              hasCursor: root.browseCursorActive && root.browseIndex === index

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: { root.browseCursorActive = true; root.browseIndex = entryRow.index }
                onClicked: root.chooseEntry(entryRow.modelData)
              }

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(6)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                text: (entryRow.modelData.dir ? "󰉋  " : (entryRow.modelData.likely ? "󰌾  " : "󰈔  "))
                  + entryRow.modelData.name
                color: entryRow.modelData.dir || entryRow.modelData.likely ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideMiddle
              }
            }
          }

          Text {
            width: parent.width
            text: root.browseTarget === "container" ? "Nothing here" : "No sub-folders here"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            visible: root.browseEntries.length === 0
          }

          Row {
            width: parent.width
            spacing: Style.space(6)
            layoutDirection: Qt.RightToLeft

            Button {
              text: "Cancel"
              foreground: root.dim
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              bordered: true
              onClicked: root.closeBrowser()
            }

            Button {
              text: root.showAllFiles ? "Containers only" : "Show all files"
              foreground: root.dim
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              bordered: true
              visible: root.browseTarget === "container"
                && (root.hiddenFileCount > 0 || root.showAllFiles)
              onClicked: {
                root.showAllFiles = !root.showAllFiles
                root.browseIndex = root.lowestBrowseIndex()
              }
            }
          }
        }
      }
    }
  }
}
