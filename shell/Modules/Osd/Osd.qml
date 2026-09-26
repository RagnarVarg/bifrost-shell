import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Compositor
import qs.Core
import qs.Components.Glass
import qs.Components.Icons
import qs.Components.Motion
import qs.Components.Text
import qs.Modules
import qs.Services

// Volume / microphone / brightness OSD on the focused screen, and feedback
// for media keys (action + track). Click-through (empty mask).
Scope {
    Connections {
        target: Audio

        function onChanged() {
            ShellState.showOsd("volume", Audio.volume, Audio.muted);
        }

        // Muting the microphone from anywhere (key, control center, another
        // app); not its volume, which apps' gain control moves by itself.
        function onMicMutedChanged() {
            if (Audio.settled)
                ShellState.showOsd("mic", Audio.micVolume, Audio.micMuted);
        }
    }

    Connections {
        target: Brightness

        function onChanged() {
            ShellState.showOsd("brightness", Brightness.value, false);
        }
    }

    PanelWindow {
        id: window

        readonly property string position: Config.values.osd.position
        readonly property real edgeMargin: Theme.space.xxxl * 3
        readonly property string kind: ShellState.osdKind
        readonly property bool media: kind === "media"

        function iconName(): string {
            if (media)
                return ({ next: "next", previous: "previous", stop: "stop" })[ShellState.osdAction] || (Media.playing ? "play" : "pause");
            if (kind === "brightness")
                return "sun";
            if (kind === "mic")
                return ShellState.osdMuted ? "mic-off" : "mic";
            return ShellState.osdMuted || ShellState.osdValue === 0 ? "volume-off" : "volume";
        }

        screen: Quickshell.screens.find(s => s.name === ShellState.focusedScreen()) || Quickshell.screens[0]
        visible: ShellState.osdVisible || glass.opacity > 0
        color: "transparent"
        WlrLayershell.namespace: RunMode.layerNamespace("osd")
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}

        anchors.top: position === "top"
        anchors.bottom: position === "bottom"
        margins.top: position === "top" ? edgeMargin : 0
        margins.bottom: position === "bottom" ? edgeMargin : 0
        implicitWidth: Theme.layout.osdWidth + glass.shadowExtent * 2
        implicitHeight: Theme.control.height.lg + Theme.space.lg * 2 + glass.shadowExtent * 2

        GlassSurface {
            id: glass

            material: Theme.materials.osd
            x: shadowExtent
            y: shadowExtent + (ShellState.osdVisible ? 0 : Theme.space.md)
            width: Theme.layout.osdWidth
            height: Theme.control.height.lg + Theme.space.lg * 2
            opacity: ShellState.osdVisible ? 1 : 0

            Behavior on opacity {
                BNumberAnimation {}
            }

            Behavior on y {
                BNumberAnimation {
                    curve: "decelerate"
                }
            }

            BIcon {
                id: icon

                anchors.left: parent.left
                anchors.leftMargin: Theme.space.xl
                anchors.verticalCenter: parent.verticalCenter
                name: window.iconName()
                size: Theme.icon.size.lg
                color: Theme.color.text
            }

            Column {
                visible: window.media
                anchors.left: icon.right
                anchors.leftMargin: Theme.space.lg
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.xl
                anchors.verticalCenter: parent.verticalCenter

                BText {
                    width: parent.width
                    text: Media.title
                    role: "label"
                    elide: Text.ElideRight
                }

                BText {
                    width: parent.width
                    visible: text !== ""
                    text: Media.artist
                    role: "caption"
                    tone: "muted"
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: track

                visible: !window.media
                anchors.left: icon.right
                anchors.leftMargin: Theme.space.lg
                anchors.right: readout.left
                anchors.rightMargin: Theme.space.lg
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.control.slider.track * 1.5
                radius: height / 2
                color: Theme.color.track

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, ShellState.osdValue))
                    height: parent.height
                    radius: parent.radius
                    color: ShellState.osdMuted ? Theme.color.textFaint : Theme.color.trackActive

                    Behavior on width {
                        BNumberAnimation {}
                    }
                }
            }

            BText {
                id: readout

                visible: !window.media
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.xl
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.space.xxxl * 1.5
                horizontalAlignment: Text.AlignRight
                text: ShellState.osdMuted ? "–" : Math.round(ShellState.osdValue * 100)
                role: "readout"
                tone: ShellState.osdMuted ? "faint" : "primary"
            }
        }
    }
}
