import QtQuick
import qs.Core
import qs.Components.Text

// Every typography role from Theme.typography.
GallerySection {
    title: "Typografi"
    subtitle: "Geist för gränssnittet, Geist Mono för teknisk information. Roller och storlekar kommer från tokens och skalas av textstorleken."

    Column {
        width: parent.width
        spacing: Theme.space.lg

        Repeater {
            model: [
                { role: "display", text: "Bifrost" },
                { role: "title", text: "Kontrollcenter" },
                { role: "heading", text: "Nätverk och anslutningar" },
                { role: "body", text: "Bron mellan världarna bärs av ljus och glas. Brödtext ska vara lugn och läsbar." },
                { role: "label", text: "Visa sekunder i klockan" },
                { role: "caption", text: "Ändringen gäller direkt för alla skärmar." },
                { role: "overline", text: "Utseende" },
                { role: "mono", text: "CPU 12 %  ·  RAM 7,4 / 32 GB  ·  Hyprland 0.56.2" },
                { role: "readout", text: "21:47  ·  48 °C" }
            ]

            delegate: Row {
                id: line

                required property var modelData
                readonly property var spec: Theme.typography[modelData.role]

                spacing: Theme.space.xl

                BText {
                    width: Theme.space.xxxl * 4
                    text: line.modelData.role + "\n" + line.spec.size + " px · " + line.spec.weight
                    role: "mono"
                    tone: "faint"
                    anchors.verticalCenter: parent.verticalCenter
                }

                BText {
                    text: line.modelData.text
                    role: line.modelData.role
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Row {
            spacing: Theme.space.xl

            Repeater {
                model: ["primary", "muted", "faint", "accent", "success", "warning", "danger"]

                delegate: BText {
                    required property string modelData

                    text: modelData
                    tone: modelData
                    role: "label"
                }
            }
        }
    }
}
