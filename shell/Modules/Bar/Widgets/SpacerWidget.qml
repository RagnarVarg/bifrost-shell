import QtQuick
import qs.Core

// Empty space; length from the entry's "size" (in spacing steps) or md.
BarWidget {
    bubble: false
    implicitWidth: entry.size ? Theme.space.md * entry.size : Theme.space.md
    implicitHeight: implicitWidth
}
