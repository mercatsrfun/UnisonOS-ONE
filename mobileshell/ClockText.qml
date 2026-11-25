import QtQuick
import QtQuick.Layouts
import org.kde.plasma.clock
import org.kde.plasma.private.mobileshell as MobileShell

RowLayout {
    id: clockText
    required property int fontPixelSize
    required property Clock clockSource

    Text {
        property bool is24HourTime: MobileShell.ShellUtil.isSystem24HourFormat
        text: Qt.formatTime(clockSource.dateTime, is24HourTime ? "h:mm" : "h:mm ap")
        color: "#FFFFFF"
        verticalAlignment: Text.AlignVCenter
        font.family: "Google Sans Flex"
        font.pixelSize: 15
        font.weight: Font.Bold
        font.letterSpacing: 0.2
    }
}
