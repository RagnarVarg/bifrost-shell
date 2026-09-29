import QtQuick
import qs.Compat
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// Config location, environment, problems and global reset.
Flickable {
    id: page

    SettingsScroll { id: wheelScroll; flickable: page }

    property bool confirmReset: false
    readonly property var problems: Schema.errors.map(e => "Schema: " + e).concat(Config.loadError ? ["config.json: " + Config.loadError] : []).concat(Config.issues.map(i => i.message)).concat(Theme.issues.map(i => "Theme: " + i))

    contentHeight: column.implicitHeight + SettingsStyle.contentPadding * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    component InfoRow: Item {
        id: info

        property string label: ""
        property string value: ""

        width: parent.width
        height: Theme.control.height.md

        BText {
            anchors.verticalCenter: parent.verticalCenter
            x: Theme.space.xl
            text: info.label
            role: "label"
        }

        BText {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.xl
            width: parent.width * 0.62
            horizontalAlignment: Text.AlignRight
            text: info.value
            role: "mono"
            tone: "muted"
            elide: Text.ElideMiddle
        }
    }

    Timer {
        id: confirmTimeout

        interval: 5000
        onTriggered: page.confirmReset = false
    }

    Column {
        id: column

        x: SettingsStyle.contentPadding
        y: SettingsStyle.contentPadding
        width: Math.min(page.width - SettingsStyle.contentPadding * 2, SettingsStyle.pageMaxWidth)
        spacing: Theme.space.xl

        BText {
            text: I18n.tr("Data & diagnostics")
            role: "title"
            font.pixelSize: Theme.typography.title.size * SettingsStyle.titleScale
            width: parent.width
            wrapMode: Text.WordWrap
        }

        Rectangle {
            width: parent.width
            height: infoColumn.implicitHeight + Theme.space.sm * 2
            radius: Theme.radius.lg
            color: Theme.color.controlFill
            border.width: Theme.border.hairline
            border.color: Theme.color.hairline

            Column {
                id: infoColumn

                y: Theme.space.sm
                width: parent.width

                InfoRow {
                    label: I18n.tr("Config file")
                    value: Paths.configFile
                }

                InfoRow {
                    label: I18n.tr("Changed settings")
                    value: I18n.tr("%1 of %2").arg(Config.modifiedKeys("").length).arg(Schema.keys.length)
                }

                InfoRow {
                    label: "Preset"
                    value: Config.preset
                }

                InfoRow {
                    label: I18n.tr("Theme")
                    value: Theme.chainIds.join(" → ") + " · " + Theme.variant
                }

                InfoRow {
                    label: I18n.tr("Run mode")
                    value: RunMode.mode
                }

                InfoRow {
                    label: "Compositor"
                    value: Compositor.displayName + " " + Compositor.version + (Compositor.supported ? "" : " " + I18n.tr("(outside tested versions)"))
                }

                InfoRow {
                    label: "Shell"
                    value: ApplyState.shellRunning ? I18n.tr("running (pid %1)").arg(ApplyState.applied.pid) : I18n.tr("not running (changes apply when it starts)")
                }
            }
        }

        Row {
            spacing: Theme.space.md

            BButton {
                icon: "folder"
                text: I18n.tr("Open config folder")
                onClicked: Platform.launch(["xdg-open", Paths.configDir])
            }

            BButton {
                icon: "reset"
                variant: page.confirmReset ? "primary" : "secondary"
                text: page.confirmReset ? I18n.tr("Confirm: reset everything") : I18n.tr("Reset all settings")
                enabled: Config.modifiedKeys("").length > 0
                onClicked: {
                    if (page.confirmReset) {
                        Config.resetAll();
                        page.confirmReset = false;
                    } else {
                        page.confirmReset = true;
                        confirmTimeout.restart();
                    }
                }
            }
        }

        BText {
            text: page.problems.length ? I18n.tr("Problems") : I18n.tr("No problems found")
            role: "overline"
            tone: page.problems.length ? "warning" : "muted"
        }

        Repeater {
            model: page.problems

            delegate: Banner {
                required property string modelData

                tone: "warning"
                text: modelData
            }
        }

    }

    BScrollIndicator {
        interactive: true
        onDragStarted: wheelScroll.motion.stop()
        flickable: page
    }
}
