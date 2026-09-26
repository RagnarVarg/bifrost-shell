import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// Slider with a numeric readout, or a number field (schema "input": "field",
// e.g. coordinates). Nullable settings show the inherited theme value while
// null and offer a chip to return to it (text from schema "nullLabel").
EditorBase {
    id: editor

    readonly property bool isNull: value === null || value === undefined
    readonly property real shown: isNull ? Number(inherited() || def.min || 0) : value
    readonly property real step: def.step || (def.type === "int" ? 1 : 0.01)
    readonly property int decimals: def.type === "int" ? 0 : Math.max(0, Math.ceil(-Math.log10(step) - 1e-9))
    readonly property bool asField: def.input === "field"

    implicitHeight: Theme.control.height.md

    BChip {
        id: themeChip

        visible: editor.def.nullable === true && !editor.asField
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: editor.def.nullLabel ? I18n.tr(editor.def.nullLabel) : I18n.tr("Theme")
        selected: editor.isNull
        onClicked: editor.set(null)
    }

    BTextField {
        visible: editor.asField
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.space.xxxl * 4
        text: editor.isNull ? "" : Number(editor.value).toFixed(editor.decimals)
        placeholder: editor.isNull && editor.def.nullLabel ? I18n.tr(editor.def.nullLabel) : ""
        onAccepted: t => {
            const v = Number(String(t).replace(",", "."));
            if (t === "")
                editor.set(null);
            else if (!isNaN(v))
                editor.set(Math.max(editor.def.min, Math.min(editor.def.max, v)));
        }
    }

    BSlider {
        visible: !editor.asField
        anchors.left: themeChip.visible ? themeChip.right : parent.left
        anchors.leftMargin: themeChip.visible ? Theme.space.md : 0
        anchors.right: readout.left
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        from: editor.def.min !== undefined ? editor.def.min : 0
        to: editor.def.max !== undefined ? editor.def.max : 100
        stepSize: editor.step
        value: editor.shown
        opacity: editor.isNull ? Theme.opacity.disabled + (1 - Theme.opacity.disabled) / 2 : 1
        onMoved: v => editor.set(v)
    }

    BText {
        id: readout

        visible: !editor.asField
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.space.xxxl * 2
        horizontalAlignment: Text.AlignRight
        role: "mono"
        tone: editor.isNull ? "faint" : "muted"
        text: Number(editor.shown).toFixed(editor.decimals) + (editor.def.unit ? " " + editor.def.unit : "")
    }
}
