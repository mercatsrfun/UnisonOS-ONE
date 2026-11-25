import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.clock
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.private.mobileshell.state as MobileShellState

Item {
    id: root
    property bool showDropShadow: false
    property color backgroundColor: "transparent"
    property bool showSecondRow: false
    property bool showTime: true

    readonly property real textPixelSize: Math.round(14 * ShellSettings.Settings.statusBarScaleFactor)
    readonly property real smallerTextPixelSize: Math.round(10 * ShellSettings.Settings.statusBarScaleFactor)
    readonly property real elementSpacing: 7

    readonly property string carrierText: {
        var lbl = (MobileShell.SignalStrengthInfo.label || "").trim();
        if (lbl.length === 0 || lbl === "No SIM" || lbl === "SIM Locked") return "PROVIDER";
        return lbl.toUpperCase();
    }

    readonly property bool hasCellular: {
        var lbl = (MobileShell.SignalStrengthInfo.label || "").trim();
        return lbl.length > 0 && lbl !== "No SIM" && lbl !== "SIM Locked";
    }

    Clock { id: clockSource }
    MobileShellState.PanelSettingsDBusClient { id: panelSettings; screenName: Screen.name }

    MultiEffect {
        anchors.fill: control
        visible: showDropShadow
        source: control
        blurMax: 16
        shadowEnabled: true
        shadowVerticalOffset: 1
        shadowOpacity: 0.55
    }

    Controls.Control {
        id: control
        z: 1
        topPadding: 6
        bottomPadding: 4
        leftPadding: 18 + panelSettings.statusBarLeftPadding
        rightPadding: 18 + panelSettings.statusBarRightPadding
        anchors.fill: parent
        background: Rectangle { color: backgroundColor }

        contentItem: ColumnLayout {
            spacing: 2

            RowLayout {
                id: mainRow
                readonly property real rowHeight: Math.max(20, MobileShell.Constants.defaultTopPanelHeight - 10)
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: rowHeight
                spacing: 0

                ClockText {
                    visible: root.showTime
                    Layout.fillHeight: true
                    fontPixelSize: 15
                    clockSource: clockSource
                }

                Text {
                    visible: !root.showTime
                    Layout.fillHeight: true
                    verticalAlignment: Text.AlignVCenter
                    text: root.carrierText
                    color: "#FFFFFF"
                    font.family: "Google Sans Flex"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    font.letterSpacing: 0.6
                }

                Item { Layout.fillWidth: true }
                RowLayout {
                    id: indicators
                    Layout.alignment: Qt.AlignVCenter
                    spacing: root.elementSpacing

                    Canvas {
                        width: 15; height: 15
                        Layout.alignment: Qt.AlignVCenter
                        property bool activeCell: root.hasCellular
                        onActiveCellChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.fillStyle = "#FFFFFF";
                            ctx.strokeStyle = "#FFFFFF";
                            if (!activeCell) {
                                ctx.beginPath();
                                ctx.moveTo(5.2, 2.0);
                                ctx.lineTo(11.8, 2.0);
                                ctx.quadraticCurveTo(13.0, 2.0, 13.0, 3.2);
                                ctx.lineTo(13.0, 12.8);
                                ctx.quadraticCurveTo(13.0, 14.0, 11.8, 14.0);
                                ctx.lineTo(3.2, 14.0);
                                ctx.quadraticCurveTo(2.0, 14.0, 2.0, 12.8);
                                ctx.lineTo(2.0, 5.4);
                                ctx.closePath();
                                ctx.fill();
                                ctx.globalCompositeOperation = "destination-out";
                                ctx.fillRect(8.2, 1.5, 5.5, 5.5);
                                ctx.globalCompositeOperation = "source-over";
                                ctx.lineWidth = 1.6;
                                ctx.lineCap = "round";
                                ctx.beginPath();
                                ctx.moveTo(9.4, 2.5); ctx.lineTo(12.8, 5.9);
                                ctx.moveTo(12.8, 2.5); ctx.lineTo(9.4, 5.9);
                                ctx.stroke();
                            } else {
                                var heights = [4, 7, 10, 13];
                                for (var i = 0; i < 4; i++) {
                                    ctx.beginPath();
                                    ctx.roundedRect(1.5 + i * 3.3, 14 - heights[i], 2.2, heights[i], 1, 1);
                                    ctx.fill();
                                }
                            }
                        }
                    }

                    Canvas {
                        width: 17; height: 15
                        Layout.alignment: Qt.AlignVCenter
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.strokeStyle = "#FFFFFF";
                            ctx.fillStyle = "#FFFFFF";
                            ctx.lineCap = "round";
                            ctx.lineWidth = 1.85;
                            var cx = 8.5, cy = 12.6;
                            var radii = [10.2, 6.8, 3.5];
                            for (var i = 0; i < radii.length; i++) {
                                ctx.beginPath();
                                ctx.arc(cx, cy, radii[i], -Math.PI * 0.76, -Math.PI * 0.24);
                                ctx.stroke();
                            }
                            ctx.beginPath();
                            ctx.arc(cx, cy, 1.35, 0, Math.PI * 2);
                            ctx.fill();
                        }
                    }

                    Item {
                        width: 25; height: 13
                        Layout.alignment: Qt.AlignVCenter
                        readonly property real chargeRatio: Math.max(0.12, Math.min(1.0, (MobileShell.BatteryInfo.percent || 75) / 100.0))
                        onChargeRatioChanged: batFill.width = Math.round(18 * chargeRatio)

                        Rectangle {
                            x: 0; y: 0.5
                            width: 22; height: 12
                            radius: 3.5
                            color: "transparent"
                            border.width: 1.5
                            border.color: "#FFFFFF"
                            Rectangle {
                                id: batFill
                                x: 2; y: 2
                                width: Math.round(18 * parent.parent.chargeRatio)
                                height: 8
                                radius: 1.8
                                color: "#FFFFFF"
                            }
                        }
                        Rectangle {
                            x: 23; y: 4.5
                            width: 1.8; height: 4
                            radius: 0.9
                            color: "#FFFFFF"
                        }
                    }
                }
            }

            RowLayout {
                spacing: 0
                visible: root.showSecondRow
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: clockSource.dateTime.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.family: "Google Sans Flex"
                    font.pixelSize: root.smallerTextPixelSize
                }
                Item { Layout.fillWidth: true }
                PlasmaComponents.Label {
                    visible: root.showTime
                    text: root.carrierText
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.family: "Google Sans Flex"
                    font.pixelSize: root.smallerTextPixelSize
                    horizontalAlignment: Qt.AlignRight
                }
            }
        }
    }
}
