import QtQuick
import QtQuick.Controls as Controls
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
  property var lightDetails: ({})
  property var statuses: ({})
  property var presets: ({})
  property var presetNames: []
  property string selectedLight: ""
  property string selectedPreset: "Custom"
  property bool sceneMode: false
  property bool busy: false
  property string message: "Loading lights…"
  property bool whiteMode: true
  property int hue: 210
  property int saturation: 70
  property int temperature: 2700
  property int dimming: 80
  // Invalidate status reads when the user edits controls or changes selection.
  property int controlRevision: 0
  property var commandQueue: []
  property var activeRequest: null
  property string processOutput: ""
  property string processError: ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onOpenedChanged: if (opened)
    refreshEverything()
  onSelectedLightChanged: {
    controlRevision++
    modeDebounce.stop()
    brightnessDebounce.stop()
    selectedPreset = "Custom"
    sceneMode = false
  }

  function enqueue(args, callback) {
    commandQueue.push({
      args: args,
      callback: callback
    })
    startNextCommand()
  }
  function startNextCommand() {
    if (commandProcess.running || activeRequest || !commandQueue.length)
      return
    activeRequest = commandQueue.shift()
    processOutput = ""
    processError = ""
    commandProcess.command = [wizctlPath].concat(activeRequest.args.map(function (v) {
      return String(v)
    }))
    busy = true
    commandProcess.running = true
  }
  function finishCommand(exitCode) {
    var request = activeRequest
    activeRequest = null
    busy = commandQueue.length > 0
    if (exitCode === 0) {
      if (request && request.callback) {
        var response
        try {
          response = JSON.parse(processOutput.trim() || "{}")
        } catch (e) {
          message = "Invalid wizctl response: " + e
          startNextCommand()
          return
        }
        try {
          request.callback(response)
        } catch (e) {
          message = "Could not update controls: " + e
          console.warn(message)
        }
      }
    } else
      message = processError.trim() || processOutput.trim() || "wizctl command failed"
    startNextCommand()
  }
  function refreshEverything() {
    var revision = controlRevision
    enqueue(["list", "--json", "--details"], function (obj) {
      lightDetails = obj
      lights = Object.keys(obj).sort()
      if (lights.indexOf(selectedLight) < 0) {
        selectedLight = lights.length ? lights[0] : ""
        revision = controlRevision
      }
    })
    enqueue(["presets", "--json"], function (obj) {
      presets = obj
      presetNames = Object.keys(obj).sort()
    })
    enqueue(["status", "--all"], function (obj) {
      statuses = obj
      if (revision === controlRevision)
        applySelectedStatus()
      message = "Status refreshed"
    })
  }
  function refreshSelected() {
    var name = selectedLight
    var revision = controlRevision
    if (!name)
      return
    enqueue(["status", name], function (obj) {
      statuses[name] = obj
      statuses = Object.assign({}, statuses)
      if (selectedLight === name && revision === controlRevision)
        applySelectedStatus()
    })
  }
  function matchingPreset(st) {
    for (var i = 0; i < presetNames.length; i++) {
      var p = presets[presetNames[i]]
      if (st.sceneId > 0 && st.sceneId === p.sceneId)
        return presetNames[i]
      if (st.dimming !== p.dimming)
        continue
      if (typeof st.temp === "number" && st.temp === p.temp)
        return presetNames[i]
      if (typeof st.r === "number" && st.r === p.r && st.g === p.g && st.b === p.b)
        return presetNames[i]
    }
    return "Custom"
  }
  function applySelectedStatus() {
    var st = statuses[selectedLight]
    if (!st || st.ok === false)
      return
    if (typeof st.dimming === "number")
      dimming = Math.max(10, Math.min(100, st.dimming))
    sceneMode = typeof st.sceneId === "number" && st.sceneId > 0
    if (typeof st.temp === "number") {
      whiteMode = true
      sceneMode = false
      temperature = Math.max(2200, Math.min(6500, st.temp))
    } else if (!sceneMode && typeof st.r === "number") {
      whiteMode = false
      var r = st.r / 255, g = st.g / 255, b = st.b / 255
      var max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min
      saturation = max ? Math.round(d / max * 100) : 0
      if (d) {
        var h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4
        hue = Math.round((h * 60 + 360) % 360)
      }
    }
    selectedPreset = matchingPreset(st)
  }
  function lightIcon(name) {
    var icon = (lightDetails[name] || {}).icon
    return ({
        icon_08: "󰛨",
        icon_11: "󰏔",
        icon_16: "󰛀",
        icon_19: "󱐋"
      })[icon] || "󰌵"
  }
  function runLight(args, successMessage) {
    if (!selectedLight)
      return
    var name = selectedLight
    var revision = controlRevision
    enqueue(args, function () {
      message = successMessage
      if (selectedLight === name && revision === controlRevision)
        refreshSelected()
    })
  }
  function setPower(on) {
    runLight([on ? "on" : "off", selectedLight], (on ? "Turned on " : "Turned off ") + selectedLight)
  }
  function applyMode() {
    controlRevision++
    modeDebounce.stop()
    sceneMode = false
    selectedPreset = "Custom"
    if (whiteMode)
      runLight(["temp", selectedLight, temperature, dimming], "White set to " + temperature + "K")
    else
      runLight(["hsv", selectedLight, hue, saturation, dimming], "Color updated")
  }
  function scheduleMode() {
    controlRevision++
    selectedPreset = "Custom"
    modeDebounce.restart()
  }
  function scheduleBrightness() {
    controlRevision++
    brightnessDebounce.restart()
  }
  function applyBrightness() {
    runLight(["dim", selectedLight, dimming], "Brightness set to " + dimming + "%")
  }
  function applyPreset(name) {
    if (!name)
      return
    controlRevision++
    modeDebounce.stop()
    brightnessDebounce.stop()
    runLight(["preset", selectedLight, name], "Applied preset " + name)
  }
  function rediscover() {
    enqueue(["discover"], function () {
      message = "Discovery finished"
      refreshEverything()
    })
  }
  function savePreset(name) {
    if (!selectedLight || !name.trim())
      return
    // Commit pending slider edits before asking the bulb for the saved state.
    if (modeDebounce.running)
      applyMode()
    if (brightnessDebounce.running) {
      brightnessDebounce.stop()
      applyBrightness()
    }
    var light = selectedLight
    var revision = controlRevision
    enqueue(["save-preset", light, name], function (obj) {
      presets = obj.presets
      presetNames = Object.keys(presets).sort()
      if (selectedLight === light && revision === controlRevision)
        selectedPreset = name
      message = "Saved preset " + name
    })
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
    onExited: function (exitCode) {
      root.finishCommand(exitCode)
    }
  }
  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: if (!root.busy)
      root.enqueue(["status", "--all"], function (obj) {
        root.statuses = obj
      })
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
    onPressed: function (b) {
      if (b === Qt.RightButton)
        root.refreshEverything()
      else
        root.toggle()
    }
  }
  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: popup.fittedContentWidth(360)
    contentHeight: popup.fittedContentHeight(content.implicitHeight, 720)
    Flickable {
      anchors.fill: parent
      clip: true
      contentWidth: width
      contentHeight: content.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      Controls.ScrollBar.vertical: Controls.ScrollBar {}
      WizControls {
        id: content
        width: parent.width
        controller: root
      }
    }
  }
}
