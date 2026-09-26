import QtQuick
import qs.Core
import qs.Components.Motion

// Position indicator with an optional enlarged, draggable pointer target.
Item {
    id: bar
    property Flickable flickable: null
    property bool interactive: false
    signal dragStarted
    readonly property real ratio: flickable && flickable.contentHeight > 0 ? flickable.height / flickable.contentHeight : 1
    readonly property real range: flickable ? Math.max(0,flickable.contentHeight-flickable.height) : 0
    visible: ratio < 1
    parent: flickable
    anchors.right: parent ? parent.right : undefined
    width: interactive ? Theme.control.height.sm : Theme.space.xs
    height: flickable ? Math.min(flickable.height,Math.max(Theme.space.xxl,flickable.height*ratio)) : 0
    y: flickable ? (flickable.height-height)*Math.max(0,Math.min(1,(flickable.contentY-flickable.originY)/Math.max(1,range))) : 0
    z: 10
    Rectangle {
        anchors.right: parent.right
        height: parent.height
        width: mouse.containsMouse || mouse.pressed ? Theme.space.md : Theme.space.xs
        radius: width/2
        color: mouse.pressed ? Theme.color.accent : mouse.containsMouse ? Theme.color.textMuted : Theme.color.track
        Behavior on width { BNumberAnimation {} }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: bar.interactive
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.SizeVerCursor
        property real startPointer: 0
        property real startScroll: 0
        onPressed: event => {
            bar.dragStarted();
            bar.flickable.cancelFlick();
            startPointer=mapToItem(bar.flickable,event.x,event.y).y;
            startScroll=bar.flickable.contentY;
        }
        onPositionChanged: event => {
            if(!pressed)return;
            const dy=mapToItem(bar.flickable,event.x,event.y).y-startPointer;
            const origin=bar.flickable.originY;
            bar.flickable.contentY=Math.max(origin,Math.min(origin+bar.range,startScroll+dy*bar.range/Math.max(1,bar.flickable.height-bar.height)));
        }
    }
}
