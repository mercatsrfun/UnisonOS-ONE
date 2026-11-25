// yo we hijacked the whole OS lock button lmaooo sit tight dpms wait your turn bro
import QtQuick
import org.kde.plasma.private.mobileshell.dpmsplugin as DPMS
import org.kde.plasma.private.mobileshell.state as MobileShellState

QtObject {
    id: root

    // ayo sussy redirect straight into our smooth black fade boiii
    function triggerLock() {
        MobileShellState.ShellDBusClient.panelState = "argon_sleep";
    }

    // secret backdoor just in case somebody actually wants raw dpms smoke
    function triggerRawLockAndOff() {
        MobileShellState.LockscreenDBusClient.lockScreen();
        __dpms.turnDpmsOff();
    }

    property DPMS.DPMSUtil __dpms: DPMS.DPMSUtil {
        id: dpms
    }
}
