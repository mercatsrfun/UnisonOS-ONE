import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.mobileshell as MobileShell

Item {
    id: root
    clip: true

    // Scene wallpaper item for live frosted blur
    property Item liveBgItem: null

    // External or internal notification model
    property var notificationModel: internalModel
    property bool notificationsShown: false

    // Vertical coordinate (in root space) of NowBarPill origin for pop-out / tuck-in physics
    property real nowBarOriginY: height - 48

    signal openNotificationsRequested()
    signal closeNotificationsRequested()

    readonly property int notificationsCount: notificationModel ? notificationModel.count : 0

    NotificationManager.Notifications {
        id: internalModel
        showExpired: true
        showDismissed: false
        showJobs: true
        sortMode: NotificationManager.Notifications.SortByTypeAndUrgency
        groupMode: NotificationManager.Notifications.GroupApplications
        groupLimit: 2
    }

    // Track overall visibility smoothly for tuck-in exit animation
    visible: notificationsShown

    function clearAllNotifications() {
        if (!notificationModel) {
            return;
        }
        // Close all closable notifications from bottom to top
        for (var i = notificationModel.count - 1; i >= 0; --i) {
            var idx = notificationModel.index(i, 0);
            if (typeof notificationModel.close === "function") {
                notificationModel.close(idx);
            }
        }
        root.closeNotificationsRequested();
    }

    // Backdrop tap/swipe-down area to collapse stack back into NowBarPill
    MouseArea {
        id: dismissBackdrop
        anchors.fill: parent
        enabled: root.notificationsShown
        z: 0

        property real pressY: 0
        onPressed: function(mouse) {
            pressY = mouse.y;
        }
        onReleased: function(mouse) {
            var dy = mouse.y - pressY;
            if (dy > 32 || Math.abs(dy) < 10) {
                root.closeNotificationsRequested();
            }
        }
    }

    // Main notification stack column centered cleanly with 24px horizontal padding
    Item {
        id: stackContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(200, parent.width - 48)
        z: 1

        opacity: root.notificationsShown ? 1.0 : 0.0
        scale: root.notificationsShown ? 1.0 : 0.90
        transform: Translate {
            y: root.notificationsShown ? 0 : Math.max(40, root.nowBarOriginY - stackContainer.height * 0.5)
            Behavior on y {
                NumberAnimation {
                    duration: root.notificationsShown ? 360 : 250
                    easing.type: root.notificationsShown ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: 1.08
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.notificationsShown ? 240 : 190
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.notificationsShown ? 340 : 230
                easing.type: root.notificationsShown ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.10
            }
        }

        // Stack Header ("N Notifications" + Clear all pill)
        RowLayout {
            id: stackHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: root.notificationsCount === 1
                    ? qsTr("1 Notification")
                    : qsTr("%1 Notifications").arg(root.notificationsCount)
                color: Qt.rgba(1, 1, 1, 0.74)
                font.pixelSize: 20
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            // Frosted "Clear all" pill button
            Rectangle {
                id: clearAllPill
                visible: root.notificationsCount > 0
                implicitWidth: clearLabel.implicitWidth + 24
                implicitHeight: 28
                radius: 14
                color: clearArea.pressed
                    ? Qt.rgba(1, 1, 1, 0.28)
                    : Qt.rgba(1, 1, 1, 0.14)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.20)
                scale: clearArea.pressed ? 0.95 : 1.0

                Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

                Text {
                    id: clearLabel
                    anchors.centerIn: parent
                    text: qsTr("Clear all")
                    color: Qt.rgba(1, 1, 1, 0.88)
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    onClicked: root.clearAllNotifications()
                }
            }
        }

        // Scrollable card stack
        ListView {
            id: notificationsList
            anchors.top: stackHeader.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 12
            clip: true
            boundsBehavior: Flickable.DragOverBounds
            interactive: root.notificationsShown && contentHeight > height

            model: root.notificationModel

            // Pull down past top to collapse back into NowBarPill
            property real dragStartContentY: 0
            onDragStarted: {
                dragStartContentY = contentY;
            }
            onDragEnded: {
                if (atYBeginning && verticalVelocity < -480) {
                    root.closeNotificationsRequested();
                } else if (contentY < -52) {
                    root.closeNotificationsRequested();
                }
            }

            // Empty state when all notifications are cleared
            Text {
                anchors.centerIn: parent
                visible: notificationsList.count === 0
                text: qsTr("No notifications")
                color: Qt.rgba(1, 1, 1, 0.55)
                font.pixelSize: 15
                font.weight: Font.Medium
            }

            delegate: LockscreenNotificationCard {
                id: cardDelegate
                width: notificationsList.width

                liveBgItem: root.liveBgItem
                notificationsModel: root.notificationModel
                modelIndex: root.notificationModel ? root.notificationModel.index(index, 0) : undefined
                rowIndex: index
                notificationsShown: root.notificationsShown
                flickableContentY: notificationsList.contentY
                viewportHeight: notificationsList.height

                // Bind Plasma 6 NotificationManager roles safely
                applicationName: model.applicationName !== undefined ? String(model.applicationName) : ""
                applicationIconName: model.applicationIconName !== undefined ? String(model.applicationIconName) : ""
                iconSource: model.icon !== undefined ? model.icon : ""
                summary: model.summary !== undefined ? String(model.summary) : ""
                body: model.body !== undefined ? String(model.body) : ""
                created: model.created !== undefined ? model.created : null
                updated: model.updated !== undefined ? model.updated : null
                actionNames: model.actionNames !== undefined ? model.actionNames : []
                actionLabels: model.actionLabels !== undefined ? model.actionLabels : []
                hasDefaultAction: model.hasDefaultAction === true
                hasReplyAction: model.hasReplyAction === true
                replyActionLabel: model.replyActionLabel !== undefined ? String(model.replyActionLabel) : ""
                replyPlaceholderText: model.replyPlaceholderText !== undefined ? String(model.replyPlaceholderText) : ""
                replySubmitButtonText: model.replySubmitButtonText !== undefined ? String(model.replySubmitButtonText) : ""
                closable: model.closable !== undefined ? Boolean(model.closable) : true
                configurable: model.configurable === true
                isGroup: model.isGroup === true
                groupChildrenCount: model.groupChildrenCount !== undefined ? Number(model.groupChildrenCount) : 0

                onCloseRequested: {
                    if (root.notificationModel && typeof root.notificationModel.close === "function") {
                        root.notificationModel.close(root.notificationModel.index(index, 0));
                    }
                }
                onActionInvoked: function(actionName) {
                    if (root.notificationModel && typeof root.notificationModel.invokeAction === "function") {
                        root.notificationModel.invokeAction(root.notificationModel.index(index, 0), actionName);
                    }
                }
                onDefaultActionInvoked: {
                    if (root.notificationModel && typeof root.notificationModel.invokeDefaultAction === "function") {
                        root.notificationModel.invokeDefaultAction(root.notificationModel.index(index, 0));
                    }
                }
                onReplySubmitted: function(text) {
                    if (root.notificationModel && typeof root.notificationModel.reply === "function") {
                        root.notificationModel.reply(root.notificationModel.index(index, 0), text);
                    }
                }
            }
        }
    }
}