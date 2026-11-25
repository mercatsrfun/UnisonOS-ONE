import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami

Item {
    id: root

    property int layoutAlignment: Qt.AlignHCenter
    property Item liveBgItem: null
    property date currentDateTime: new Date()

    implicitWidth: clockColumn.implicitWidth
    implicitHeight: clockColumn.implicitHeight

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentDateTime = new Date()
    }

    readonly property string dayPrefix: Qt.formatDate(root.currentDateTime, "ddd, ")
    readonly property string dayNumber: Qt.formatDate(root.currentDateTime, "d")
    readonly property string monthSuffix: Qt.formatDate(root.currentDateTime, " MMM")
    readonly property string hourText: Qt.formatTime(root.currentDateTime, "hh")
    readonly property string minuteText: Qt.formatTime(root.currentDateTime, "mm")

    readonly property bool isClockEasterEgg: root.hourText === "12" && root.minuteText === "25"
    readonly property bool isDateEasterEgg: (root.currentDateTime.getMonth() + 1) === 12 && root.currentDateTime.getDate() === 25

    component DateText : Text {
        font.family: "Google Sans Flex"
        font.pixelSize: 22
        font.weight: Font.Normal
        font.variableAxes: ({ "wght": 700, "wdth": 107, "ROND": 100, "opsz": 22 })
        renderType: Text.CurveRendering
        antialiasing: true
    }

    component FrostedClockGlyph : Item {
        id: fg
        property string text: ""
        property int pixelSize: 106
        property int fontWeight: Font.Normal
        property real letterSpacing: -2.0
        property real lineHeight: 0.92
        property color baseColor: "#C5CDD8"
        property real baseOpacity: 0.62
        property color softTintColor: "#FFFFFF"
        property real softTintOpacity: 0.18

        implicitWidth: glyphMask.implicitWidth
        implicitHeight: glyphMask.implicitHeight

        Text {
            id: glyphMask
            anchors.centerIn: parent
            text: fg.text
            color: "#FFFFFF"
            font.family: "Google Sans Flex"
            font.variableAxes: ({ "wght": 700, "wdth": 107, "ROND": 100, "opsz": 120 })
            font.pixelSize: fg.pixelSize
            font.weight: fg.fontWeight
            font.letterSpacing: fg.letterSpacing
            lineHeight: fg.lineHeight
            renderType: Text.CurveRendering
            antialiasing: true
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
        }

        Text {
            id: shiftedCutout
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1.0
            text: fg.text
            color: "#FFFFFF"
            font.family: "Google Sans Flex"
            font.variableAxes: ({ "wght": 700, "wdth": 107, "ROND": 100, "opsz": 120 })
            font.pixelSize: fg.pixelSize
            font.weight: fg.fontWeight
            font.letterSpacing: fg.letterSpacing
            lineHeight: fg.lineHeight
            renderType: Text.CurveRendering
            antialiasing: true
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
            layer.effect: OpacityMask {
                maskSource: glyphMask
                cached: false
            }

            Image {
                property point globalPos: fg.mapToItem(null, 0, 0)
                x: -globalPos.x
                y: -globalPos.y
                width: fg.Window.width > 0 ? fg.Window.width : 393
                height: fg.Window.height > 0 ? fg.Window.height : 852
                source: "file:///home/jayjayc/wallpaper_blurred_clock.png"
                fillMode: Image.PreserveAspectCrop
                smooth: true
                cache: false
            }

            Rectangle {
                anchors.fill: parent
                color: fg.baseColor
                opacity: fg.baseOpacity
            }

            Rectangle {
                anchors.fill: parent
                color: fg.softTintColor
                opacity: fg.softTintOpacity
            }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.32
                    blurMax: 8
                }

                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: shiftedCutout
                        maskInverted: true
                        maskThresholdMin: 0.20
                        maskSpreadAtMin: 0.25
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(1, 1, 1, 0.25)
                    }
                }
            }
        }
    }

    Column {
        id: clockColumn
        anchors.horizontalCenter: root.layoutAlignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
        anchors.left: root.layoutAlignment === Qt.AlignLeft ? parent.left : undefined
        spacing: 4

        Row {
            anchors.horizontalCenter: root.layoutAlignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
            spacing: 0

            DateText {
                text: root.dayPrefix
                color: "#C8D0DC"
                opacity: 0.88
            }

            DateText {
                text: root.dayNumber
                color: root.isDateEasterEgg ? "#4B70FF" : "#C8D0DC"
                opacity: root.isDateEasterEgg ? 0.96 : 0.88
            }

            DateText {
                text: root.monthSuffix
                color: "#C8D0DC"
                opacity: 0.88
            }
        }

        Row {
            anchors.horizontalCenter: root.layoutAlignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
            spacing: -2

            FrostedClockGlyph {
                id: hoursLabel
                text: root.hourText
                pixelSize: 106
                fontWeight: Font.Normal
                letterSpacing: -2.0
                lineHeight: 0.92
                baseColor: "#C2CAD6"
                baseOpacity: 0.62
                softTintColor: "#FFFFFF"
                softTintOpacity: 0.18
            }

            FrostedClockGlyph {
                id: colonLabel
                text: ":"
                pixelSize: 98
                fontWeight: Font.Normal
                letterSpacing: 0
                lineHeight: 0.92
                anchors.verticalCenter: hoursLabel.verticalCenter
                anchors.verticalCenterOffset: -7
                baseColor: "#7F7CF0"
                baseOpacity: 0.66
                softTintColor: "#D6D8FF"
                softTintOpacity: 0.24
            }

            FrostedClockGlyph {
                id: minutesLabel
                text: root.minuteText
                pixelSize: 106
                fontWeight: Font.Normal
                letterSpacing: -2.0
                lineHeight: 0.92
                baseColor: root.isClockEasterEgg ? "#3D66FF" : "#C2CAD6"
                baseOpacity: root.isClockEasterEgg ? 0.78 : 0.62
                softTintColor: root.isClockEasterEgg ? "#A3BEFF" : "#FFFFFF"
                softTintOpacity: root.isClockEasterEgg ? 0.38 : 0.18
            }
        }
    }
}
