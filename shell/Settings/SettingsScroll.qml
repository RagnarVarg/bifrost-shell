import QtQuick
import qs.Core

// Mouse notches accumulate into a smooth destination. Pixel scrolling remains
// immediate, including momentum events and direction changes.
WheelHandler {
    id: handler
    required property Flickable flickable
    target: null
    acceptedDevices: PointerDevice.Mouse
    function preciseScroll(delta) {
        if (!flickable || !delta) return;
        motion.stop();
        flickable.cancelFlick();
        flickable.contentY=Math.max(flickable.originY,Math.min(flickable.originY+Math.max(0,flickable.contentHeight-flickable.height),flickable.contentY-delta*Theme.control.settingsScroll.pixelMultiplier));
    }
    property WheelHandler trackpadWheel: WheelHandler {
        parent: handler.parent
        target: null
        acceptedDevices: PointerDevice.TouchPad
        onWheel: event => {
            const delta=event.pixelDelta.y || event.angleDelta.y/8;
            if (!delta) {event.accepted=false;return;}
            handler.preciseScroll(delta);
            event.accepted=true;
        }
    }
    property real destination: 0
    property real lastDelta: 0
    property NumberAnimation motion: NumberAnimation {
        target: handler.flickable
        property: "contentY"
        duration: Theme.motion.duration.fast
        easing.type: Easing.OutCubic
    }
    onWheel: event => {
        if (!flickable || (event.pixelDelta.y === 0 && event.angleDelta.y === 0)) {
            motion.stop();
            event.accepted = false;
            return;
        }
        if (event.pixelDelta.y !== 0) {
            preciseScroll(event.pixelDelta.y);
            event.accepted=true;
            return;
        }
        const delta=-event.angleDelta.y/120*Theme.control.height.lg*Theme.control.settingsScroll.rowsPerNotch;
        const previous=motion.running && delta*lastDelta>0 ? destination : flickable.contentY;
        motion.stop();
        flickable.cancelFlick();
        destination=Math.max(flickable.originY,Math.min(flickable.originY+Math.max(0,flickable.contentHeight-flickable.height),previous+delta));
        lastDelta=delta;
        if (Theme.motion.enabled) {
            motion.from=flickable.contentY;
            motion.to=destination;
            motion.start();
        } else flickable.contentY=destination;
        event.accepted=true;
    }
}
