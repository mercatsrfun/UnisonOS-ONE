// SPDX-FileCopyrightText: 2020-2024 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import org.kde.plasma.workspace.keyboardlayout 1.0 as Keyboards
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mobileshell as MobileShell

Item {
    id: root
    required property var lockScreenState
    property alias textField: textField
    required property bool isKeypadOpen

    property int previewCharIndex: -2
    property real shakeOffset: 0.0
    property bool isErrorState: false
    property bool hasAttemptedSubmit: false
    MobileShell.HapticsEffect { id: haptics }
    readonly property int dotCount: (pinLengthLoader.item && pinLengthLoader.item.length >= 4 && pinLengthLoader.item.length <= 16)
                                    ? pinLengthLoader.item.length : 4

    implicitWidth: 260
    implicitHeight: 36

    Loader {
        id: pinLengthLoader
        source: "file:///home/jayjayc/.config/argon-pin-length.qml"
    }

    Connections {
        target: root.lockScreenState
        function onUnlockSucceeded() {
            root.isErrorState = false;
            if (root.lockScreenState.password.length >= 4) {
                root.dotCount = root.lockScreenState.password.length;
            }
        }
        function onUnlockFailed() {
            if (!root.hasAttemptedSubmit) return;
            root.hasAttemptedSubmit = false;
            root.isErrorState = true;
            haptics.buttonVibrate();
            wrongPinShakeAnim.restart();
        }
    }

    function backspace() {
        if (!lockScreenState.waitingForAuth) {
            autoSubmitTimer.stop();
            root.previewCharIndex = -2;
            lockScreenState.password = lockScreenState.password.substr(0, lockScreenState.password.length - 1);
        }
    }

    function clear() {
        if (!lockScreenState.waitingForAuth) {
            root.previewCharIndex = -2;
            lockScreenState.resetPassword();
        }
    }

    function enter() {
        root.hasAttemptedSubmit = true;
        lockScreenState.tryPassword();
        if (root.isKeypadOpen && root.lockScreenState.isKeyboardMode) {
            openKeyboardTimer.restart();
        }
    }

    function keyPress(data) {
        if (!lockScreenState.waitingForAuth) {
            if (data === "\x08") {
                root.backspace();
            } else if (data === "\r") {
                root.enter();
            } else if (wrongPinShakeAnim.running || root.isErrorState) {
                wrongPinShakeAnim.stop();
                root.shakeOffset = 0.0;
                root.isErrorState = false;
                root.lockScreenState.resetPassword();
                root.lockScreenState.resetPinLabel();
                root.previewCharIndex = 0;
                lockScreenState.password = data;
                letterTimer.restart();
            } else if (lockScreenState.password.length < root.dotCount) {
                root.isErrorState = false;
                root.lockScreenState.resetPinLabel();
                root.previewCharIndex = lockScreenState.password.length;
                lockScreenState.password += data;
                letterTimer.restart();
                if (lockScreenState.password.length === root.dotCount) autoSubmitTimer.restart();
            }
        }
    }

    Timer {
        id: autoSubmitTimer
        interval: 90
        repeat: false
        onTriggered: {
            if (lockScreenState.password.length === root.dotCount && !lockScreenState.waitingForAuth) {
                root.enter();
            }
        }
    }

    Timer {
        id: openKeyboardTimer
        interval: 10
        repeat: false
        onTriggered: Keyboards.KWinVirtualKeyboard.active = true
    }

    Timer {
        id: letterTimer
        interval: 500
        repeat: false
        onTriggered: root.previewCharIndex = -2
    }

    TextField {
        id: textField
        visible: false
        focus: root.isKeypadOpen && root.lockScreenState.isKeyboardMode
        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhSensitiveData
        onFocusChanged: if (focus) Keyboards.KWinVirtualKeyboard.active = true

        property bool externalEdit: false
        property string prevText: ""

        Connections {
            target: root.lockScreenState
            function onPasswordChanged() {
                if (textField.text != root.lockScreenState.password) {
                    textField.externalEdit = true;
                    textField.text = root.lockScreenState.password;
                }
            }
        }

        onEditingFinished: if (textField.focus) root.enter()
        onTextChanged: {
            if (!externalEdit) {
                if (prevText.length > text.length) {
                    for (let i = 0; i < (prevText.length - text.length); i++) root.backspace();
                } else if (text.length > 0) {
                    root.keyPress(text.charAt(text.length - 1));
                }
            }
            prevText = text;
            externalEdit = false;
        }
    }

    SequentialAnimation {
        id: wrongPinShakeAnim
        NumberAnimation { target: root; property: "shakeOffset"; to: -14; duration: 48; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 14; duration: 64; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: -10; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 10; duration: 56; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: -5; duration: 48; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 5; duration: 44; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 40; easing.type: Easing.OutQuad }
        onFinished: {
            root.lockScreenState.resetPassword();
            root.isErrorState = false;
        }
    }

    Row {
        id: pinRingsRow
        anchors.centerIn: parent
        transform: Translate { x: root.shakeOffset }
        spacing: root.dotCount > 6 ? 12 : 16

        Repeater {
            model: root.dotCount
            delegate: Item {
                readonly property bool filled: index < root.lockScreenState.password.length
                width: 16
                height: 16

                // Sub-pixel centered, zero-clipping radial glow (matches image_t_jI75.png)
                Canvas {
                    anchors.centerIn: parent
                    width: 36
                    height: 36
                    opacity: filled ? 1.0 : 0.0
                    scale: filled ? 1.0 : 0.7
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var g = ctx.createRadialGradient(18, 18, 5.5, 18, 18, 17);
                        g.addColorStop(0.0, "rgba(255, 255, 255, 0.30)");
                        g.addColorStop(0.55, "rgba(255, 255, 255, 0.10)");
                        g.addColorStop(1.0, "rgba(255, 255, 255, 0.0)");
                        ctx.fillStyle = g;
                        ctx.beginPath();
                        ctx.arc(18, 18, 17, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }

                // Crisp circular ring / filled dot
                Rectangle {
                    anchors.centerIn: parent
                    width: 13
                    height: 13
                    radius: 6.5
                    color: filled ? (root.isErrorState ? "#FF5A5F" : "#FFFFFF") : "transparent"
                    border.width: 2.0
                    border.color: root.isErrorState ? "#FF5A5F" : "#FFFFFF"
                    scale: filled ? 1.10 : 1.0

                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack } }
                }
            }
        }
    }
}
