// SPDX-FileCopyrightText: 2025 User8395 <therealuser8395@proton.me>
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import org.kde.plasma.quicksetting.flashlight
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.kirigami as Kirigami

AbstractButton {
    id: root
    Loader { id: wpPathLoader; source: "file:///home/jayjayc/.config/argon-wallpapers.qml" }

    property int buttonAction
    signal actionTriggered()
    property bool isRightButton: false
    property bool hideButton: false
    readonly property int effectiveAction: (effectiveAction !== ShellSettings.Settings.None)
        ? buttonAction
        : (isRightButton ? ShellSettings.Settings.Camera : ShellSettings.Settings.Flashlight)
    property bool localTorchFallback: false
    property real torchIntensity: 0.72
    property bool buttonHeld: false
    property real pressScale: pressed ? (buttonHeld ? 1.18 : 1.10) : 1.0
    property real fillAmount: 0.0

    readonly property bool isActivated: {
        if (effectiveAction === ShellSettings.Settings.Flashlight) {
            return localTorchFallback;
        }
        return pressed || buttonHeld;
    }

    Behavior on pressScale {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    MobileShell.HapticsEffect { id: haptics }

    visible: !hideButton && effectiveAction !== ShellSettings.Settings.None
    implicitWidth: 60
    implicitHeight: 60
    width: 60
    height: 60
    padding: 0

    transform: Scale {
        origin.x: width * 0.5
        origin.y: height * 0.5
        xScale: root.pressScale
        yScale: root.pressScale
    }

    // Activated Drop Shadow Glow: X: 0, Y: 0, Blur: 10, #FFFFFF 50% (image_SzND5O.png)
    Rectangle {
        anchors.centerIn: parent
        width: 62; height: 62; radius: 31
        color: Qt.rgba(1.0, 1.0, 1.0, 0.35)
        opacity: root.isActivated ? 1.0 : 0.0
        visible: opacity > 0.01
        z: -1
        Behavior on opacity { NumberAnimation { duration: 220 } }
        layer.enabled: true
        layer.effect: FastBlur { radius: 10; transparentBorder: true }
    }

    background: Item {
        width: 60; height: 60

        Rectangle {
            id: btnMask
            anchors.fill: parent
            radius: 30
            color: "#FFFFFF"
            visible: false
            layer.enabled: true
            layer.smooth: true
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            layer.effect: OpacityMask { maskSource: btnMask }

            // Uniform 30 Background Blur aligned to bottom-left / bottom-right button position
            Image {
                width: root.Window.width > 0 ? root.Window.width : 393
                height: root.Window.height > 0 ? root.Window.height : 852
                x: root.isRightButton ? -(width - 84) : -24
                y: -(height - 84)
                source: (wpPathLoader.item && wpPathLoader.item.lockUrl.length > 0) ? wpPathLoader.item.lockUrl : "file:///home/jayjayc/custom-wallpaper.png"
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 196; sourceSize.height: 426
                smooth: true
                layer.enabled: true; layer.effect: FastBlur { radius: 30 }
            }

            // #696969 40% Luminosity + #FFFFFF 20% Soft Light (brightens smoothly when activated)
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.412, 0.412, 0.412, root.isActivated ? 0.22 : 0.18)
            }
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(1.0, 1.0, 1.0, root.isActivated ? 0.13 : 0.08)
            }

            // Inner Shadow: X: 0, Y: 1, Blur: 4 (or 5 when activated), #FFFFFF 25% (image_rkYzWE.png)
            Item {
                anchors.fill: parent; clip: true
                Rectangle {
                    x: -1; y: 1.2
                    width: parent.width + 2; height: parent.height + 2; radius: 31
                    color: "transparent"
                    border.width: root.isActivated ? 2.4 : 2.0
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.25)
                    layer.enabled: true
                    layer.effect: FastBlur { radius: root.isActivated ? 5 : 4 }
                }
            }
        }

        // Inner Concentric 46x46 Circle (#FFFFFF 30% Soft Light, clean state transition without expanding inner circle)
        Rectangle {
            anchors.centerIn: parent
            width: 46; height: 46; radius: 23
            color: Qt.rgba(1.0, 1.0, 1.0, root.isActivated ? 0.15 : 0.08)
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    contentItem: Item {
        anchors.fill: parent

        // Custom Flashlight SVGs (dead-center in 60x60)
        Image {
            visible: root.effectiveAction === ShellSettings.Settings.Flashlight
            anchors.centerIn: parent
            width: 24; height: 24
            source: root.isActivated ? Qt.resolvedUrl("flashlight-activated.svg") : Qt.resolvedUrl("flashlight-unactivated.svg")
            sourceSize.width: 72; sourceSize.height: 72
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // Crisp native vector Camera icon (matches Figma image_vXkoqu.png)
        Canvas {
            visible: root.effectiveAction === ShellSettings.Settings.Camera
            anchors.centerIn: parent
            width: 24; height: 24
            property bool active: root.isActivated
            onActiveChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = active ? "#FFFFFF" : "rgba(255, 255, 255, 0.78)";
                ctx.lineWidth = 1.9;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.roundedRect(2.5, 6.8, 19, 13.2, 3.4, 3.4);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(7.8, 6.8);
                ctx.lineTo(9.3, 4.4);
                ctx.lineTo(14.7, 4.4);
                ctx.lineTo(16.2, 6.8);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(12, 13.4, 3.6, 0, Math.PI * 2, false);
                ctx.stroke();
            }
        }
    }

    onPressedChanged: {
        if (pressed) {
            pressedTimer.restart();
            buttonHeld = false;
            emptyAnimation.stop();
            fillAnimation.from = root.fillAmount;
            fillAnimation.start();
        } else {
            pressedTimer.stop();
            fillAnimation.stop();
            emptyAnimation.from = root.fillAmount;
            emptyAnimation.start();
        }
    }

    function setFlashlightEnabled(enabled) {
        if (effectiveAction !== ShellSettings.Settings.Flashlight) return;
        if (root.localTorchFallback !== enabled) {
            root.localTorchFallback = enabled;
            if (typeof FlashlightUtil !== "undefined" && FlashlightUtil.torchEnabled !== enabled) {
                FlashlightUtil.toggleTorch();
            }
        }
    }
    function triggerButtonAction() {
        switch (effectiveAction) {
            case ShellSettings.Settings.Flashlight:
                root.localTorchFallback = !root.localTorchFallback;
                if (typeof FlashlightUtil !== "undefined") FlashlightUtil.toggleTorch();
                return;
            case ShellSettings.Settings.Camera:
                root.actionTriggered();
                return;
        }
    }

    Timer {
        id: pressedTimer
        interval: 280
        repeat: false
        onTriggered: {
            haptics.buttonVibrate();
            buttonHeld = true;
            triggerButtonAction();
        }
    }

    PropertyAnimation { id: fillAnimation; target: root; property: "fillAmount"; duration: 280; to: 1.0 }
    PropertyAnimation { id: emptyAnimation; target: root; property: "fillAmount"; duration: 220; to: 0.0 }
}
