import QtQuick
import qs.Core

// A short, thin vertical divider with low opacity, centred in its parent's
// height. Place it with `x`.
Rectangle {
    width: Theme.effects.lineWidth ?? 1
    height: parent ? parent.height * (Theme.effects.dividerLength ?? 0.4) : 0
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    radius: width / 2
    color: Theme.alpha(Theme.effects.dividerColor || "white", Theme.effects.dividerOpacity ?? 0.14)
}
