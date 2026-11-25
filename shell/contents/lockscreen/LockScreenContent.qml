// SPDX-FileCopyrightText: 2021-2024 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import org.kde.kirigami as Kirigami
import org.kde.plasma.quicksetting.flashlight
import org.kde.plasma.workspace.keyboardlayout 1.0
import org.kde.notificationmanager as Notifications
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings

Item {
    id: root

    required property bool isVertical
    required property var lockScreenState
    property Item liveBgItem: null
    property real screenPowerT: 1.0
    readonly property real clockPowerOpacity: 1.0
    readonly property real bottomPowerOpacity: 1.0

    readonly property bool listOverflowing: false

    property var notificationsModel: []
    property bool notificationsShown: false
    property bool scrollLock: false

    signal passwordRequested()

    // Vertical layout
    ColumnLayout {
        id: verticalLayout
        visible: root.isVertical
        spacing: 0

        anchors.topMargin: Kirigami.Units.gridUnit * 3.5
        anchors.bottomMargin: Kirigami.Units.gridUnit * 2
        anchors.fill: parent

        LayoutItemProxy { target: clockAndMediaWidget }
        LayoutItemProxy { target: notificationComponent }

        LayoutItemProxy { target: actionButtons }
    }

    // Horizontal layout (landscape on smaller devices)
    Item {
        id: horizontalLayout
        anchors.fill: parent
        visible: !root.isVertical

        ColumnLayout {
            id: leftLayout
            width: Math.round(parent.width / 2.15)
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                leftMargin: Kirigami.Units.gridUnit * 3
                bottomMargin: Kirigami.Units.gridUnit * 3
            }

            LayoutItemProxy { target: clockAndMediaWidget }
        }

        ColumnLayout {
            id: rightLayout
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: leftLayout.right
                right: parent.right
                rightMargin: Kirigami.Units.gridUnit
            }

            LayoutItemProxy { target: notificationComponent }
        }

        ColumnLayout {
            anchors.bottomMargin: Kirigami.Units.gridUnit
            anchors.leftMargin: Kirigami.Units.gridUnit
            anchors.rightMargin: Kirigami.Units.gridUnit
            anchors.fill: parent

            LayoutItemProxy { target: actionButtons }
        }
    }

    // Clock and media widget column
    ColumnLayout {
        id: clockAndMediaWidget
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: Kirigami.Units.gridUnit * 2.2
        spacing: Kirigami.Units.gridUnit

        opacity: (root.notificationsShown ? 0.0 : 1.0) * root.clockPowerOpacity
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Clock {
            liveBgItem: root.liveBgItem
            layoutAlignment: root.isVertical ? Qt.AlignHCenter : Qt.AlignLeft
            Layout.alignment: root.isVertical ? Qt.AlignHCenter : Qt.AlignLeft
            Layout.fillWidth: true
        }

        MobileShell.MediaControlsWidget {
            id: mediaControlsWidget
            visible: false // hidden in favor of NowBar
            Layout.alignment: root.isVertical ? Qt.AlignHCenter : Qt.AlignLeft
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
            Layout.leftMargin: root.isVertical ? Kirigami.Units.gridUnit : 0
            Layout.rightMargin: root.isVertical ? Kirigami.Units.gridUnit : 0
            panelType: MobileShell.PanelBackground.PanelType.Wallpaper
        }
    }

    // Custom Argon pop-out 3D notification stack
    NotificationsComponent {
        id: notificationComponent
        visible: root.notificationsShown
        liveBgItem: root.liveBgItem
        notificationsShown: root.notificationsShown
        nowBarOriginY: height

        Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
        Layout.fillWidth: true
        Layout.fillHeight: root.notificationsShown
        Layout.preferredHeight: root.notificationsShown ? parent.height * 0.72 : 0
        Layout.bottomMargin: root.notificationsShown ? Kirigami.Units.gridUnit : 0

        onOpenNotificationsRequested: root.notificationsShown = true
        onCloseNotificationsRequested: root.notificationsShown = false
    }

    // Full-screen tap-anywhere catcher to collapse expanded Now Brief sheet
    MouseArea {
        id: briefOutsideDismissArea
        anchors.fill: parent
        visible: nowBarPill.briefExpanded || nowBarPill.flashlightExpanded
        enabled: nowBarPill.briefExpanded || nowBarPill.flashlightExpanded
        z: 5
        onPressed: (mouse) => {
            var pt = mapToItem(nowBarPill, mouse.x, mouse.y);
            if (nowBarPill.flashlightExpanded && pt.x >= 17 && pt.x <= 187 && pt.y >= -196 && pt.y <= 50) {
                mouse.accepted = false;
                return;
            }
            if (nowBarPill.briefExpanded && pt.x >= -39 && pt.x <= 243 && pt.y >= -106 && pt.y <= 0) {
                mouse.accepted = false;
                return;
            }
        }
        onClicked: {
            nowBarPill.briefExpanded = false;
            nowBarPill.flashlightExpanded = false;
        }
    }

    // Minimalist borderless "+N Notifications" indicator pinned 24px above NowBar (image_muoV0T.png)
    Item {
        id: notifSummaryPill
        property int fileNotifCount: 3
        property string fileAppIcon: "mail-message-new"
        readonly property int totalCount: Math.max(notificationComponent.notificationsCount, fileNotifCount)
        readonly property var resolvedIcon: {
            if (notificationComponent.notificationModel && notificationComponent.notificationModel.count > 0) {
                var idx = notificationComponent.notificationModel.index(0, 0);
                var ico = notificationComponent.notificationModel.data(idx, Qt.DecorationRole);
                if (ico) return ico;
            }
            return fileAppIcon;
        }
        readonly property real flashHideFade: Math.max(0.0, Math.min(1.0, 1.0 - nowBarPill.flashlightExpandT / 0.32))
        visible: totalCount > 0 && !root.notificationsShown && flashHideFade > 0.01
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 146 + 106 * nowBarPill.briefExpandT
        width: pillRow.implicitWidth
        height: 24
        z: 95
        scale: pillTapArea.pressed ? 0.94 : 1.0
        opacity: (pillTapArea.pressed ? 0.72 : 1.0) * flashHideFade * root.bottomPowerOpacity

        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Timer {
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                var xhr = new XMLHttpRequest();
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === XMLHttpRequest.DONE && (xhr.status === 200 || xhr.status === 0) && xhr.responseText.length > 2) {
                        try {
                            var d = JSON.parse(xhr.responseText);
                            if (d.count !== undefined) notifSummaryPill.fileNotifCount = Number(d.count);
                            if (d.icon !== undefined && d.icon.length > 0) notifSummaryPill.fileAppIcon = String(d.icon);
                        } catch (e) {}
                    }
                };
                xhr.open("GET", "file:///tmp/argon_notifications.json");
                xhr.send();
            }
        }

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            opacity: 0.70
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                radius: 4
                color: "#FFFFFF"
            }

            Text {
                text: notifSummaryPill.totalCount === 1
                      ? qsTr("+1 Notification")
                      : qsTr("+%1 Notifications").arg(notifSummaryPill.totalCount)
                color: "#FFFFFF"
                font.family: "Google Sans Flex"
                font.pixelSize: 15
                font.weight: Font.Medium
                font.letterSpacing: 0.1
            }
        }

        MouseArea {
            id: pillTapArea
            anchors.fill: parent
            anchors.margins: -8
            onClicked: root.notificationsShown = true
        }
    }

    // Edge-to-edge 282x92 tap catcher for expanded Brief card (keeps NowBar dead-center at 224px!)
    MouseArea {
        id: expandedCardFullHitArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 128
        width: 282
        height: 92
        z: 115
        visible: nowBarPill.briefExpanded
        enabled: nowBarPill.briefExpanded
        onClicked: {
            nowBarPill.briefExpanded = false;
            nowBarPill.currentIndex = 0;
        }
    }

    // Bottom quick action buttons + centered NowBarPill
    RowLayout {
        id: actionButtons
        z: 110
        opacity: root.bottomPowerOpacity
        visible: opacity > 0.005

        readonly property int sideMargin: 16
        readonly property bool isVisible: true

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
        Layout.leftMargin: actionButtons.sideMargin
        Layout.rightMargin: actionButtons.sideMargin
        Layout.bottomMargin: 28

        // Left quick action button
        QuickActionButton {
            id: leftButton
            torchIntensity: nowBarPill.flashlightVisualLevel
            buttonAction: ShellSettings.Settings.lockscreenLeftButtonAction
            opacity: Math.max(0, 1 - 0 * 2)
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        // Centered NowBarPill
        NowBarPill {
            id: nowBarPill
            flashlightActive: leftButton.isActivated
            Layout.preferredWidth: 204
            Layout.minimumWidth: 204
            Layout.maximumWidth: 204
            Layout.preferredHeight: 50
            liveBgItem: root.liveBgItem
            notificationModel: notificationComponent.notificationModel
            notificationsShown: root.notificationsShown
            opacity: Math.max(0, 1 - 0 * 2)
            Layout.alignment: Qt.AlignVCenter

            onToggleNotificationsRequested: root.notificationsShown = !root.notificationsShown
            onOpenNotificationsRequested: root.notificationsShown = true
            onCloseNotificationsRequested: root.notificationsShown = false
            onSetFlashlightRequested: (enabled) => leftButton.setFlashlightEnabled(enabled)
        }

        Item { Layout.fillWidth: true }

        // Right quick action button
        QuickActionButton {
            id: rightButton
            isRightButton: true
            onActionTriggered: root.passwordRequested()
            buttonAction: ShellSettings.Settings.lockscreenRightButtonAction
            opacity: Math.max(0, 1 - 0 * 2)
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
