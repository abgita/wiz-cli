import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "com.github.abgita.wizlights"
  ipcTarget: "com.github.abgita.wizlights"

  property string wizctlPath: Quickshell.env("HOME") + "/.local/bin/wizctl"
  property var lights: []
  property var statuses: ({})
  property var presets: ({})
  property var presetNames: []
  property string selectedLight: ""
  property bool busy: false
  property string message: "Loading lights…"
  property bool whiteMode: true
  property int hue: 210
  property int saturation: 70
  property int temperature: 2700
  property int dimming: 80
  property var commandQueue: []
  property var activeRequest: null
  property string processOutput: ""
  property string processError: ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) refreshEverything()

  function enqueue(args, callback) {
    commandQueue.push({ args: args, callback: callback })
    commandQueue = commandQueue.slice()
    startNextCommand()
  }

  function startNextCommand() {
    if (commandProcess.running || activeRequest || commandQueue.length === 0) return
    activeRequest = commandQueue.shift()
    commandQueue = commandQueue.slice()
    processOutput = ""
    processError = ""
    commandProcess.command = [root.wizctlPath].concat(activeRequest.args.map(function(v) { return String(v) }))
    busy = true
    commandProcess.running = true
  }

  function finishCommand(exitCode) {
    var request = activeRequest
    activeRequest = null
    busy = commandQueue.length > 0
    if (exitCode === 0) {
      if (request && request.callback) {
        try { request.callback(JSON.parse(processOutput.trim() || "{}")) }
        catch (e) { message = "Invalid wizctl response" }
      }
    } else {
      message = (processError.trim() || processOutput.trim() || "wizctl command failed")
    }
    startNextCommand()
  }

  function refreshEverything() {
    enqueue(["list", "--json", "--details"], function(obj) {
      lights = Object.keys(obj).sort()
      if (!selectedLight || lights.indexOf(selectedLight) < 0)
        selectedLight = lights.length ? lights[0] : ""
      message = lights.length ? "Loaded " + lights.length + " lights" : "No lights configured"
    })
    enqueue(["presets", "--json"], function(obj) {
      presets = obj
      presetNames = Object.keys(obj).sort()
    })
    enqueue(["status", "--all"], function(obj) {
      statuses = obj
      applySelectedStatus()
      message = "Status refreshed"
    })
  }

  function refreshSelected() {
    if (!selectedLight) return
    enqueue(["status", selectedLight], function(obj) {
      statuses[selectedLight] = obj
      statuses = Object.assign({}, statuses)
      applySelectedStatus()
    })
  }

  function applySelectedStatus() {
    var st = statuses[selectedLight]
    if (!st || st.ok === false) return
    if (typeof st.dimming === "number") dimming = Math.max(10, Math.min(100, st.dimming))
    if (typeof st.temp === "number") {
      whiteMode = true
      temperature = Math.max(2200, Math.min(6500, st.temp))
    } else if (typeof st.r === "number" || typeof st.sceneId === "number") {
      whiteMode = false
    }
  }

  function runLight(args, successMessage) {
    if (!selectedLight) return
    enqueue(args, function() {
      message = successMessage
      refreshSelected()
    })
  }

  function setPower(on) {
    runLight([on ? "on" : "off", selectedLight], (on ? "Turned on " : "Turned off ") + selectedLight)
  }

  function applyMode() {
    if (whiteMode)
      runLight(["temp", selectedLight, temperature, dimming], "White set to " + temperature + "K")
    else
      runLight(["hsv", selectedLight, hue, saturation, dimming], "Color updated")
  }

  function applyBrightness() {
    runLight(["dim", selectedLight, dimming], "Brightness set to " + dimming + "%")
  }

  function applyPreset(name) {
    if (!name) return
    runLight(["preset", selectedLight, name], "Applied preset " + name)
  }

  Process {
    id: commandProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.processOutput = text
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.processError = text
    }
    onExited: function(exitCode) { root.finishCommand(exitCode) }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!root.opened && !root.busy) root.enqueue(["status", "--all"], function(obj) { root.statuses = obj })
  }

  Timer {
    id: brightnessDebounce
    interval: 250
    onTriggered: root.applyBrightness()
  }

  Timer {
    id: modeDebounce
    interval: 250
    onTriggered: root.applyMode()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌵"
    opacity: root.lights.length === 0 ? 0.55 : 1
    onPressed: function(b) {
      if (b === Qt.RightButton) root.refreshEverything()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: popup.fittedContentWidth(Style.space(390))
    contentHeight: popup.fittedContentHeight(content.implicitHeight, Style.space(620))

    ScrollView {
      anchors.fill: parent
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

      ColumnLayout {
        id: content
        width: parent.width
        spacing: Style.space(12)

        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: "Wiz Lights"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Button { text: "↻"; enabled: !root.busy; onClicked: root.refreshEverything() }
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.bar.foreground }

        ComboBox {
          Layout.fillWidth: true
          model: root.lights
          currentIndex: Math.max(0, root.lights.indexOf(root.selectedLight))
          enabled: root.lights.length > 0
          onActivated: {
            root.selectedLight = currentText
            root.applySelectedStatus()
            root.refreshSelected()
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: {
              var st = root.statuses[root.selectedLight]
              return !st ? "Unknown" : st.ok === false ? "Unreachable" : (st.state || "Unknown")
            }
            color: root.bar.foreground
            font.family: root.bar.fontFamily
          }
          Switch {
            checked: {
              var st = root.statuses[root.selectedLight]
              return !!st && st.state === "on"
            }
            enabled: !!root.selectedLight && !root.busy
            onClicked: root.setPower(checked)
          }
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.bar.foreground }

        Text { text: "PRESET"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.bold: true }
        ComboBox {
          Layout.fillWidth: true
          model: root.presetNames
          enabled: !!root.selectedLight && root.presetNames.length > 0
          onActivated: root.applyPreset(currentText)
        }

        RowLayout {
          Layout.fillWidth: true
          Button { text: "RGB"; checkable: true; checked: !root.whiteMode; onClicked: { root.whiteMode = false; root.applyMode() } }
          Button { text: "White"; checkable: true; checked: root.whiteMode; onClicked: { root.whiteMode = true; root.applyMode() } }
        }

        ColumnLayout {
          Layout.fillWidth: true
          visible: root.whiteMode
          Text { text: "Temperature  " + root.temperature + "K"; color: root.bar.foreground; font.family: root.bar.fontFamily }
          Slider {
            Layout.fillWidth: true; from: 2200; to: 6500; stepSize: 50; value: root.temperature
            onMoved: { root.temperature = Math.round(value / 50) * 50; modeDebounce.restart() }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          visible: !root.whiteMode
          Text { text: "Hue  " + root.hue + "°"; color: root.bar.foreground; font.family: root.bar.fontFamily }
          Slider {
            Layout.fillWidth: true; from: 0; to: 360; stepSize: 1; value: root.hue
            onMoved: { root.hue = Math.round(value); modeDebounce.restart() }
          }
          Text { text: "Saturation  " + root.saturation + "%"; color: root.bar.foreground; font.family: root.bar.fontFamily }
          Slider {
            Layout.fillWidth: true; from: 0; to: 100; stepSize: 1; value: root.saturation
            onMoved: { root.saturation = Math.round(value); modeDebounce.restart() }
          }
        }

        Text { text: "Brightness  " + root.dimming + "%"; color: root.bar.foreground; font.family: root.bar.fontFamily }
        Slider {
          Layout.fillWidth: true; from: 10; to: 100; stepSize: 1; value: root.dimming
          onMoved: { root.dimming = Math.round(value); brightnessDebounce.restart() }
        }

        Text {
          Layout.fillWidth: true
          text: root.busy ? "Working…" : root.message
          color: Qt.darker(root.bar.foreground, 1.35)
          font.family: root.bar.fontFamily
          elide: Text.ElideRight
        }
      }
    }
  }
}
