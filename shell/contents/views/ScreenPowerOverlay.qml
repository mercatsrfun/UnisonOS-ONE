// oh hey look i built a whole global wayland blackout curtain!! wow!!! so cool bro
import QtQuick
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.state as MobileShellState
import org.kde.plasma.private.mobileshell.dpmsplugin as DPMS
import org.kde.plasma.private.mobileshell.raiselockscreenplugin as RaiseLockscreenPlugin

Window {
    id: overlayWin

    // big chungus full screen geometry so kwin doesnt make us 0x0 invisible
    width: Screen.width > 0 ? Screen.width : 393
    height: Screen.height > 0 ? Screen.height : 852
    visible: true
    color: "transparent"

    LayerShell.Window.scope: "argon-power-overlay"
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight | LayerShell.Window.AnchorBottom
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    property real veilOpacity: 0.0
    property bool asleep: false
    property bool dpmsIsOff: false
    property bool settleGuard: false

    // ghosts pass right through when awake so apps dont get mad at us
    readonly property bool blockInput: asleep || sleepAnim.running
    onBlockInputChanged: MobileShell.ShellUtil.setInputTransparent(overlayWin, !blockInput)

    function ensureAboveLockscreen() {
        if (MobileShellState.LockscreenDBusClient.lockscreenActive) {
            raiseHelper.raiseOverlay();
        }
    }

    Component.onCompleted: {
        MobileShell.ShellUtil.setInputTransparent(overlayWin, true);
        raiseHelper.initializeOverlay(overlayWin);
        ensureAboveLockscreen();
    }

    RaiseLockscreenPlugin.RaiseLockscreen { id: raiseHelper }

    // ayo kscreenlocker just spawned?! jump back on top of its head immediately!!
    Connections {
        target: MobileShellState.LockscreenDBusClient
        function onLockscreenLocked() {
            overlayWin.ensureAboveLockscreen();
            reRaiseTimer.restart();
        }
        function onLockscreenActiveChanged() {
            overlayWin.ensureAboveLockscreen();
        }
    }

    // double tap that raise button 120ms later because wayland tokens love taking naps
    Timer {
        id: reRaiseTimer
        interval: 120; repeat: false
        onTriggered: overlayWin.ensureAboveLockscreen()
    }

    // tiny head-start timer so kscreenlocker spawns BEFORE qemu freezes scanout
    Timer {
        id: dpmsCutTimer
        interval: 140; repeat: false
        onTriggered: {
            overlayWin.ensureAboveLockscreen();
            dpmsControl.turnDpmsOff();
        }
    }

    Timer {
        id: settleTimer
        interval: 260; repeat: false
        onTriggered: {
            overlayWin.settleGuard = false;
            if (overlayWin.asleep && !overlayWin.dpmsIsOff) overlayWin.triggerWake();
        }
    }

    // nighty night fade to pitch black THEN pull the real dpms plug
    NumberAnimation {
        id: sleepAnim
        target: overlayWin; property: "veilOpacity"
        to: 1.0; duration: 200; easing.type: Easing.InOutQuad
        onFinished: {
            overlayWin.asleep = true;
            overlayWin.dpmsIsOff = true;
            overlayWin.settleGuard = true;
            settleTimer.restart();
            // give kscreenlocker 140ms head start under our pitch-black veil before cutting dpms!!
            MobileShellState.LockscreenDBusClient.lockScreen();
            dpmsCutTimer.restart();
        }
    }

    // chill for 75ms so kwin hands over the xdg token BEFORE fading out!! big brain move
    SequentialAnimation {
        id: wakeAnim
        PauseAnimation { duration: 115 }
        NumberAnimation {
            target: overlayWin; property: "veilOpacity"
            to: 0.0; duration: 240; easing.type: Easing.OutCubic
        }
    }

    function triggerSleep() {
        if (sleepAnim.running || overlayWin.asleep) return;
        wakeAnim.stop();
        overlayWin.asleep = true;
        overlayWin.settleGuard = true;
        ensureAboveLockscreen();
        sleepAnim.restart();
    }

    function triggerWake() {
        sleepAnim.stop();
        overlayWin.asleep = false;
        overlayWin.dpmsIsOff = false;
        if (MobileShellState.ShellDBusClient.panelState === "argon_sleep") {
            MobileShellState.ShellDBusClient.panelState = "default";
        }
        overlayWin.veilOpacity = 1.0;
        ensureAboveLockscreen();
        wakeAnim.restart();
    }

    Connections {
        target: MobileShellState.ShellDBusClient
        function onPanelStateChanged() {
            if (MobileShellState.ShellDBusClient.panelState === "argon_sleep") overlayWin.triggerSleep();
            else if (overlayWin.asleep) overlayWin.triggerWake();
        }
    }

    DPMS.DPMSUtil {
        id: dpmsControl
        onDpmsTurnedOff: (screen) => {
            overlayWin.dpmsIsOff = true;
            overlayWin.asleep = true;
            overlayWin.veilOpacity = 1.0;
        }
        onDpmsTurnedOn: (screen) => {
            overlayWin.dpmsIsOff = false;
            if (!overlayWin.settleGuard) overlayWin.triggerWake();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: overlayWin.veilOpacity
        visible: opacity > 0.002

        // yo did a mouse molecule just twitch?? WAKE UP BRO!!
        MouseArea {
            anchors.fill: parent
            enabled: overlayWin.blockInput
            hoverEnabled: true
            property real lx: -1; property real ly: -1
            onEnabledChanged: { lx = -1; ly = -1; }
            onPressed: if (!overlayWin.settleGuard && !sleepAnim.running) overlayWin.triggerWake()
            onPositionChanged: (m) => {
                if (overlayWin.settleGuard || sleepAnim.running) { lx = m.x; ly = m.y; return; }
                if (lx < 0) { lx = m.x; ly = m.y; return; }
                if (Math.abs(m.x - lx) > 2 || Math.abs(m.y - ly) > 2) overlayWin.triggerWake();
            }
        }
    }
}
