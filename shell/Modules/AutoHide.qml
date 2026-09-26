import QtQuick
import qs.Compositor
import qs.Core

// Shared auto-hide logic for the bar and the dock.
//   enabled       – hide at all (otherwise always revealed)
//   smart         – stay revealed while no window covers `area`
//   pointerInside – one continuous hover source for the whole band
//   pinned        – e.g. a panel or menu is open
// Hides wait `delayMs` (with a short floor) and never happen within settleMs
// of a reveal: input-mask changes lag the reveal and cause spurious leaves.
// Wayland also reports spurious leaves while the pointer rests on the
// surface, so before hiding, the controller asks the compositor where the
// pointer really is and stays revealed while it is inside `area` (or while
// the answer is unknown).
Item {
    id: ctl

    property bool enabled: false
    property bool smart: false
    property bool pointerInside: false
    property bool pinned: false
    property string screenName: ""
    property var area: null
    property int delayMs: 0
    // For surfaces that reserve space while shown: tiled windows count as
    // covering even though they have moved out of the way.
    property bool tiledCovers: false

    readonly property bool covered: enabled && smart && Compositor.windowsCover(screenName, area, tiledCovers)
    readonly property bool wantReveal: !enabled || pointerInside || pinned || (smart && !covered)
    property bool revealed: true
    property real revealedAt: 0
    readonly property int settleMs: Theme.motion.duration.slow * 2

    visible: false

    onWantRevealChanged: {
        if (wantReveal) {
            hideTimer.stop();
            revealed = true;
        } else {
            hideTimer.interval = Math.max(delayMs, Theme.motion.duration.normal);
            hideTimer.restart();
        }
    }
    onRevealedChanged: if (revealed)
        revealedAt = Date.now()

    // Window geometry is only polled while someone relies on it.
    readonly property bool watching: enabled && smart
    property bool retained: false

    onWatchingChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (retained)
        Compositor.releaseGeometry()

    function sync() {
        if (watching && !retained)
            Compositor.retainGeometry();
        else if (!watching && retained)
            Compositor.releaseGeometry();
        retained = watching;
    }

    Timer {
        id: hideTimer

        onTriggered: {
            if (ctl.wantReveal)
                return;
            const since = Date.now() - ctl.revealedAt;
            if (since < ctl.settleMs) {
                interval = ctl.settleMs - since;
                restart();
                return;
            }
            Compositor.pointerIn(ctl.screenName, ctl.area, inside => {
                if (ctl.wantReveal)
                    return;
                // Unknown (the query failed or timed out) counts as inside:
                // hiding under the pointer is worse than asking again.
                if (inside !== false) {
                    hideTimer.interval = Theme.motion.duration.slow;
                    hideTimer.restart();
                } else {
                    ctl.revealed = false;
                }
            });
        }
    }
}
