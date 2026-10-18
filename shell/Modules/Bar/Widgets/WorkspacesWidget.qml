import QtQuick
import qs.Compositor
import qs.Core
import qs.Components.Motion
import qs.Components.State
import qs.Components.Text

// Workspace pills. Active = prism; occupied vs empty by text tone. Hovering a
// pill opens its preview (WorkspacePreview, workspaces.preview); moving along
// the pills switches the preview to the one under the pointer.
BarWidget {
    id: widget

    readonly property var cfg: Config.values.workspaces
    readonly property string monitor: bar ? bar.modelData.name : ""
    readonly property var runes: ["ᚠ", "ᚢ", "ᚦ", "ᚨ", "ᚱ", "ᚲ", "ᚷ", "ᚹ", "ᚺ", "ᚾ", "ᛁ", "ᛃ", "ᛇ", "ᛈ", "ᛉ", "ᛊ", "ᛏ", "ᛒ", "ᛖ", "ᛗ", "ᛚ", "ᛜ", "ᛞ", "ᛟ"]
    readonly property var entries: {
        const mine = Compositor.workspaces.filter(w => !w.special && (!cfg.perMonitor || w.monitor === monitor));
        const out = [];
        for (let i = 1; i <= cfg.persistent; i++) {
            const w = mine.find(x => x.id === i);
            out.push(w || { id: i, name: String(i), active: false, focused: false, windowCount: 0, urgent: false });
        }
        for (const w of mine)
            if (w.id > cfg.persistent && (cfg.showEmpty || w.windowCount > 0 || w.active))
                out.push(w);
        return out.sort((a, b) => a.id - b.id);
    }

    // The pill under the pointer (-1: none) and the workspace last shown.
    property var hoveredId: -1
    property var previewed: null

    shown: Compositor.supports("workspaces")
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    function label(w) {
        if (cfg.labels === "runes")
            return w.id >= 1 && w.id <= runes.length ? runes[w.id - 1] : String(w.id);
        return w.name && isNaN(Number(w.name)) ? w.name : String(w.id);
    }

    // The preview's anchor: the whole row, hovered while any pill is.
    Item {
        id: previewAnchor

        readonly property bool hovered: widget.hoveredId !== -1

        anchors.fill: row
    }

    WorkspacePreview {
        bar: widget.bar
        anchorItem: previewAnchor
        workspace: widget.previewed
        monitorName: widget.monitor
    }

    BarRow {
        id: row

        anchors.centerIn: parent
        vertical: widget.vertical
        spacing: Theme.space.xxs

        Repeater {
            model: widget.entries

            delegate: Item {
                id: pill

                required property var modelData
                readonly property bool isActive: modelData.active === true
                readonly property bool occupied: modelData.windowCount > 0

                // The active pill is longer, along the bar.
                readonly property real length: isActive ? Theme.control.height.sm * 1.8 : Theme.control.height.sm

                width: widget.vertical ? Theme.control.height.sm : length
                height: widget.vertical ? length : Theme.control.height.sm

                Behavior on width {
                    BNumberAnimation {
                        speed: "normal"
                        curve: "emphasized"
                    }
                }

                Behavior on height {
                    BNumberAnimation {
                        speed: "normal"
                        curve: "emphasized"
                    }
                }

                StateLayer {
                    anchors.fill: parent
                    radius: Math.min(width, height) / 2
                    active: pill.isActive
                    hovered: mouse.containsMouse
                    pressed: mouse.pressed
                }

                // "dots" style
                Rectangle {
                    visible: widget.cfg.labels === "dots"
                    anchors.centerIn: parent
                    width: pill.isActive ? Theme.space.md : Theme.space.sm
                    height: width
                    radius: width / 2
                    color: pill.isActive ? Theme.color.text : pill.occupied ? Theme.color.textMuted : Theme.color.textFaint
                }

                BText {
                    visible: widget.cfg.labels !== "dots"
                    anchors.centerIn: parent
                    text: widget.label(pill.modelData)
                    role: "label"
                    font.family: widget.cfg.labels === "runes" ? Theme.font.runic : Theme.typography.label.family
                    tone: pill.isActive ? "primary" : pill.modelData.urgent ? "warning" : pill.occupied ? "muted" : "faint"
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Compositor.focusWorkspace(pill.modelData.id)
                    onContainsMouseChanged: {
                        if (containsMouse) {
                            widget.hoveredId = pill.modelData.id;
                            widget.previewed = pill.modelData;
                        } else if (widget.hoveredId === pill.modelData.id) {
                            widget.hoveredId = -1;
                        }
                    }
                }
            }
        }
    }
}
