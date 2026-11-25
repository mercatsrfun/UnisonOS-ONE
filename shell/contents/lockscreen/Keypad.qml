// SPDX-FileCopyrightText: 2020-2024 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.kirigami as Kirigami

Item {
    id: root
    Loader { id: wpPathLoader; source: "file:///home/jayjayc/.config/argon-wallpapers.qml" }
    required property real openProgress
    property real swipeIntensity: 0.5
    readonly property real dynamicOvershoot: 1.50 + Math.min(0.45, Math.max(0.0, root.swipeIntensity) * 0.45)
    readonly property int dynamicDuration: Math.round(500 - Math.min(0.5, Math.max(0.0, root.swipeIntensity)) * 70)
    required property var lockScreenState
    property alias passwordBar: passwordBar

    MobileShell.HapticsEffect { id: haptics }

    readonly property real appearT: Math.max(0.0, Math.min(1.0, (openProgress - 0.28) / 0.72))
    property real headerT: 0.0
    property real footerT: 0.0

    visible: appearT > 0.001
    opacity: appearT

    states: [
        State { name: "keypadShown"; when: root.openProgress >= 0.34; PropertyChanges { target: root; headerT: 1.0; footerT: 1.0 } },
        State { name: "keypadHidden"; when: root.openProgress < 0.34; PropertyChanges { target: root; headerT: 0.0; footerT: 0.0 } }
    ]

    transitions: [
        Transition {
            to: "keypadShown"
            ParallelAnimation {
                NumberAnimation { target: root; property: "headerT"; duration: root.dynamicDuration; easing.type: Easing.OutBack; easing.overshoot: root.dynamicOvershoot }
                SequentialAnimation {
                    PauseAnimation { duration: 60 }
                    NumberAnimation { target: root; property: "footerT"; duration: root.dynamicDuration; easing.type: Easing.OutBack; easing.overshoot: root.dynamicOvershoot }
                }
            }
        },
        Transition {
            to: "keypadHidden"
            NumberAnimation { target: root; properties: "headerT,footerT"; duration: 120; easing.type: Easing.InCubic }
        }
    ]

    readonly property var subLettersMap: ({
        "1": "", "2": "ABC", "3": "DEF",
        "4": "GHI", "5": "JKL", "6": "MNO",
        "7": "PQRS", "8": "TUV", "9": "WXYZ",
        "0": ""
    })
    // Single pre-blurred wallpaper texture shared by all 10 digit buttons (10x faster 60fps spring animation!)
    Item {
        id: sharedBlurSource
        visible: false
        width: root.width > 0 ? root.width : 393
        height: root.height > 0 ? root.height : 852
        Image {
            anchors.fill: parent
            source: (wpPathLoader.item && wpPathLoader.item.lockUrl.length > 0) ? wpPathLoader.item.lockUrl : "file:///home/jayjayc/custom-wallpaper.png"
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 196; sourceSize.height: 426
            smooth: true
            layer.enabled: true
            layer.effect: FastBlur { radius: 30 }
        }
    }

    ShaderEffectSource {
        id: sharedBlurredWpTex
        visible: false
        sourceItem: sharedBlurSource
        live: true
    }

    ColumnLayout {
        id: keypadVerticalContainer
        width: parent.width
        anchors.top: parent.top
        anchors.topMargin: Math.max(46, parent.height * 0.08)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44
        spacing: 0

        ColumnLayout {
            id: headerGroup
            Layout.fillWidth: true
            spacing: 0
            opacity: Math.max(0.0, Math.min(1.0, root.headerT * 1.35))
            transform: Translate { y: (1.0 - root.headerT) * 78 }

            Canvas {
                Layout.alignment: Qt.AlignHCenter
                width: 64; height: 64
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.save();
                    ctx.shadowColor = "rgba(255, 255, 255, 0.65)";
                    ctx.shadowBlur = 14;
                    ctx.strokeStyle = "#FFFFFF";
                    ctx.lineWidth = 2.4;
                    ctx.lineJoin = "round";
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.moveTo(32, 16);
                    ctx.lineTo(43, 20.2);
                    ctx.lineTo(43, 29.5);
                    ctx.bezierCurveTo(43, 37.0, 37.8, 41.8, 32, 44.2);
                    ctx.bezierCurveTo(26.2, 41.8, 21, 37.0, 21, 29.5);
                    ctx.lineTo(21, 20.2);
                    ctx.closePath();
                    ctx.stroke();
                    ctx.restore();
                }
            }

            Text {
                id: descriptionLabel
                Layout.fillWidth: true
                Layout.topMargin: 4
                horizontalAlignment: Text.AlignHCenter
                text: (root.lockScreenState.pinLabel && root.lockScreenState.pinLabel.length > 0 && root.lockScreenState.pinLabel !== "Enter PIN")
                      ? root.lockScreenState.pinLabel : "Enter Pin"
                font.family: "Google Sans Flex"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: "#FFFFFF"
            }

            PasswordBar {
                id: passwordBar
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 66
                Layout.preferredWidth: 220
                Layout.preferredHeight: 24
                lockScreenState: root.lockScreenState
                isKeypadOpen: root.openProgress >= 0.9
                enabled: root.openProgress >= 0.8
            }
        }

        Item { Layout.fillHeight: true; Layout.minimumHeight: 24 }

        GridLayout {
            id: keypadGrid
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            columnSpacing: 26
            rowSpacing: 18

            Repeater {
                model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "R", "0", "E"]

                delegate: AbstractButton {
                    id: button
                    readonly property bool isDigit: modelData !== "R" && modelData !== "E"
                    readonly property string subText: root.subLettersMap[modelData] || ""
                    readonly property int colIdx: index % 3
                    readonly property int centerDist: Math.abs(colIdx - 1)
                    readonly property int rowIdx: Math.floor(index / 3)
                    readonly property bool colRevealed: root.openProgress >= 0.34
                    property real springT: 0.0

                    states: [
                        State { name: "shown"; when: button.colRevealed; PropertyChanges { target: button; springT: 1.0 } },
                        State { name: "hidden"; when: !button.colRevealed; PropertyChanges { target: button; springT: 0.0 } }
                    ]
                    transitions: [
                        Transition {
                            to: "shown"
                            SequentialAnimation {
                                PauseAnimation { duration: button.centerDist * 58 + button.rowIdx * 20 }
                                NumberAnimation { target: button; property: "springT"; duration: root.dynamicDuration; easing.type: Easing.OutBack; easing.overshoot: root.dynamicOvershoot }
                            }
                        },
                        Transition { to: "hidden"; NumberAnimation { target: button; property: "springT"; duration: 120; easing.type: Easing.InCubic } }
                    ]

                    implicitWidth: 80; implicitHeight: 80
                    Layout.preferredWidth: 80; Layout.preferredHeight: 80
                    enabled: root.openProgress >= 0.8 && !lockScreenState.isKeyboardMode

                    opacity: Math.max(0.0, Math.min(1.0, springT * 1.35))
                    property real pressScale: pressed ? 1.16 : 1.0
                    Behavior on pressScale {
                        NumberAnimation {
                            duration: button.pressed ? 260 : 380
                            easing.type: Easing.OutBack
                            easing.overshoot: button.pressed ? 1.55 : 1.85
                        }
                    }
                    scale: (0.88 + 0.12 * Math.min(1.0, springT)) * pressScale
                    transform: Translate { y: (1.0 - button.springT) * 104 }
                    background: Item {}
                    onPressedChanged: if (pressed) haptics.buttonVibrate()
                    onClicked: {
                        if (modelData === "R") passwordBar.backspace();
                        else if (modelData === "E") passwordBar.enter();
                        else passwordBar.keyPress(modelData);
                    }
                    onPressAndHold: if (modelData === "R") { haptics.buttonVibrate(); passwordBar.clear(); }

                    contentItem: Item {
                        anchors.fill: parent

                        // No gray circle background on Backspace / Submit

                        // Seamless Outer Glow Halo (transparentBorder: true eliminates square clipping)
                        Rectangle {
                            z: -2
                            visible: button.isDigit
                            anchors.centerIn: parent
                            width: 80; height: 80; radius: 40
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.42)
                            opacity: button.pressed ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: button.pressed ? 80 : 240 } }
                            layer.enabled: true
                            layer.effect: FastBlur { radius: 12; transparentBorder: true }
                        }

                        // Exact QuickActionButton Glass Material (Uniform 30 BG Blur + #696969/#FFFFFF blend + Inner Shadow)
                        Rectangle {
                            id: keyCircleMask
                            visible: false
                            width: 80; height: 80; radius: 40
                            color: "#FFFFFF"
                            layer.enabled: true
                            layer.smooth: true
                        }

                        Item {
                            z: -1
                            visible: button.isDigit
                            width: 80; height: 80
                            anchors.centerIn: parent
                            layer.enabled: true
                            layer.smooth: true
                            layer.effect: OpacityMask { maskSource: keyCircleMask }

                            ShaderEffectSource {
                                width: root.width > 0 ? root.width : 393
                                height: root.height > 0 ? root.height : 852
                                x: -(keypadGrid.x + button.x)
                                y: -(keypadVerticalContainer.y + keypadGrid.y + button.y)
                                sourceItem: sharedBlurredWpTex
                                live: false
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0.412, 0.412, 0.412, button.pressed ? 0.30 : 0.18)
                                Behavior on color { ColorAnimation { duration: button.pressed ? 80 : 240 } }
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(1.0, 1.0, 1.0, button.pressed ? 0.24 : 0.08)
                                Behavior on color { ColorAnimation { duration: button.pressed ? 80 : 240 } }
                            }

                            // Exact Inner Shadow: X: 0, Y: 1, Blur: 4, #FFFFFF 25%
                            Item {
                                anchors.fill: parent; clip: true
                                Rectangle {
                                    x: -1; y: 1.2
                                    width: parent.width + 2; height: parent.height + 2; radius: 41
                                    color: "transparent"
                                    border.width: button.pressed ? 2.4 : 2.0
                                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.25)
                                    layer.enabled: true
                                    layer.effect: FastBlur { radius: button.pressed ? 5 : 4 }
                                }
                            }
                        }

                        Text {
                            visible: button.isDigit
                            anchors.centerIn: parent
                            text: modelData
                            font.family: "Google Sans Flex"
                            font.pixelSize: 30
                            font.weight: Font.DemiBold
                            color: Qt.rgba(1.0, 1.0, 1.0, button.pressed ? 1.0 : 0.50)
                        }

                        Canvas {
                            visible: modelData === "R"
                            anchors.centerIn: parent
                            width: 26; height: 20
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.85)";
                                ctx.lineWidth = 1.8;
                                ctx.lineJoin = "round";
                                ctx.lineCap = "round";
                                ctx.beginPath();
                                ctx.moveTo(8.5, 3); ctx.lineTo(22.5, 3);
                                ctx.quadraticCurveTo(24.5, 3, 24.5, 5);
                                ctx.lineTo(24.5, 15);
                                ctx.quadraticCurveTo(24.5, 17, 22.5, 17);
                                ctx.lineTo(8.5, 17); ctx.lineTo(2.5, 10);
                                ctx.closePath(); ctx.stroke();
                                ctx.beginPath();
                                ctx.moveTo(13, 7.2); ctx.lineTo(18.6, 12.8);
                                ctx.moveTo(18.6, 7.2); ctx.lineTo(13, 12.8);
                                ctx.stroke();
                            }
                        }

                        Canvas {
                            visible: modelData === "E"
                            anchors.centerIn: parent
                            width: 22; height: 22
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.88)";
                                ctx.lineWidth = 2.1;
                                ctx.lineJoin = "round";
                                ctx.lineCap = "round";
                                ctx.beginPath();
                                ctx.moveTo(8, 5); ctx.lineTo(15, 11); ctx.lineTo(8, 17);
                                ctx.stroke();
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true; Layout.minimumHeight: 20 }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Swipe up to use fingerprint"
            font.family: "Google Sans Flex"
            font.pixelSize: 15
            font.weight: Font.Medium
            color: Qt.rgba(1.0, 1.0, 1.0, 0.85)
            opacity: Math.max(0.0, Math.min(1.0, root.footerT * 1.35))
            transform: Translate { y: (1.0 - root.footerT) * 90 }
        }
    }
}
