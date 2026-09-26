import QtQuick
import qs.Core

// Every material defined in Theme.materials, as-is.
GallerySection {
    title: "Material"
    subtitle: "Alla ytor i Bifrost använder ett av dessa material. Samma GlassSurface; bara materialet skiljer."

    Flow {
        width: parent.width
        spacing: Theme.space.xxxl

        Repeater {
            model: [
                { id: "bar", note: "Top bar" },
                { id: "dock", note: "Dock" },
                { id: "panel", note: "Control center, launcher, notiscenter, Settings" },
                { id: "popover", note: "Menyer och små popups" },
                { id: "osd", note: "Volym, ljusstyrka" },
                { id: "tooltip", note: "Tooltips, ingen blur" },
                { id: "lock", note: "Lock screen, mest transparent" }
            ]

            delegate: MaterialCard {
                required property var modelData

                material: Theme.materials[modelData.id]
                name: modelData.id
                note: modelData.note
            }
        }
    }
}
