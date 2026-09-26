import QtQuick
import qs.Core

// HSV colour picker: a saturation/value field and a hue strip.
// `color` is the current colour; `picked(hex)` fires while dragging, so the
// owner can preview live.
Item {
    id: picker

    property color color: Theme.color.accent

    signal picked(string hex)

    // Kept separately so the hue survives grey (s = 0) and black (v = 0).
    property real hue: 0
    property real sat: 0
    property real val: 0
    readonly property bool dragging: fieldMouse.pressed || stripMouse.pressed

    function sync() {
        if (dragging)
            return;
        if (color.hsvSaturation > 0 && color.hsvValue > 0)
            hue = Math.max(0, color.hsvHue);
        sat = color.hsvSaturation;
        val = color.hsvValue;
    }

    function hex(c) {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase();
    }

    function emitPick() {
        picked(hex(Qt.hsva(hue, sat, val, 1)));
    }

    onColorChanged: sync()
    Component.onCompleted: sync()

    implicitWidth: Theme.layout.editorWidth
    implicitHeight: fieldBox.height + Theme.space.md + stripBox.height

    // Saturation grows to the right, value upward.
    Rectangle {
        id: fieldBox

        width: parent.width
        height: Math.round(width * 0.55)
        radius: Theme.radius.md
        color: Qt.hsva(picker.hue, 1, 1, 1)
        border.width: Theme.border.hairline
        border.color: Theme.color.innerBorder

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Qt.hsva(0, 0, 1, 1)
                }

                GradientStop {
                    position: 1
                    color: Qt.hsva(0, 0, 1, 0)
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.hsva(0, 0, 0, 0)
                }

                GradientStop {
                    position: 1
                    color: Qt.hsva(0, 0, 0, 1)
                }
            }
        }

        Rectangle {
            x: picker.sat * parent.width - width / 2
            y: (1 - picker.val) * parent.height - height / 2
            width: Theme.control.slider.knob
            height: width
            radius: width / 2
            color: Qt.hsva(picker.hue, picker.sat, picker.val, 1)
            border.width: Theme.border.thick
            border.color: Theme.color.text
        }

        MouseArea {
            id: fieldMouse

            function at(m) {
                picker.sat = Math.max(0, Math.min(1, m.x / width));
                picker.val = Math.max(0, Math.min(1, 1 - m.y / height));
                picker.emitPick();
            }

            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            onPressed: m => at(m)
            onPositionChanged: m => {
                if (pressed)
                    at(m);
            }
        }
    }

    Rectangle {
        id: stripBox

        anchors.top: fieldBox.bottom
        anchors.topMargin: Theme.space.md
        width: parent.width
        height: Math.round(Theme.control.slider.height * 0.75)
        radius: height / 2
        border.width: Theme.border.hairline
        border.color: Theme.color.innerBorder
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: Qt.hsva(0, 1, 1, 1)
            }

            GradientStop {
                position: 1 / 6
                color: Qt.hsva(1 / 6, 1, 1, 1)
            }

            GradientStop {
                position: 2 / 6
                color: Qt.hsva(2 / 6, 1, 1, 1)
            }

            GradientStop {
                position: 3 / 6
                color: Qt.hsva(3 / 6, 1, 1, 1)
            }

            GradientStop {
                position: 4 / 6
                color: Qt.hsva(4 / 6, 1, 1, 1)
            }

            GradientStop {
                position: 5 / 6
                color: Qt.hsva(5 / 6, 1, 1, 1)
            }

            GradientStop {
                position: 1
                color: Qt.hsva(0.9999, 1, 1, 1)
            }
        }

        Rectangle {
            x: picker.hue * parent.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.control.slider.knob
            height: width
            radius: width / 2
            color: Qt.hsva(picker.hue, 1, 1, 1)
            border.width: Theme.border.thick
            border.color: Theme.color.text
        }

        MouseArea {
            id: stripMouse

            function at(m) {
                picker.hue = Math.max(0, Math.min(0.9999, m.x / stripBox.width));
                picker.emitPick();
            }

            anchors.fill: parent
            anchors.topMargin: -Theme.space.xs
            anchors.bottomMargin: -Theme.space.xs
            cursorShape: Qt.PointingHandCursor
            onPressed: m => at(m)
            onPositionChanged: m => {
                if (pressed)
                    at(m);
            }
        }
    }
}
