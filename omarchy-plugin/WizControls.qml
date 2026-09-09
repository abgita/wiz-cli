pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQml.Models

ColumnLayout {
  id: ui
  required property var controller
  readonly property var ctl: controller
  readonly property color ink: ctl.bar.foreground
  readonly property color accent: "#4285f4"
  readonly property color subtle: Qt.rgba(ink.r, ink.g, ink.b, 0.12)
  spacing: 14
  property real lightGridHeight: 154

  component Label: Text {
    color: ui.ink
    font.family: "sans-serif"
    font.pixelSize: 13
  }
  component Action: Controls.Button {
    id: action
    property bool selected: false
    implicitHeight: 30
    leftPadding: 10
    rightPadding: 10
    contentItem: Label {
      text: action.text
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      opacity: action.enabled ? 1 : 0.4
    }
    background: Rectangle {
      radius: 4
      color: action.selected ? ui.accent : action.down ? Qt.rgba(ui.ink.r, ui.ink.g, ui.ink.b, 0.25) : ui.subtle
      border.color: action.hovered ? ui.ink : "transparent"
    }
  }
  component Track: Controls.Slider {
    id: slider
    Layout.fillWidth: true
    implicitHeight: 22
    stepSize: 1
    background: Rectangle {
      x: slider.leftPadding
      y: (slider.height - height) / 2
      width: slider.availableWidth
      height: 7
      radius: 4
      color: ui.subtle
      Rectangle {
        width: parent.width * slider.visualPosition
        height: parent.height
        radius: 4
        color: ui.ink
      }
    }
    handle: Rectangle {
      x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
      y: (slider.height - height) / 2
      width: 13
      height: 13
      radius: 7
      color: ui.ink
      border.color: slider.pressed ? ui.accent : "transparent"
    }
  }
  component Divider: Rectangle {
    Layout.fillWidth: true
    implicitHeight: 1
    color: ui.subtle
  }

  RowLayout {
    Layout.fillWidth: true
    Label {
      text: "Wiz Lights"
      font.bold: true
      font.pixelSize: 17
      Layout.fillWidth: true
    }
    Action {
      text: "Rediscover"
      enabled: !ui.ctl.busy
      onClicked: ui.ctl.rediscover()
    }
    Action {
      text: "Refresh"
      enabled: !ui.ctl.busy
      onClicked: ui.ctl.refreshEverything()
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0
    Flickable {
      id: lightViewport
      objectName: "lightViewport"
      Layout.fillWidth: true
      Layout.preferredHeight: ui.lightGridHeight
      clip: true
      contentWidth: width
      contentHeight: lightGrid.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      Controls.ScrollBar.vertical: Controls.ScrollBar {}
      GridLayout {
        id: lightGrid
        width: lightViewport.width
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
          model: ui.ctl.lights
          delegate: Rectangle {
            id: tile
            required property string modelData
            readonly property var status: ui.ctl.statuses[modelData] || ({})
            readonly property bool chosen: ui.ctl.selectedLight === modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: 46
            radius: 4
            color: chosen ? Qt.rgba(ui.accent.r, ui.accent.g, ui.accent.b, 0.16) : hover.containsMouse ? ui.subtle : "transparent"
            border.width: chosen ? 2 : 1
            border.color: chosen ? ui.accent : Qt.rgba(ui.ink.r, ui.ink.g, ui.ink.b, 0.5)
            RowLayout {
              anchors.fill: parent
              anchors.margins: 8
              spacing: 10
              Text {
                text: ui.ctl.lightIcon(tile.modelData)
                font.family: ui.ctl.bar.fontFamily
                font.pixelSize: 24
                color: ui.ink
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                  text: tile.modelData
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                }
                Label {
                  text: tile.status.ok === false ? "unreachable" : tile.status.state || "unknown"
                  font.pixelSize: 11
                  color: tile.status.ok === false ? "#e5ad59" : tile.status.state === "on" ? "#36d46d" : tile.status.state === "off" ? "#f16a67" : ui.ink
                }
              }
            }
            MouseArea {
              id: hover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                ui.ctl.selectedLight = tile.modelData
                ui.ctl.applySelectedStatus()
                ui.ctl.refreshSelected()
              }
            }
          }
        }
      }
    }
    Item {
      Layout.fillWidth: true
      implicitHeight: 18
      Rectangle {
        anchors.centerIn: parent
        width: 50
        height: 3
        radius: 2
        color: resizeMouse.containsMouse || resizeMouse.pressed ? ui.accent : ui.ink
        opacity: resizeMouse.containsMouse || resizeMouse.pressed ? 1 : 0.35
      }
      MouseArea {
        id: resizeMouse
        objectName: "lightGridResizeHandle"
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.SizeVerCursor
        property real startY: 0
        property real startHeight: 0
        onPressed: function (mouse) {
          startY = mapToItem(ui, mouse.x, mouse.y).y
          startHeight = ui.lightGridHeight
        }
        onPositionChanged: function (mouse) {
          if (pressed)
            ui.lightGridHeight = Math.max(46, Math.min(360, startHeight + mapToItem(ui, mouse.x, mouse.y).y - startY))
        }
        onDoubleClicked: ui.lightGridHeight = Math.max(46, Math.min(360, lightGrid.implicitHeight))
      }
    }
  }
  Label {
    visible: !ui.ctl.lights.length
    text: "No lights configured. Try Rediscover."
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }
  Divider {}
  RowLayout {
    Layout.fillWidth: true
    Label {
      text: "Power"
      Layout.fillWidth: true
    }
    Action {
      readonly property bool isOn: (ui.ctl.statuses[ui.ctl.selectedLight] || {}).state === "on"
      text: isOn ? "✓ On" : "Off"
      selected: isOn
      enabled: !!ui.ctl.selectedLight && !ui.ctl.busy
      onClicked: ui.ctl.setPower(!isOn)
    }
  }
  RowLayout {
    Layout.fillWidth: true
    spacing: 6
    Label {
      text: "Mode"
      Layout.fillWidth: true
    }
    Action {
      text: "RGB"
      selected: !ui.ctl.whiteMode && !ui.ctl.sceneMode
      enabled: !!ui.ctl.selectedLight
      onClicked: {
        ui.ctl.whiteMode = false
        ui.ctl.applyMode()
      }
    }
    Action {
      text: "White"
      selected: ui.ctl.whiteMode && !ui.ctl.sceneMode
      enabled: !!ui.ctl.selectedLight
      onClicked: {
        ui.ctl.whiteMode = true
        ui.ctl.applyMode()
      }
    }
    Action {
      text: ui.ctl.selectedPreset + " ▾"
      Layout.maximumWidth: 135
      enabled: !!ui.ctl.selectedLight
      onClicked: presetMenu.open()
      Controls.Menu {
        id: presetMenu
        Controls.MenuItem {
          text: "Custom"
          enabled: false
        }
        Instantiator {
          model: ui.ctl.presetNames
          delegate: Controls.MenuItem {
            required property string modelData
            text: modelData
            onTriggered: ui.ctl.applyPreset(modelData)
          }
          onObjectAdded: function (index, object) {
            presetMenu.insertItem(index + 1, object)
          }
          onObjectRemoved: function (index, object) {
            presetMenu.removeItem(object)
          }
        }
      }
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 8
    visible: !ui.ctl.whiteMode && !ui.ctl.sceneMode
    RowLayout {
      Layout.fillWidth: true
      Label {
        text: "Hue: " + ui.ctl.hue + "°"
        Layout.fillWidth: true
      }
      Rectangle {
        implicitWidth: 34
        implicitHeight: 18
        radius: 9
        color: Qt.hsva(ui.ctl.hue / 360, ui.ctl.saturation / 100, 1, 1)
      }
    }
    Track {
      id: hueSlider
      from: 0
      to: 360
      value: ui.ctl.hue
      background: Rectangle {
        x: hueSlider.leftPadding
        y: (hueSlider.height - height) / 2
        width: hueSlider.availableWidth
        height: 8
        radius: 4
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop {
            position: 0
            color: "#ff0000"
          }
          GradientStop {
            position: 0.167
            color: "#ffff00"
          }
          GradientStop {
            position: 0.333
            color: "#00ff00"
          }
          GradientStop {
            position: 0.5
            color: "#00ffff"
          }
          GradientStop {
            position: 0.667
            color: "#0000ff"
          }
          GradientStop {
            position: 0.833
            color: "#ff00ff"
          }
          GradientStop {
            position: 1
            color: "#ff0000"
          }
        }
      }
      onMoved: {
        ui.ctl.hue = Math.round(value)
        ui.ctl.scheduleMode()
      }
    }
    Label {
      text: "Saturation: " + ui.ctl.saturation + "%"
    }
    Track {
      from: 0
      to: 100
      value: ui.ctl.saturation
      onMoved: {
        ui.ctl.saturation = Math.round(value)
        ui.ctl.scheduleMode()
      }
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 8
    visible: ui.ctl.whiteMode && !ui.ctl.sceneMode
    Label {
      text: "Temperature: " + ui.ctl.temperature + " K"
    }
    Track {
      id: temperatureSlider
      objectName: "temperatureSlider"
      from: 2200
      to: 6500
      stepSize: 50
      value: ui.ctl.temperature
      background: Rectangle {
        x: temperatureSlider.leftPadding
        y: (temperatureSlider.height - height) / 2
        width: temperatureSlider.availableWidth
        height: 8
        radius: 4
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop {
            position: 0
            color: "#ffb25f"
          }
          GradientStop {
            position: 0.5
            color: "#fff4df"
          }
          GradientStop {
            position: 1
            color: "#d9e9ff"
          }
        }
      }
      onMoved: {
        ui.ctl.temperature = Math.round(value / 50) * 50
        ui.ctl.scheduleMode()
      }
    }
  }
  Label {
    visible: ui.ctl.sceneMode
    text: "Scene: " + ui.ctl.selectedPreset
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 8
    Label {
      text: "Brightness: " + ui.ctl.dimming + "%"
    }
    Track {
      from: 10
      to: 100
      value: ui.ctl.dimming
      enabled: !!ui.ctl.selectedLight
      onMoved: {
        ui.ctl.dimming = Math.round(value)
        ui.ctl.scheduleBrightness()
      }
    }
  }
  Divider {}
  RowLayout {
    Layout.fillWidth: true
    Controls.TextField {
      id: presetName
      Layout.fillWidth: true
      implicitHeight: 30
      placeholderText: "Preset name"
      color: ui.ink
      font.family: "sans-serif"
      font.pixelSize: 13
      placeholderTextColor: Qt.rgba(ui.ink.r, ui.ink.g, ui.ink.b, 0.5)
      background: Rectangle {
        radius: 4
        color: ui.subtle
        border.color: presetName.activeFocus ? ui.accent : "transparent"
      }
      onAccepted: if (text.trim() && ui.ctl.selectedLight && !ui.ctl.busy)
        ui.ctl.savePreset(text.trim())
    }
    Action {
      text: "Save"
      enabled: !!ui.ctl.selectedLight && !!presetName.text.trim() && !ui.ctl.busy
      onClicked: ui.ctl.savePreset(presetName.text.trim())
    }
  }
  Label {
    Layout.fillWidth: true
    text: ui.ctl.busy ? "Working…" : ui.ctl.message
    font.pixelSize: 12
    elide: Text.ElideRight
    opacity: 0.8
  }
}
