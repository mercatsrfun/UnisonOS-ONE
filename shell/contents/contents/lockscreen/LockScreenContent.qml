// SPDX-FileCopyrightText: 2021-2024 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.keyboardlayout 1.0
import org.kde.notificationmanager as Notifications
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings

Item {
    id: root

    required property bool isVertical
    required property var lockScreenState
    property Item liveBgItem: null

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
        Layout.fillHeight: !root.notificationsShown
        spacing: Kirigami.Units.gridUnit

        opacity: root.notificationsShown ? 0.0 : 1.0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Clock {
            layoutAlignment: root.isVertical ? Qt.AlignHCenter : Qt.AlignLeft
            Layout.alignment: root.isVertical ? Qt.AlignHCenter : Qt.AlignLeft
            Layout.fillWidth: true
        }

        MobileShell.MediaControlsWidget {
            id: mediaControlsWidget
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
        liveBgItem: root.liveBgItem
        notificationsShown: root.notificationsShown
        nowBarOriginY: height

        Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
        Layout.fillWidth: true
        Layout.fillHeight: root.notificationsShown
        Layout.preferredHeight: root.notificationsShown ? parent.height * 0.72 : 0
        Layout.bottomMargin: Kirigami.Units.gridUnit

        onOpenNotificationsRequested: root.notificationsShown = true
        onCloseNotificationsRequested: root.notificationsShown = false
    }

    // Bottom quick action buttons + centered NowBarPill
    RowLayout {
        id: actionButtons

        readonly property int sideMargin: Kirigami.Units.gridUnit * 1.5
        readonly property bool isVisible: true

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
        Layout.leftMargin: actionButtons.sideMargin
        Layout.rightMargin: actionButtons.sideMargin

        // Left quick action button
        QuickActionButton {
            id: leftButton
            buttonAction: ShellSettings.Settings.lockscreenLeftButtonAction
            opacity: Math.max(0, 1 - 0 * 2)
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        // Centered NowBarPill
        NowBarPill {
            id: nowBarPill
            liveBgItem: root.liveBgItem
            notificationModel: notificationComponent.notificationModel
            notificationsShown: root.notificationsShown
            opacity: Math.max(0, 1 - 0 * 2)
            Layout.alignment: Qt.AlignVCenter

            onToggleNotificationsRequested: root.notificationsShown = !root.notificationsShown
            onOpenNotificationsRequested: root.notificationsShown = true
            onCloseNotificationsRequested: root.notificationsShown = false
        }

        Item { Layout.fillWidth: true }

        // Right quick action button
        QuickActionButton {
            id: rightButton
            buttonAction: ShellSettings.Settings.lockscreenRightButtonAction
            opacity: Math.max(0, 1 - 0 * 2)
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
