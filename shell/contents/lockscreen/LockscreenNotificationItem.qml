import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Item {
    id: root

    property Item liveBgItem: null
    property string applicationName: ""
    property string applicationIconName: ""
    property var iconSource: ""
    property string summary: ""
    property string body: ""
    property var created: null
    property var updated: null
    property var actionNames: []
    property var actionLabels: []
    property bool hasDefaultAction: false
    property bool hasReplyAction: false
    property string replyActionLabel: ""
    property string replyPlaceholderText: ""
    property string replySubmitButtonText: ""
    property bool closable: true
    property bool configurable: false
    property bool isGroup: false
    property int groupChildrenCount: 0
    property bool expanded: false

    signal closeRequested()
    signal actionInvoked(string actionName)
    signal defaultActionInvoked()
    signal replySubmitted(string text)
    signal configureRequested()

    readonly property bool hasValidLiveBg: liveBgItem !== null
        && liveBgItem.visible
        && liveBgItem.opacity > 0.01
        && liveBgItem.width > 0
        && liveBgItem.height > 0

    implicitHeight: contentCol.implicitHeight + 28
    height: implicitHeight

    property real dragX: 0
    readonly property real swipeProgress: Math.max(-1.0, Math.min(1.0, dragX / Math.max(120, width * 0.42)))

    Item {
        id: cardVisual
        width: root.width
        height: root.height
        x: root.dragX
        opacity: Math.max(0.15, 1.0 - Math.abs(root.swipeProgress) * 0.65)
        scale: 1.0 - Math.abs(root.swipeProgress) * 0.04

        transform: Rotation {
            origin.x: cardVisual.width / 2
            origin.y: cardVisual.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.swipeProgress * 16
        }

        Rectangle {
            id: cardMask
            anchors.fill: parent
            radius: 22
            color: "#ffffff"
            visible: false
            layer.enabled: true
        }

        ShaderEffectSource {
            id: cardBgSource
            anchors.fill: parent
            visible: root.hasValidLiveBg
            live: root.hasValidLiveBg
            recursive: false
            sourceItem: root.hasValidLiveBg ? root.liveBgItem : null
            sourceRect: {
                var _track = (cardVisual.x + root.y + root.width + root.height) * 0;
                if (!root.hasValidLiveBg) {
                    return Qt.rect(0, 0, 1, 1);
                }
                var pt = cardVisual.mapToItem(root.liveBgItem, 0, 0);
                return Qt.rect(pt.x + _track, pt.y, cardVisual.width, cardVisual.height);
            }
        }

        MultiEffect {
            anchors.fill: parent
            visible: root.hasValidLiveBg
            source: cardBgSource
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 0.15
            maskEnabled: true
            maskSource: cardMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: Qt.rgba(0.13, 0.13, 0.19, 0.66)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.22)
        }

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.15)

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 15
                        height: 15
                        source: root.applicationIconName.length > 0 ? root.applicationIconName : (root.iconSource !== "" ? root.iconSource : "notifications")
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.applicationName.length > 0 ? root.applicationName : qsTr("Notification")
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: root.closable
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 11
                    color: closeBtnArea.pressed ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.12)

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        source: "window-close"
                        isMask: true
                        color: Qt.rgba(1, 1, 1, 0.8)
                    }

                    MouseArea {
                        id: closeBtnArea
                        anchors.fill: parent
                        onClicked: root.closeRequested()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.summary.length > 0
                text: root.summary
                color: Qt.rgba(1, 1, 1, 0.96)
                font.pixelSize: 15
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.body.length > 0
                text: root.body
                color: Qt.rgba(1, 1, 1, 0.80)
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            Flow {
                Layout.fillWidth: true
                visible: root.actionLabels && root.actionLabels.length > 0
                spacing: 8

                Repeater {
                    model: root.actionLabels ? root.actionLabels.length : 0

                    Rectangle {
                        implicitWidth: actionTxt.implicitWidth + 24
                        implicitHeight: 30
                        radius: 15
                        color: actArea.pressed ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.16)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.22)

                        Text {
                            id: actionTxt
                            anchors.centerIn: parent
                            text: root.actionLabels[index] || ""
                            color: Qt.rgba(1, 1, 1, 0.94)
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: actArea
                            anchors.fill: parent
                            onClicked: {
                                if (root.actionNames && index < root.actionNames.length) {
                                    root.actionInvoked(root.actionNames[index]);
                                }
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: swipeArea
            anchors.fill: parent
            z: -1
            preventStealing: true
            property real startX: 0

            onPressed: function(mouse) { startX = mouse.x; }
            onPositionChanged: function(mouse) {
                if (root.closable) {
                    root.dragX = mouse.x - startX;
                }
            }
            onReleased: {
                if (root.closable && Math.abs(root.dragX) > root.width * 0.36) {
                    dismissAnim.to = root.dragX > 0 ? root.width * 1.2 : -root.width * 1.2;
                    dismissAnim.restart();
                } else {
                    snapBackAnim.restart();
                }
            }
            onCanceled: snapBackAnim.restart()
        }
    }

    NumberAnimation {
        id: snapBackAnim
        target: root
        property: "dragX"
        to: 0
        duration: 240
        easing.type: Easing.OutBack
        easing.overshoot: 1.15
    }

    NumberAnimation {
        id: dismissAnim
        target: root
        property: "dragX"
        duration: 200
        easing.type: Easing.InCubic
        onFinished: root.closeRequested()
    }
}
