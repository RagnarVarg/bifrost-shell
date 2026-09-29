import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// Scrollable page with a title for custom (non-schema) Settings pages.
Flickable {
    id: page

    SettingsScroll { id: wheelScroll; flickable: page }

    property string title: ""
    default property alias content: column.data

    contentHeight: column.implicitHeight + SettingsStyle.contentPadding * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column

        x: SettingsStyle.contentPadding
        y: SettingsStyle.contentPadding
        width: Math.min(page.width - SettingsStyle.contentPadding * 2, SettingsStyle.pageMaxWidth)
        spacing: SettingsStyle.groupSpacing

        BText {
            text: page.title
            role: "title"
            font.pixelSize: Theme.typography.title.size * SettingsStyle.titleScale
            width: parent.width
            wrapMode: Text.WordWrap
        }
    }

    BScrollIndicator {
        interactive: true
        onDragStarted: wheelScroll.motion.stop()
        flickable: page
    }
}
