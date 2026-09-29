import QtQuick
import qs.Core
import qs.Modules

BarWidget {
    id: widget

    implicitWidth: button.implicitWidth

    BarButton {
        id: button

        anchors.fill: parent
        padding: Theme.space.sm
        implicitWidth: implicitHeight
        selected: menu.isOpen
        onClicked: menu.click()

        Canvas {
            id: rune
            width: 11
            height: 15
            anchors.centerIn: parent

            // Same colour as the other bar widgets (Text and icons, per
            // light/dark mode); redrawn when it changes.
            readonly property color color: Theme.color.text
            onColorChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()

                ctx.strokeStyle = rune.color
                ctx.lineWidth = 1.1
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                const x = width
                const y = height

                ctx.beginPath()

                // Stam
                ctx.moveTo(x * 0.22, y * 0.08)
                ctx.lineTo(x * 0.22, y * 0.92)

                // Övre Berkano-triangel
                ctx.moveTo(x * 0.22, y * 0.10)
                ctx.lineTo(x * 0.78, y * 0.28)
                ctx.lineTo(x * 0.22, y * 0.50)

                // Nedre Berkano-triangel
                ctx.moveTo(x * 0.22, y * 0.50)
                ctx.lineTo(x * 0.78, y * 0.70)
                ctx.lineTo(x * 0.22, y * 0.90)

                ctx.stroke()
            }
        }
    }

    SystemMenu {
        id: menu

        bar: widget.bar
        anchorItem: button
    }

    Connections {
        target: ShellState

        function onStatusMenuRequested(screen, name) {
            if (!name.startsWith("system") || !widget.bar || screen !== widget.bar.modelData.name)
                return;

            const page = name.split(":")[1] || "";

            if (!page) {
                menu.toggle();
                return;
            }

            menu.open();
            menu.openPage(page);
        }
    }
}
