// SPDX-FileCopyrightText: 2019 Nicolas Fella <nicolas.fella@gmx.de>
// SPDX-FileCopyrightText: 2021-2024 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.notificationmanager as Notifications
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.state as MobileShellState
import org.kde.plasma.private.mobileshell.dpmsplugin as DPMS
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings

import org.kde.kirigami as Kirigami

/**
 * Lockscreen component that is loaded after the device is locked.
 *
 * Special attention must be paid to ensuring the GUI loads as fast as possible.
 */
Item {
    id: root
    // Argon Hardware Failsafe: Hold Volume Down for 3 seconds
    property int volumeHoldCount: 0
    Timer {
        id: volumeHoldTimer
        interval: 100; repeat: true; running: false
        onTriggered: {
            volumeHoldCount++;
            if (volumeHoldCount >= 30) { // 3 seconds
                root.safeMode = true;
                running = false;
                console.log("ARGON: Hardware Failsafe Triggered!");
            }
        }
    }
    // Argon Failsafe: hold Volume Up or create /tmp/argon_safe to bypass UI
    property bool safeMode: false
    Timer {
        id: failsafeTimer; interval: 500; running: true; repeat: true
        onTriggered: {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "file:///tmp/argon_safe");
            xhr.onreadystatechange = function() { if (xhr.readyState === 4) root.safeMode = (xhr.status === 200); }
            xhr.send();
        }
    }

    readonly property var lockScreenState: LockScreenState {}
    readonly property var notifModel: Notifications.WatchedNotificationsModel {}

    // Only show widescreen mode for short height devices (ex. phone landscape)
    readonly property bool isWidescreen: root.height < Kirigami.Units.gridUnit * 25 && (root.height < root.width * 0.75)
    property bool notificationsShown: false

    property var passwordBar: flickable.passwordBar

    // Wake-up fade-in + subtle outward expansion (scale 0.96 -> 1.0, opacity 0.0 -> 1.0)
    ParallelAnimation {
        id: wakeExpandAnim
        NumberAnimation {
            target: lockscreenContainer
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 420
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: lockscreenContainer
            property: "scale"
            from: 0.96
            to: 1.0
            duration: 420
            easing.type: Easing.OutCubic
        }
    }

    property real screenPowerT: 1.0

    function sleepScreen() {
        MobileShellState.ShellDBusClient.panelState = "argon_sleep";
    }

    Component.onCompleted: {
        forceActiveFocus();
    }

    // Listen for keyboard events, and focus on input area
    Keys.onReleased: (event) => { if (event.key === Qt.Key_VolumeDown) { volumeHoldTimer.stop(); volumeHoldCount = 0; } }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_VolumeDown) { volumeHoldTimer.start(); }

        root.lockScreenState.isKeyboardMode = true;
        flickable.goToOpenPosition();
        passwordBar.textField.forceActiveFocus();

        passwordBar.keyPress(event.text);
    }

    Connections {
        target: MobileShellState.ShellDBusClient

        function onOpenLockScreenKeypadRequested() {
            flickable.goToOpenPosition();
        }
    }

    // Wallpaper blur
    Loader {
        id: wallpaperLoader
        anchors.fill: parent
        active: false
        asynchronous: true

        // This take a while to load, don't pause initial lockscreen loading for it
        Timer {
            running: true
            repeat: false
            onTriggered: wallpaperLoader.active = true
        }

        sourceComponent: WallpaperBlur {
            source: wallpaper
            opacity: Math.min(1.0, flickable.openFactor * 2.2)
        }
    }

    Connections {
        target: root.lockScreenState

        // Ensure keypad is opened when password is updated (ex. keyboard)
        function onPasswordChanged() {
            if (root.lockScreenState.password !== "") {
                flickable.goToOpenPosition();
            }
        }
    }

    // when screen turns off, reset state
    // yo start pitch black at 1.0 on cold boot so late-loading kscreenlocker NEVER flashbangs us bro!!
    Rectangle {
        id: localLockWakeGuard
        anchors.fill: parent
        z: 9997
        color: "#000000"
        opacity: 1.0
        visible: opacity > 0.002
    }

    SequentialAnimation {
        id: localLockWakeAnim
        PauseAnimation { duration: 55 }
        NumberAnimation {
            target: localLockWakeGuard; property: "opacity"
            to: 0.0; duration: 240; easing.type: Easing.OutCubic
        }
    }

    Connections {
        target: MobileShellState.ShellDBusClient
        function onPanelStateChanged() {
            if (MobileShellState.ShellDBusClient.panelState === "argon_sleep") {
                localLockWakeAnim.stop();
                localLockWakeGuard.opacity = 1.0;
            } else {
                localLockWakeAnim.restart();
            }
        }
    }

    Timer {
        id: initialBootFadeTimer
        interval: 90; running: true; repeat: false
        onTriggered: {
            if (MobileShellState.ShellDBusClient.panelState !== "argon_sleep") {
                localLockWakeAnim.restart();
            }
        }
    }

    DPMS.DPMSUtil {
        id: dpms
        onDpmsTurnedOff: (screen) => {
            if (screen.name === Screen.name) {
                localLockWakeAnim.stop();
                localLockWakeGuard.opacity = 1.0;
                flickable.goToClosePosition();
                lockScreenState.resetPassword();
            }
        }
        onDpmsTurnedOn: (screen) => {
            if (screen.name === Screen.name && MobileShellState.ShellDBusClient.panelState !== "argon_sleep") {
                localLockWakeAnim.restart();
            }
        }
    }

    // Container for lockscreen contents
    Item {
        id: lockscreenContainer
        anchors.fill: parent
        z: 2

        FlickContainer {
            id: flickable
            anchors.fill: parent
            property alias passwordBar: keypad.passwordBar

            // Speed up animation when passwordless
            animationDuration: 420

            // Distance to swipe to fully open keypad
            keypadHeight: Kirigami.Units.gridUnit * 20

            Component.onCompleted: {
                // Go to closed position when loaded
                flickable.position = 0;
                flickable.goToClosePosition();
            }

            // Unlock lockscreen if it's already unlocked and keypad is opened
            onOpened: {
                if (root.lockScreenState.canBeUnlocked) {
                    Qt.quit();
                }
            }

            // Unlock lockscreen if it's already unlocked and keypad is open
            Connections {
                target: root.lockScreenState
                function onCanBeUnlockedChanged() {
                    if (root.lockScreenState.canBeUnlocked && flickable.openFactor > 0.8) {
                        Qt.quit();
                    }
                }
            }

            // Clear entered password after closing keypad
            onOpenFactorChanged: {
                if (flickable.openFactor < 0.1 && !flickable.movingUp) {
                    root.passwordBar.clear();
                }
            }

            // Figma swipe-up-to-unlock navigation pill (replaces old chevron)
            Rectangle {
                id: swipeUpHomeBar
                width: 134
                height: 5
                radius: 2.5
                color: Qt.rgba(1.0, 1.0, 1.0, 0.38)
                opacity: Math.max(0.0, 1.0 - flickable.openFactor * 2.4) * lockScreenContent.bottomPowerOpacity

                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10 + flickable.position * 0.14
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                id: keypadScrim
                anchors.fill: parent
                visible: opacity > 0
                opacity: flickable.openFactor
                color: Qt.rgba(0, 0, 0, 0.5)
            }

            MouseArea {
                // Disable "double tap to lock" to avoid accidental locking
                // when the keypad is open, and the user is typing their password.
                enabled: flickable.openFactor < 0.1
                anchors.fill: parent

                onDoubleClicked: (mouse) => {
                    root.sleepScreen();
                }

                MobileShell.DeviceLock {
                    id: deviceLock
                }
            }

            Keypad {
                id: keypad
                visible: !root.lockScreenState.canBeUnlocked // don't show for passwordless login
                anchors.fill: parent
                openProgress: flickable.openFactor
                swipeIntensity: flickable.velocityFactor
                lockScreenState: root.lockScreenState

                // opacity & blur controlled smoothly by Keypad.appearT
            }
        }

        LockScreenContent {
            visible: !root.safeMode
            id: lockScreenContent

            isVertical: !root.isWidescreen
            opacity: Math.max(0.0, 1.0 - flickable.openFactor * 2.1)
            width: parent.width
            height: parent.height
            y: -flickable.position * 0.85

            liveBgItem: wallpaper
            screenPowerT: root.screenPowerT
            lockScreenState: root.lockScreenState
            notificationsModel: root.notifModel
            onNotificationsShownChanged: root.notificationsShown = notificationsShown
            onPasswordRequested: flickable.goToOpenPosition()

            scrollLock: flickable.openFactor > 0.2
            z: scrollLock ? -1 : 0
        }
    }
}
