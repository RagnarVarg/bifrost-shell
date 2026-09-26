import QtQuick
import qs.Core

// Base for bar widgets: `entry` is the widget's object from bar.widgets
// (id + optional props), `bar` the BarWindow it lives in.
Item {
    property var entry: ({})
    property var bar: null
    // Whether the widget has something to show. Widgets set this instead of
    // `visible` (effective visibility would loop through the host).
    property bool shown: true
    // Part of the system status group (Boxed/Integrated appearance, shared
    // hover details and click action, drawn by the zone).
    property bool statusGroup: false
    // Boxed bar: whether this widget gets its own glass bubble.
    property bool bubble: true
    // On a side bar the widget stands upright, as wide as the bar is thick
    // (WidgetHost). Widgets lay their content out for it (BarRow) and give
    // their size along the bar as implicitHeight; square by default.
    readonly property bool vertical: bar ? bar.vertical === true : false
    readonly property real length: vertical ? implicitHeight : implicitWidth

    implicitHeight: implicitWidth
    height: parent ? parent.height : Theme.control.height.md
}
