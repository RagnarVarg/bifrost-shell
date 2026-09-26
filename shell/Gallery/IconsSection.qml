import QtQuick
import Qt.labs.folderlistmodel
import qs.Core
import qs.Components.Icons
import qs.Components.Text

// Every icon in assets/icons, plus the Bifrost mark.
GallerySection {
    title: "Ikoner"
    subtitle: "Eget linjeset (24 px ritat, 1,5 px linje), färgat via tokens. Märket: ᛒ-runa under Bifrost-bågen."

    Row {
        width: parent.width
        spacing: Theme.space.xxxl

        Column {
            spacing: Theme.space.sm

            BIcon {
                source: "file://" + Paths.assetsDir + "/brand/bifrost-mark.svg"
                size: Theme.icon.size.xl * 3
                color: Theme.palette.silver
            }

            BText {
                text: "bifrost-mark"
                role: "mono"
                tone: "faint"
            }
        }

        Flow {
            width: parent.width - Theme.icon.size.xl * 3 - Theme.space.xxxl
            spacing: Theme.space.lg

            Repeater {
                model: FolderListModel {
                    folder: "file://" + Paths.assetsDir + "/icons"
                    nameFilters: ["*.svg"]
                    showDirs: false
                }

                delegate: Column {
                    id: cell

                    required property string fileBaseName

                    width: Theme.space.xxxl * 3
                    spacing: Theme.space.xs

                    BIcon {
                        name: cell.fileBaseName
                        size: Theme.icon.size.lg
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    BText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.fileBaseName
                        role: "mono"
                        tone: "faint"
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
