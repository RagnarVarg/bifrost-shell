import QtQuick
import qs.Compat
import qs.Core
import qs.Components.Icons

// Reuse the same screenshot action as Print: select, save, and copy.
BarWidget {
    implicitWidth:button.implicitWidth
    BarButton {
        id:button
        anchors.fill:parent
        padding:Theme.space.sm
        onClicked:Platform.launch(["bash",Paths.repoDir+"/bin/bifrost-screenshot","region"],{appId:"bifrost-screenshot"})
        BIcon { name:"camera"; size:Theme.icon.size.md; color:Theme.color.text }
    }
}
