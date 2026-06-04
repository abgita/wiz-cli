import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as Controls
import QtGraphicalEffects 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.12 as Kirigami

Item {
    id: root

    implicitWidth: Kirigami.Units.iconSizes.medium
    implicitHeight: Kirigami.Units.iconSizes.medium
    Layout.minimumWidth: Kirigami.Units.iconSizes.smallMedium
    Layout.minimumHeight: Kirigami.Units.iconSizes.smallMedium
    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
    Layout.preferredHeight: Kirigami.Units.iconSizes.medium

    // Backend command. Install/symlink wizctl somewhere in Plasma's PATH (for example
    // ~/.local/bin/wizctl) to make the widget independent of the source checkout path.
    property string wizctlPath: "wizctl"
    property var lights: ({})
    property var lightDetails: ({})
    property var statuses: ({})
    property var presets: ({})
    property var presetNames: []
    property var presetOptions: ["Custom"]
    property var iconOptions: ["default", "icon_08", "icon_11", "icon_16", "icon_19"]
    property string selectedPresetName: "Custom"
    property string presetNameDraft: ""
    property string selectedLight: ""
    property string message: "Loading lights..."
    property bool busy: false
    property bool whiteMode: true
    property int currentSceneId: -1
    property int currentSpeed: -1
    property int hue: 210
    property int saturation: 70
    property int temp: 2700
    property int dimming: 80
    property color colorPreview: Qt.rgba(0.24, 0.71, 0.80, 1)
    property int previewRequestId: 0
    property var callbacks: ({})
    property var busySources: ({})
    property var quietSources: ({})

    Plasmoid.preferredRepresentation: Plasmoid.compactRepresentation

    Plasmoid.compactRepresentation: MouseArea {
        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: Kirigami.Units.iconSizes.medium
        onClicked: {
            if (!Plasmoid.expanded) root.refreshEverything()
            Plasmoid.expanded = !Plasmoid.expanded
        }
        PlasmaCore.IconItem {
            anchors.fill: parent
            source: "brightness-high"
        }
    }

    Plasmoid.fullRepresentation: Item {
        id: fullRep

        implicitWidth: Kirigami.Units.gridUnit * 20
        implicitHeight: Kirigami.Units.gridUnit * 34 + gridResizeHandleHeight + lightGridHeight - defaultLightGridHeight
        Layout.minimumHeight: implicitHeight
        Layout.maximumHeight: implicitHeight

        property int sectionSpacing: 8
        property int fieldSpacing: Math.max(8, Kirigami.Units.smallSpacing * 2)
        property int gridItemPadding: Kirigami.Units.smallSpacing * 2
        property real defaultLightGridHeight: Kirigami.Units.gridUnit * 9
        property real minLightGridHeight: Kirigami.Units.gridUnit * 6
        property real maxLightGridHeight: Kirigami.Units.gridUnit * 16
        property real lightGridHeight: defaultLightGridHeight
        property int gridResizeHandleHeight: 6

        Kirigami.Theme.inherit: false
        Kirigami.Theme.textColor: PlasmaCore.ColorScope.textColor
        Kirigami.Theme.backgroundColor: PlasmaCore.ColorScope.backgroundColor
        Kirigami.Theme.disabledTextColor: PlasmaCore.ColorScope.disabledTextColor
        Kirigami.Theme.highlightColor: PlasmaCore.ColorScope.highlightColor
        Kirigami.Theme.highlightedTextColor: PlasmaCore.ColorScope.highlightedTextColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: fullRep.fieldSpacing

            RowLayout {
                Layout.fillWidth: true
                Controls.Label {
                    text: "Wiz Lights"
                    font.bold: true
                    font.pointSize: 13
                    Layout.fillWidth: true
                }
                PlasmaComponents.Button {
                    text: "Rediscover"
                    enabled: !root.busy
                    onClicked: root.rediscover()
                }
                PlasmaComponents.Button {
                    text: "Refresh"
                    enabled: !root.busy
                    onClicked: root.refreshEverything()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(0, fullRep.sectionSpacing - parent.spacing)
            }

            Item {
                id: lightGridPane
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.minimumHeight: fullRep.minLightGridHeight + fullRep.gridResizeHandleHeight
                Layout.preferredHeight: fullRep.lightGridHeight + fullRep.gridResizeHandleHeight
                Layout.maximumHeight: fullRep.maxLightGridHeight + fullRep.gridResizeHandleHeight

                GridView {
                    id: grid
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: fullRep.lightGridHeight
                    cellWidth: width / 2
                cellHeight: Kirigami.Units.gridUnit * 3
                clip: true
                model: Object.keys(root.lights).sort()
                flow: GridView.FlowLeftToRight
                verticalLayoutDirection: GridView.TopToBottom
                boundsBehavior: Flickable.StopAtBounds

                Controls.ScrollBar.vertical: Controls.ScrollBar {
                    policy: Controls.ScrollBar.AsNeeded
                    interactive: true
                }

                onCountChanged: positionViewAtBeginning()
                onHeightChanged: positionViewAtBeginning()

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight

                    property string lightName: modelData
                    property var st: root.statuses[lightName] || ({})

                    Rectangle {
                        id: tile
                        width: grid.cellWidth - fullRep.gridItemPadding
                        height: grid.cellHeight - fullRep.gridItemPadding
                        x: (grid.count % 2 === 1 && index === grid.count - 1) ? (grid.width - width) / 2 : fullRep.gridItemPadding / 2
                        radius: Kirigami.Units.smallSpacing
                        border.width: lightName === root.selectedLight ? 2 : 1
                        border.color: lightName === root.selectedLight ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                        color: lightName === root.selectedLight ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.16) : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing * 1.5
                            spacing: fullRep.fieldSpacing

                        PlasmaComponents.ComboBox {
                            id: iconCombo
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            model: root.iconOptions
                            currentIndex: Math.max(0, root.iconOptions.indexOf(root.lightIcon(lightName)))
                            enabled: !root.busy
                            popup.modal: true
                            popup.closePolicy: Controls.Popup.CloseOnEscape
                                               | Controls.Popup.CloseOnPressOutside
                                               | Controls.Popup.CloseOnReleaseOutside
                                               | Controls.Popup.CloseOnPressOutsideParent
                                               | Controls.Popup.CloseOnReleaseOutsideParent
                            background: Item {}
                            indicator: Item {}
                            contentItem: Item {
                                PlasmaCore.IconItem {
                                    anchors.fill: parent
                                    source: "brightness-high"
                                    visible: root.lightIcon(lightName) === "default"
                                    active: st.state === "on"
                                    enabled: st.state !== "off"
                                }

                                Image {
                                    id: customLightIcon
                                    anchors.fill: parent
                                    source: root.lightIconSource(lightName)
                                    visible: false
                                    fillMode: Image.PreserveAspectFit
                                }

                                ColorOverlay {
                                    anchors.fill: customLightIcon
                                    source: customLightIcon
                                    visible: root.lightIcon(lightName) !== "default"
                                    color: Kirigami.Theme.textColor
                                    opacity: st.state === "off" ? 0.5 : 1
                                }

                                Rectangle {
                                    width: Kirigami.Units.smallSpacing * 2
                                    height: width
                                    radius: width / 2
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    color: st.state === "on" ? "#22c55e" : st.ok === false ? "#ef4444" : "#64748b"
                                    border.width: 1
                                    border.color: Kirigami.Theme.backgroundColor
                                }
                            }
                            delegate: Controls.ItemDelegate {
                                width: iconCombo.popup.width
                                text: modelData === "default" ? "Default" : modelData
                            }
                            onPressedChanged: {
                                if (pressed && root.selectedLight !== lightName) root.selectLight(lightName)
                            }
                            onActivated: root.setLightIcon(lightName, currentText)
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Controls.Label {
                                text: modelData
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Controls.Label {
                                text: st.ok === false ? "unreachable" : (st.state || "unknown")
                                color: st.state === "on" ? "#22c55e" : st.state === "off" ? "#ef4444" : Kirigami.Theme.disabledTextColor
                                font.pointSize: 9
                            }
                        }
                    }

                        MouseArea {
                            anchors.fill: parent
                            anchors.leftMargin: Kirigami.Units.smallSpacing * 1.5 + Kirigami.Units.iconSizes.medium + fullRep.fieldSpacing
                            onClicked: root.selectLight(lightName)
                        }
                    }
                }
            }

                Item {
                    id: gridResizeHandle
                    anchors.top: grid.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: fullRep.gridResizeHandleHeight

                    Rectangle {
                    width: Kirigami.Units.gridUnit * 3
                    height: 2
                    radius: height / 2
                    anchors.centerIn: parent
                    color: gridResizeMouse.containsMouse || gridResizeMouse.pressed ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                    opacity: gridResizeMouse.containsMouse || gridResizeMouse.pressed ? 0.9 : 0.45
                }

                    MouseArea {
                        id: gridResizeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeVerCursor
                        property real startY: 0
                        property real startHeight: 0
                        onPressed: {
                            startY = mapToItem(fullRep, mouse.x, mouse.y).y
                            startHeight = fullRep.lightGridHeight
                        }
                        onPositionChanged: {
                            if (!pressed) return
                            var currentY = mapToItem(fullRep, mouse.x, mouse.y).y
                            fullRep.lightGridHeight = Math.max(fullRep.minLightGridHeight, Math.min(fullRep.maxLightGridHeight, startHeight + currentY - startY))
                        }
                        onDoubleClicked: fullRep.lightGridHeight = fullRep.defaultLightGridHeight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: -fullRep.fieldSpacing
                Controls.Label {
                    text: "Power"
                    Layout.fillWidth: true
                }
                PlasmaComponents.CheckBox {
                    text: checked ? "On" : "Off"
                    checked: root.currentPowerOn()
                    enabled: root.selectedLight && !root.busy
                    onClicked: {
                        root.markPresetCustom()
                        var command = checked ? "on" : "off"
                        root.runLightCommand(command, [root.selectedLight], function(obj) {
                            root.statuses[root.selectedLight] = { ok: true, state: checked ? "on" : "off", ip: root.lights[root.selectedLight] }
                            root.statuses = Object.assign({}, root.statuses)
                            root.message = (checked ? "Turned on " : "Turned off ") + root.selectedLight
                        })
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Controls.Label {
                    text: "Mode"
                    Layout.fillWidth: true
                }
                PlasmaComponents.Button {
                    id: rgbModeButton
                    text: "RGB"
                    checkable: true
                    checked: !root.whiteMode && root.currentSceneId < 0
                    highlighted: checked
                    enabled: root.selectedLight && !root.busy
                    onClicked: root.setMode(false)
                }
                PlasmaComponents.Button {
                    id: whiteModeButton
                    text: "White"
                    checkable: true
                    checked: root.whiteMode && root.currentSceneId < 0
                    highlighted: checked
                    enabled: root.selectedLight && !root.busy
                    onClicked: root.setMode(true)
                }
                PlasmaComponents.ComboBox {
                    id: modePresetCombo
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 5.5
                    popup.modal: true
                    popup.closePolicy: Controls.Popup.CloseOnEscape
                                       | Controls.Popup.CloseOnPressOutside
                                       | Controls.Popup.CloseOnReleaseOutside
                                       | Controls.Popup.CloseOnPressOutsideParent
                                       | Controls.Popup.CloseOnReleaseOutsideParent
                    model: root.presetOptions
                    currentIndex: Math.max(0, root.presetOptions.indexOf(root.selectedPresetName))
                    enabled: root.selectedLight.length > 0 && root.presetOptions.length > 1
                    font.bold: root.selectedPresetIsScene()
                    onActivated: {
                        if (root.busy) return
                        if (currentText === "Custom") root.selectedPresetName = "Custom"
                        else root.applyPreset(currentText)
                    }
                }
            }

            Controls.Label {
                Layout.fillWidth: true
                visible: root.currentSceneId >= 0
                text: root.currentSceneId >= 0 ? "Scene: " + root.currentSceneId : ""
                color: Kirigami.Theme.disabledTextColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: fullRep.fieldSpacing
                visible: root.whiteMode && root.currentSceneId < 0

                RowLayout {
                    Layout.fillWidth: true
                    Controls.Label {
                        text: "White: " + root.temp + "K"
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                        Layout.preferredHeight: Kirigami.Units.gridUnit
                        radius: height / 2
                        border.width: 1
                        border.color: Kirigami.Theme.disabledTextColor
                        color: root.previewWhiteColor()
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.smallSpacing * 2
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.000; color: "#ffb25f" }
                            GradientStop { position: 0.500; color: "#fff4df" }
                            GradientStop { position: 1.000; color: "#d9e9ff" }
                        }
                    }
                }

                PlasmaComponents.Slider {
                    Layout.fillWidth: true
                    from: 2200
                    to: 6500
                    stepSize: 50
                    value: root.temp
                    enabled: root.selectedLight && !root.busy
                    onMoved: {
                        root.markPresetCustom()
                        root.temp = Math.round(value / 50) * 50
                        whiteDebounce.restart()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: fullRep.fieldSpacing
                visible: !root.whiteMode && root.currentSceneId < 0

                RowLayout {
                    Layout.fillWidth: true
                    Controls.Label {
                        text: "Hue: " + root.hue + "°"
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                        Layout.preferredHeight: Kirigami.Units.gridUnit
                        radius: height / 2
                        border.width: 1
                        border.color: Kirigami.Theme.disabledTextColor
                        color: root.colorPreview
                    }
                }

                Item {
                    id: hueBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.smallSpacing * 2

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.000; color: "#ff0000" }
                            GradientStop { position: 0.167; color: "#ffff00" }
                            GradientStop { position: 0.333; color: "#00ff00" }
                            GradientStop { position: 0.500; color: "#00ffff" }
                            GradientStop { position: 0.667; color: "#0000ff" }
                            GradientStop { position: 0.833; color: "#ff00ff" }
                            GradientStop { position: 1.000; color: "#ff0000" }
                        }
                    }

                    Rectangle {
                        width: 3
                        height: parent.height + 6
                        radius: 1
                        y: -3
                        x: Math.max(0, Math.min(parent.width - width, (root.hue / 360) * parent.width - width / 2))
                        color: Kirigami.Theme.textColor
                        border.width: 1
                        border.color: Kirigami.Theme.backgroundColor
                    }
                }

                PlasmaComponents.Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 360
                    stepSize: 1
                    value: root.hue
                    enabled: root.selectedLight && !root.busy
                    onMoved: {
                        root.markPresetCustom()
                        root.hue = Math.round(value)
                        colorPreviewDebounce.restart()
                        colorDebounce.restart()
                    }
                }

                Controls.Label { text: "Saturation: " + root.saturation + "%" }
                PlasmaComponents.Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    stepSize: 1
                    value: root.saturation
                    enabled: root.selectedLight && !root.busy
                    onMoved: {
                        root.markPresetCustom()
                        root.saturation = Math.round(value)
                        colorPreviewDebounce.restart()
                        colorDebounce.restart()
                    }
                }
            }

            Controls.Label { text: "Brightness: " + root.dimming + "%" }
            PlasmaComponents.Slider {
                Layout.fillWidth: true
                from: 10
                to: 100
                stepSize: 1
                value: root.dimming
                enabled: root.selectedLight && !root.busy
                onMoved: {
                    if (root.currentSceneId < 0) root.markPresetCustom()
                    root.dimming = Math.round(value)
                    if (!root.whiteMode && root.currentSceneId < 0) colorPreviewDebounce.restart()
                    dimDebounce.restart()
                }
            }

            Controls.Label {
                visible: root.currentSceneId >= 0 && root.currentSpeed >= 0
                text: "Speed: " + Math.round(root.currentSpeed / 2) + "%"
            }
            PlasmaComponents.Slider {
                Layout.fillWidth: true
                visible: root.currentSceneId >= 0 && root.currentSpeed >= 0
                from: 10
                to: 200
                stepSize: 1
                value: root.currentSpeed >= 0 ? root.currentSpeed : 155
                enabled: root.selectedLight && !root.busy
                onMoved: {
                    root.currentSpeed = Math.round(value)
                    speedDebounce.restart()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(0, fullRep.sectionSpacing - parent.spacing)
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Kirigami.Theme.disabledTextColor
                opacity: 0.3
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(0, fullRep.sectionSpacing - parent.spacing)
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.TextField {
                    id: presetNameInput
                    Layout.fillWidth: true
                    text: root.presetNameDraft
                    placeholderText: "Preset name"
                    enabled: root.selectedLight && !root.busy
                    onTextChanged: root.presetNameDraft = text
                    onAccepted: root.savePreset(text)
                }
                PlasmaComponents.Button {
                    text: "Save"
                    enabled: root.selectedLight && !root.busy && presetNameInput.text.trim().length > 0
                    onClicked: root.savePreset(presetNameInput.text)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Controls.Label {
                    Layout.fillWidth: true
                    text: root.busy ? "Working..." : root.message
                    elide: Text.ElideRight
                    font.pointSize: 9
                }
            }

        }
    }

    PlasmaCore.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: {
            disconnectSource(sourceName)
            var cb = root.callbacks[sourceName]
            delete root.callbacks[sourceName]
            var wasBusy = root.busySources[sourceName]
            delete root.busySources[sourceName]
            var wasQuiet = root.quietSources[sourceName]
            delete root.quietSources[sourceName]
            if (wasBusy) root.busy = Object.keys(root.busySources).length > 0

            var exitCode = data["exit code"] !== undefined ? data["exit code"] : data.exitCode
            var stdout = data.stdout || data.output || ""
            var stderr = data.stderr || ""
            if (exitCode !== 0 && exitCode !== undefined) {
                if (!wasQuiet) root.message = stderr || stdout || ("Command failed: " + sourceName)
                return
            }
            if (cb) cb(stdout)
        }
    }

    Timer {
        id: colorDebounce
        interval: 220
        repeat: false
        onTriggered: {
            if (!root.selectedLight) return
            root.runLightCommand("hsv", [root.selectedLight, root.hue, root.saturation, root.dimming], function(obj) {
                root.message = "Color set: H" + Math.round(obj.hsv.h) + " S" + Math.round(obj.hsv.s) + "% V" + Math.round(obj.hsv.v) + "%"
                root.refreshSelectedStatus()
            })
        }
    }

    Timer {
        id: colorPreviewDebounce
        interval: 80
        repeat: false
        onTriggered: root.refreshColorPreview()
    }

    Timer {
        id: whiteDebounce
        interval: 220
        repeat: false
        onTriggered: {
            if (!root.selectedLight) return
            root.runLightCommand("temp", [root.selectedLight, root.temp, root.dimming], function(obj) {
                root.message = "White set: " + obj.temp + "K " + obj.dimming + "%"
                root.refreshSelectedStatus()
            })
        }
    }

    Timer {
        id: speedDebounce
        interval: 260
        repeat: false
        onTriggered: {
            if (!root.selectedLight || root.currentSceneId < 0 || root.currentSpeed < 0) return
            root.runLightCommand("scene", [root.selectedLight, root.currentSceneId, root.dimming, root.currentSpeed], function(obj) {
                root.message = "Scene " + obj.sceneId + " speed set to " + Math.round(obj.speed / 2) + "%"
                root.refreshSelectedStatus()
            })
        }
    }

    Timer {
        id: dimDebounce
        interval: 260
        repeat: false
        onTriggered: {
            if (!root.selectedLight) return
            if (root.currentSceneId >= 0) {
                var args = [root.selectedLight, root.currentSceneId, root.dimming]
                if (root.currentSpeed >= 0) args.push(root.currentSpeed)
                root.runLightCommand("scene", args, function(obj) {
                    root.message = "Scene " + obj.sceneId + " brightness set to " + obj.dimming + "%"
                    root.refreshSelectedStatus()
                })
                return
            }
            if (root.whiteMode) {
                whiteDebounce.restart()
                return
            }
            root.runLightCommand("dim", [root.selectedLight, root.dimming], function(obj) {
                root.message = "Brightness set to " + obj.dimming + "%"
                root.refreshSelectedStatus()
            })
        }
    }

    Component.onCompleted: refreshEverything()

    function shellQuote(value) {
        var s = String(value)
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    function exec(args, callback, options) {
        options = options || ({})
        var command = shellQuote(root.wizctlPath)
        for (var i = 0; i < args.length; i++) command += " " + shellQuote(args[i])
        root.callbacks[command] = callback
        if (options.busy !== false) {
            root.busySources[command] = true
            root.busy = true
        }
        if (options.quiet === true) root.quietSources[command] = true
        executable.connectSource(command)
    }

    function parseJson(stdout) {
        return JSON.parse(stdout.trim() || "{}")
    }

    function runLightCommand(command, args, callback) {
        exec([command].concat(args), function(stdout) {
            callback(parseJson(stdout))
        })
    }

    function currentPowerOn() {
        var st = root.statuses[root.selectedLight]
        return st ? st.state === "on" : false
    }

    function setMode(isWhite) {
        root.markPresetCustom()
        root.whiteMode = isWhite
        root.currentSceneId = -1
        root.currentSpeed = -1

        // Apply immediately instead of debouncing through the old scene state. This
        // prevents a stale scene status response from putting the UI back in Scene mode.
        if (root.whiteMode) {
            root.runLightCommand("temp", [root.selectedLight, root.temp, root.dimming], function(obj) {
                root.message = "White set: " + obj.temp + "K " + obj.dimming + "%"
            })
        } else {
            root.refreshColorPreview()
            root.runLightCommand("hsv", [root.selectedLight, root.hue, root.saturation, root.dimming], function(obj) {
                root.message = "RGB set: H" + Math.round(obj.hsv.h) + " S" + Math.round(obj.hsv.s) + "% V" + Math.round(obj.hsv.v) + "%"
            })
        }
    }

    function refreshEverything() {
        loadLights(function() {
            loadPresets(function() {
                refreshAllStatus()
            })
        })
    }

    function loadLights(callback) {
        exec(["list", "--json", "--details"], function(stdout) {
            root.lightDetails = parseJson(stdout)
            var mapping = ({})
            var names = Object.keys(root.lightDetails).sort()
            for (var i = 0; i < names.length; i++) mapping[names[i]] = root.lightDetails[names[i]].ip
            root.lights = mapping
            if (!root.selectedLight && names.length > 0) root.selectedLight = names[0]
            if (root.selectedLight && !root.lights[root.selectedLight] && names.length > 0) root.selectedLight = names[0]
            root.message = names.length ? "Loaded " + names.length + " lights" : "No lights configured"
            if (callback) callback()
        })
    }

    function loadPresets(callback) {
        exec(["presets", "--json"], function(stdout) {
            root.presets = parseJson(stdout)
            root.rebuildPresetOptions()
            if (callback) callback()
        })
    }

    function refreshAllStatus() {
        exec(["status", "--all"], function(stdout) {
            root.statuses = parseJson(stdout)
            root.message = "Status refreshed"
            applySelectedStatusToSliders()
        })
    }

    function refreshSelectedStatus() {
        if (!root.selectedLight) return
        exec(["status", root.selectedLight], function(stdout) {
            var st = parseJson(stdout)
            root.statuses[root.selectedLight] = st
            root.statuses = Object.assign({}, root.statuses)
            applySelectedStatusToSliders()
        })
    }

    function rediscover() {
        exec(["discover"], function(stdout) {
            var obj = parseJson(stdout)
            root.lights = obj.lights || root.lights
            root.message = "Rediscovery complete"
            refreshAllStatus()
        })
    }

    function applyPreset(name) {
        if (!name || name === "Custom") return
        root.runLightCommand("preset", [root.selectedLight, name], function(obj) {
            root.selectedPresetName = name
            root.message = "Applied preset " + name
            if (typeof obj.temp === "number") {
                root.whiteMode = true
                root.currentSceneId = -1
                root.currentSpeed = -1
                root.temp = obj.temp
            } else if (typeof obj.sceneId === "number") {
                root.currentSceneId = obj.sceneId
            } else if (obj.rgb) {
                root.whiteMode = false
                root.currentSceneId = -1
                root.currentSpeed = -1
            }
            if (typeof obj.dimming === "number") root.dimming = obj.dimming
            root.refreshSelectedStatus()
        })
    }

    function savePreset(name) {
        name = String(name || "").trim()
        if (!name) return
        exec(["save-preset", root.selectedLight, name], function(stdout) {
            var obj = parseJson(stdout)
            root.presets = obj.presets || root.presets
            root.rebuildPresetOptions()
            root.selectedPresetName = name
            root.message = "Saved preset " + name
            root.presetNameDraft = ""
        })
    }

    function selectLight(name) {
        root.selectedLight = name
        root.message = "Selected " + name
        applySelectedStatusToSliders()
        refreshSelectedStatus()
    }

    function lightIcon(name) {
        var entry = root.lightDetails[name] || ({})
        return entry.icon || "default"
    }

    function lightIconSource(name) {
        var icon = root.lightIcon(name)
        return icon === "default" ? "" : Qt.resolvedUrl("../icons/" + icon + ".svg")
    }

    function setLightIcon(name, icon) {
        root.exec(["set-icon", name, icon], function(stdout) {
            var obj = root.parseJson(stdout)
            var entry = root.lightDetails[name] || ({})
            entry.icon = obj.icon || icon
            root.lightDetails[name] = entry
            root.lightDetails = Object.assign({}, root.lightDetails)
            root.message = "Icon set for " + name
        })
    }

    function rebuildPresetOptions() {
        root.presetNames = Object.keys(root.presets).sort()
        root.presetOptions = ["Custom"].concat(root.presetNames)
    }

    function markPresetCustom() {
        root.selectedPresetName = "Custom"
    }

    function applySelectedStatusToSliders() {
        var st = root.statuses[root.selectedLight]
        if (!st || st.ok === false) return
        if (typeof st.dimming === "number") root.dimming = Math.max(10, Math.min(100, st.dimming))
        if (typeof st.temp === "number") {
            root.temp = Math.max(2200, Math.min(6500, st.temp))
            root.whiteMode = true
            root.currentSceneId = -1
            root.currentSpeed = -1
        } else if (typeof st.sceneId === "number" && st.sceneId > 0) {
            root.currentSceneId = st.sceneId
            root.currentSpeed = typeof st.speed === "number" ? Math.max(10, Math.min(200, st.speed)) : root.presetSpeed(root.matchingPresetName(st))
        } else if (typeof st.r === "number" || typeof st.g === "number" || typeof st.b === "number" || st.sceneId === 0) {
            root.whiteMode = false
            root.currentSceneId = -1
            root.currentSpeed = -1
        }
        root.selectedPresetName = root.matchingPresetName(st)
        root.refreshColorPreview()
    }

    function presetSpeed(name) {
        var p = root.presets[name] || ({})
        return typeof p.speed === "number" ? Math.max(10, Math.min(200, p.speed)) : -1
    }

    function selectedPresetIsScene() {
        if (!root.selectedPresetName || root.selectedPresetName === "Custom") return false
        var p = root.presets[root.selectedPresetName] || ({})
        return typeof p.sceneId === "number"
    }

    function matchingPresetName(st) {
        var dim = typeof st.dimming === "number" ? Math.max(10, Math.min(100, st.dimming)) : null
        for (var i = 0; i < root.presetNames.length; i++) {
            var name = root.presetNames[i]
            var p = root.presets[name] || ({})

            // Scene presets are identified by sceneId. The brightness slider is allowed
            // to adjust dimming while keeping the same scene preset selected.
            if (typeof st.sceneId === "number" && st.sceneId > 0 && typeof p.sceneId === "number" && st.sceneId === p.sceneId) return name

            var pdim = typeof p.dimming === "number" ? Math.max(10, Math.min(100, p.dimming)) : null
            if (dim !== pdim) continue
            if (typeof st.temp === "number" && typeof p.temp === "number" && st.temp === p.temp) return name
            if (typeof st.r === "number" && typeof st.g === "number" && typeof st.b === "number" &&
                typeof p.r === "number" && typeof p.g === "number" && typeof p.b === "number" &&
                st.r === p.r && st.g === p.g && st.b === p.b) return name
        }
        return "Custom"
    }

    function previewWhiteColor() {
        var t = (Math.max(2200, Math.min(6500, root.temp)) - 2200) / (6500 - 2200)
        var r = 255 + (217 - 255) * t
        var g = 178 + (233 - 178) * t
        var b = 95 + (255 - 95) * t
        return Qt.rgba(r / 255, g / 255, b / 255, 1)
    }

    function refreshColorPreview() {
        if (root.whiteMode || root.currentSceneId >= 0) return
        var requestId = ++root.previewRequestId
        root.exec(["hsv-preview", root.hue, root.saturation, root.dimming], function(stdout) {
            if (requestId !== root.previewRequestId) return
            var obj = root.parseJson(stdout)
            var rgb = obj.rgb || ({})
            if (typeof rgb.r === "number" && typeof rgb.g === "number" && typeof rgb.b === "number") {
                root.colorPreview = Qt.rgba(rgb.r / 255, rgb.g / 255, rgb.b / 255, 1)
            }
        }, { busy: false, quiet: true })
    }

}
