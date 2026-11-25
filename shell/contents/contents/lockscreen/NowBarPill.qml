import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: root

    // Scene wallpaper/background item provided by LockScreen.qml for live blur
    property Item liveBgItem: null

    // Notification model (NotificationManager.Notifications) or direct count
    property var notificationModel: null
    property int notificationsCount: notificationModel ? notificationModel.count : 0
    property bool notificationsShown: false

    // Optional external media bindings (auto-populated via MPRIS if left unset)
    property bool mediaPlaying: internalMprisActive
    property string mediaTitle: internalMprisTitle
    property string mediaArtist: internalMprisArtist
    property url mediaArtUrl: internalMprisArtUrl

    // Optional manual overrides for testing charging/battery UI
    property bool overrideCharging: false
    property int overrideBatteryPercent: -1

    signal toggleNotificationsRequested()
    signal openNotificationsRequested()
    signal closeNotificationsRequested()

    readonly property bool hasValidLiveBg: liveBgItem !== null
        && liveBgItem.visible
        && liveBgItem.opacity > 0.01
        && liveBgItem.width > 0
        && liveBgItem.height > 0

    // Power management state via Plasma5Support
    readonly property var batteryData: pmSource.data["Battery"] ? pmSource.data["Battery"] : ({})
    readonly property var acData: pmSource.data["AC Adapter"] ? pmSource.data["AC Adapter"] : ({})
    readonly property bool hasBattery: batteryData["Has Cumulative"] === true || overrideBatteryPercent >= 0
    readonly property int batteryPercent: overrideBatteryPercent >= 0
        ? overrideBatteryPercent
        : (batteryData["Percent"] !== undefined ? Math.round(batteryData["Percent"]) : 0)
    readonly property string batteryState: batteryData["State"] !== undefined ? String(batteryData["State"]) : ""
    readonly property bool isPluggedIn: overrideCharging
        || (acData["Plugged in"] === true)
        || (batteryState === "Charging")
        || (batteryState === "FullyCharged")

    // Safe optional MPRIS loader (prevents failsafe fallback if MPRIS plugin is absent)
    property var mprisModel: null
    readonly property bool internalMprisActive: mprisModel !== null
        && mprisModel.currentPlayer !== null
        && (mprisModel.playbackStatus === 2 || (mprisModel.track !== undefined && mprisModel.track !== ""))
    readonly property string internalMprisTitle: (mprisModel && mprisModel.track) ? String(mprisModel.track) : ""
    readonly property string internalMprisArtist: (mprisModel && mprisModel.artist) ? String(mprisModel.artist) : ""
    readonly property url internalMprisArtUrl: (mprisModel && mprisModel.artUrl) ? mprisModel.artUrl : ""

    // Build ordered list of swipeable scenario cards: "notifications", "charging", "media"
    readonly property var scenarios: {
        var list = ["notifications"];
        if (isPluggedIn || hasBattery) {
            list.push("charging");
        }
        if (mediaPlaying && mediaTitle.length > 0) {
            list.push("media");
        }
        return list;
    }

    property int currentScenarioIndex: 0
    readonly property string currentScenario: (currentScenarioIndex >= 0 && currentScenarioIndex < scenarios.length)
        ? scenarios[currentScenarioIndex]
        : "notifications"

    // Automatically prioritize charging pill when plugged in, or media when playback starts
    onIsPluggedInChanged: {
        if (isPluggedIn) {
            var idx = scenarios.indexOf("charging");
            if (idx >= 0) {
                currentScenarioIndex = idx;
            }
        } else if (currentScenario === "charging" && notificationsCount > 0) {
            currentScenarioIndex = 0;
        }
    }

    onNotificationsCountChanged: {
        if (notificationsCount > 0 && !isPluggedIn) {
            currentScenarioIndex = 0;
        }
    }

    onScenariosChanged: {
        if (currentScenarioIndex >= scenarios.length) {
            currentScenarioIndex = Math.max(0, scenarios.length - 1);
        }
    }

    readonly property string activeLabel: {
        if (currentScenario === "charging") {
            if (batteryState === "FullyCharged" || batteryPercent >= 100) {
                return qsTr("100% Charged");
            }
            return isPluggedIn
                ? qsTr("%1% Charged").arg(batteryPercent)
                : qsTr("%1% Battery").arg(batteryPercent);
        }
        if (currentScenario === "media") {
            return mediaArtist.length > 0
                ? (mediaTitle + " · " + mediaArtist)
                : mediaTitle;
        }
        if (notificationsCount > 0) {
            return notificationsCount === 1
                ? qsTr("+1 notification")
                : qsTr("+%1 notifications").arg(notificationsCount);
        }
        return qsTr("No news");
    }

    // Measure ideal pill width (exact 180px baseline from spec, expanding up to 224px when needed)
    readonly property real targetPillWidth: Math.max(180, Math.min(224, 11 + 34 + 10 + labelMetrics.advanceWidth + 18))

    implicitWidth: targetPillWidth
    implicitHeight: 56

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    // Hide/tuck gracefully when full notification stack is expanded
    opacity: notificationsShown ? 0.0 : 1.0
    scale: notificationsShown ? 0.88 : (pressFeedback ? 0.96 : 1.0)
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        SpringAnimation { spring: 4.2; damping: 0.36; epsilon: 0.005 }
    }

    property bool pressFeedback: false
    property real swipeOffsetX: 0

    Plasma5Support.DataSource {
        id: pmSource
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter"]
    }

    Component.onCompleted: {
        try {
            mprisModel = Qt.createQmlObject(
                'import QtQuick; import org.kde.plasma.private.mpris as Mpris; Mpris.Mpris2Model {}',
                root,
                "NowBarMprisLoader"
            );
        } catch (e) {
            mprisModel = null;
        }
    }

    TextMetrics {
        id: labelMetrics
        font.pixelSize: 13
        font.weight: Font.DemiBold
        text: root.activeLabel
    }

    // Left and right ColorOS-style curved swipe indicators "(" ")"
    Canvas {
        id: leftBracket
        width: 12
        height: 36
        anchors.right: pillContainer.left
        anchors.rightMargin: 6
        anchors.verticalCenter: pillContainer.verticalCenter
        visible: root.scenarios.length > 1
        opacity: visible ? (0.48 + Math.max(0, root.swipeOffsetX / 60) * 0.35) : 0.0
        transform: Translate { x: Math.min(4, Math.max(-6, root.swipeOffsetX * 0.15)) }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.55);
            ctx.lineWidth = 2.6;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.moveTo(9, 4);
            ctx.quadraticCurveTo(2, height / 2, 9, height - 4);
            ctx.stroke();
        }
        onVisibleChanged: if (visible) requestPaint()
    }

    Canvas {
        id: rightBracket
        width: 12
        height: 36
        anchors.left: pillContainer.right
        anchors.leftMargin: 6
        anchors.verticalCenter: pillContainer.verticalCenter
        visible: root.scenarios.length > 1
        opacity: visible ? (0.48 + Math.max(0, -root.swipeOffsetX / 60) * 0.35) : 0.0
        transform: Translate { x: Math.max(-4, Math.min(6, root.swipeOffsetX * 0.15)) }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.55);
            ctx.lineWidth = 2.6;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.moveTo(3, 4);
            ctx.quadraticCurveTo(10, height / 2, 3, height - 4);
            ctx.stroke();
        }
        onVisibleChanged: if (visible) requestPaint()
    }

    Item {
        id: pillContainer
        anchors.fill: parent

        // Rounded mask source for MultiEffect
        Rectangle {
            id: pillMask
            anchors.fill: parent
            radius: height / 2
            color: "#ffffff"
            visible: false
            layer.enabled: true
        }

        // Live wallpaper blur source (strictly disabled when liveBgItem is hidden/null)
        ShaderEffectSource {
            id: bgSource
            anchors.fill: parent
            visible: root.hasValidLiveBg
            live: root.hasValidLiveBg
            recursive: false
            sourceItem: root.hasValidLiveBg ? root.liveBgItem : null
            sourceRect: {
                // Reference dynamic geometry so mapping updates during morph/scroll
                var _track = (root.x + root.y + root.width + root.height + root.scale) * 0;
                if (!root.hasValidLiveBg) {
                    return Qt.rect(0, 0, 1, 1);
                }
                var pt = pillContainer.mapToItem(root.liveBgItem, 0, 0);
                return Qt.rect(pt.x + _track, pt.y, pillContainer.width, pillContainer.height);
            }
        }

        MultiEffect {
            id: frostedBlur
            anchors.fill: parent
            visible: root.hasValidLiveBg
            source: bgSource
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 0.15
            maskEnabled: true
            maskSource: pillMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        // Frosted / State tint layer
        Rectangle {
            id: tintLayer
            anchors.fill: parent
            radius: height / 2
            color: {
                if (root.currentScenario === "charging") {
                    return "transparent";
                }
                if (root.currentScenario === "media") {
                    return Qt.rgba(0.16, 0.15, 0.22, 0.58);
                }
                return root.notificationsCount > 0
                    ? Qt.rgba(0.14, 0.14, 0.23, 0.56)
                    : Qt.rgba(0.17, 0.17, 0.19, 0.54);
            }

            Behavior on color {
                ColorAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            // Charging gradient overlay matching Teal -> Green pill in reference
            Rectangle {
                id: chargingGradientLayer
                anchors.fill: parent
                radius: height / 2
                opacity: root.currentScenario === "charging" ? 0.90 : 0.0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                }

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#0B4E69" }
                    GradientStop { position: 0.52; color: "#1E865F" }
                    GradientStop { position: 1.0; color: "#68BE2B" }
                }

                // Liquid charging shimmer sweep
                Item {
                    anchors.fill: parent
                    clip: true

                    Rectangle {
                        id: shimmerBand
                        width: parent.width * 0.45
                        height: parent.height * 1.6
                        anchors.verticalCenter: parent.verticalCenter
                        rotation: 18
                        x: -width
                        opacity: root.isPluggedIn && root.currentScenario === "charging" ? 1.0 : 0.0
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.20) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                        }

                        SequentialAnimation on x {
                            running: root.visible && root.isPluggedIn && root.currentScenario === "charging"
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: -shimmerBand.width - 20
                                to: pillContainer.width + 20
                                duration: 1900
                                easing.type: Easing.InOutQuad
                            }
                            PauseAnimation { duration: 1200 }
                        }
                    }
                }
            }

            // Subtle top-down glass sheen
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.14) }
                    GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.03) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.10) }
                }
            }
        }

        // Specular 1px inner border / shadow highlight (Y=1, #FFFFFF 25%)
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: root.currentScenario === "charging"
                ? Qt.rgba(1, 1, 1, 0.30)
                : Qt.rgba(1, 1, 1, 0.25)
        }

        // Sliding inner scenario content
        Item {
            id: contentClip
            anchors.fill: parent
            clip: true

            RowLayout {
                id: innerRow
                anchors.fill: parent
                anchors.leftMargin: 11
                anchors.rightMargin: 15
                anchors.topMargin: 11
                anchors.bottomMargin: 11
                spacing: 10
                x: root.swipeOffsetX * 0.45
                opacity: Math.max(0.25, 1.0 - Math.abs(root.swipeOffsetX) / 110)

                // Small 34x34 inner circular badge (11px top, left, bottom gaps)
                Rectangle {
                    id: innerBadge
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    Layout.alignment: Qt.AlignVCenter
                    radius: 17
                    color: root.currentScenario === "charging"
                        ? Qt.rgba(1, 1, 1, 0.18)
                        : Qt.rgba(1, 1, 1, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                    clip: true

                    Image {
                        anchors.fill: parent
                        visible: root.currentScenario === "media" && root.mediaArtUrl.toString().length > 0
                        source: root.mediaArtUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        visible: !(root.currentScenario === "media" && root.mediaArtUrl.toString().length > 0)
                        source: {
                            if (root.currentScenario === "charging") {
                                return root.isPluggedIn ? "battery-charging" : "battery-good";
                            }
                            if (root.currentScenario === "media") {
                                return "media-playback-start";
                            }
                            return "notifications";
                        }
                        isMask: true
                        color: root.currentScenario === "charging"
                            ? "#3EF278"
                            : Qt.rgba(1, 1, 1, 0.78)
                    }
                }

                // Pill label
                Text {
                    id: pillLabel
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.activeLabel
                    color: Qt.rgba(1, 1, 1, 0.92)
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Unified horizontal card-switch + vertical pop-out + tap gesture handler
        MouseArea {
            id: gestureArea
            anchors.fill: parent
            preventStealing: true

            property real startX: 0
            property real startY: 0
            property string gestureAxis: ""

            onPressed: function(mouse) {
                startX = mouse.x;
                startY = mouse.y;
                gestureAxis = "";
                root.pressFeedback = true;
            }

            onPositionChanged: function(mouse) {
                var dx = mouse.x - startX;
                var dy = mouse.y - startY;

                if (gestureAxis === "" && (Math.abs(dx) > 8 || Math.abs(dy) > 8)) {
                    gestureAxis = Math.abs(dx) >= Math.abs(dy) ? "x" : "y";
                }

                if (gestureAxis === "x" && root.scenarios.length > 1) {
                    root.swipeOffsetX = Math.max(-72, Math.min(72, dx));
                } else if (gestureAxis === "y" && dy < -22) {
                    root.pressFeedback = false;
                    root.openNotificationsRequested();
                    gestureAxis = "done";
                }
            }

            onReleased: function(mouse) {
                root.pressFeedback = false;
                var dx = mouse.x - startX;

                if (gestureAxis === "x" && root.scenarios.length > 1) {
                    if (dx < -34) {
                        root.currentScenarioIndex = (root.currentScenarioIndex + 1) % root.scenarios.length;
                    } else if (dx > 34) {
                        root.currentScenarioIndex = (root.currentScenarioIndex - 1 + root.scenarios.length) % root.scenarios.length;
                    }
                } else if (gestureAxis === "") {
                    if (root.currentScenario === "media" && root.mprisModel) {
                        root.mprisModel.playPause();
                    } else {
                        root.toggleNotificationsRequested();
                    }
                }
                swipeResetAnim.restart();
            }

            onCanceled: {
                root.pressFeedback = false;
                swipeResetAnim.restart();
            }
        }

        NumberAnimation {
            id: swipeResetAnim
            target: root
            property: "swipeOffsetX"
            to: 0
            duration: 240
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }
}