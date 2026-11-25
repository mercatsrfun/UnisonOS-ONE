import QtQuick

Item {
    id: root

    property Item liveBgItem: null
    property var notificationsModel: null
    property var modelIndex: undefined
    property int rowIndex: 0
    property bool notificationsShown: true
    property real flickableContentY: 0
    property real viewportHeight: 500

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

    implicitHeight: cardItem.implicitHeight

    LockscreenNotificationItem {
        id: cardItem
        width: root.width
        liveBgItem: root.liveBgItem
        applicationName: root.applicationName
        applicationIconName: root.applicationIconName
        iconSource: root.iconSource
        summary: root.summary
        body: root.body
        created: root.created
        updated: root.updated
        actionNames: root.actionNames
        actionLabels: root.actionLabels
        hasDefaultAction: root.hasDefaultAction
        hasReplyAction: root.hasReplyAction
        replyActionLabel: root.replyActionLabel
        replyPlaceholderText: root.replyPlaceholderText
        replySubmitButtonText: root.replySubmitButtonText
        closable: root.closable
        configurable: root.configurable
        isGroup: root.isGroup
        groupChildrenCount: root.groupChildrenCount
        expanded: root.expanded

        onExpandedChanged: root.expanded = expanded
        onCloseRequested: {
            if (root.notificationsModel && root.modelIndex !== undefined && typeof root.notificationsModel.close === "function") {
                root.notificationsModel.close(root.modelIndex);
            }
            root.closeRequested();
        }
        onActionInvoked: function(name) {
            if (root.notificationsModel && root.modelIndex !== undefined && typeof root.notificationsModel.invokeAction === "function") {
                root.notificationsModel.invokeAction(root.modelIndex, name);
            }
            root.actionInvoked(name);
        }
        onDefaultActionInvoked: {
            if (root.notificationsModel && root.modelIndex !== undefined && typeof root.notificationsModel.invokeDefaultAction === "function") {
                root.notificationsModel.invokeDefaultAction(root.modelIndex);
            }
            root.defaultActionInvoked();
        }
        onReplySubmitted: function(text) {
            if (root.notificationsModel && root.modelIndex !== undefined && typeof root.notificationsModel.reply === "function") {
                root.notificationsModel.reply(root.modelIndex, text);
            }
            root.replySubmitted(text);
        }
        onConfigureRequested: root.configureRequested()
    }
}
