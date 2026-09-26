import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// Light / Dark / System / Automatic, with what the mode does right now:
// the current variant and, for Automatic, the next sunrise or sunset and
// where the location comes from.
EditorBase {
    id: editor

    function time(d) {
        return d ? Qt.formatTime(d, Qt.locale().timeFormat(Locale.ShortFormat)) : "–";
    }

    readonly property string status: {
        const variant = ThemeMode.variant === "light" ? I18n.tr("Light") : I18n.tr("Dark");
        if (ThemeMode.mode === "system")
            return I18n.tr("Now %1, from the system preference").arg(variant);
        if (ThemeMode.mode !== "auto")
            return "";
        if (!ThemeMode.autoAvailable)
            return I18n.tr("No location known: follows the system preference (now %1)").arg(variant);
        const where = ThemeMode.locationSource === "manual" ? I18n.tr("your coordinates") : I18n.tr("time zone %1").arg(ThemeMode.location.zone);
        if (ThemeMode.polar)
            return I18n.tr("Now %1 (polar %2), location from %3").arg(variant).arg(ThemeMode.polar).arg(where);
        return I18n.tr("Now %1 · sunrise %2, sunset %3 · location from %4").arg(variant).arg(time(ThemeMode.sunrise)).arg(time(ThemeMode.sunset)).arg(where);
    }

    implicitWidth: seg.implicitWidth
    implicitHeight: seg.height + (status ? Theme.space.xs + info.implicitHeight : 0)

    BSegmented {
        id: seg

        anchors.right: parent.right
        width: Math.min(parent.width, implicitWidth)
        model: (editor.def.options || []).map(o => Schema.optionLabel(editor.key, o))
        currentIndex: (editor.def.options || []).indexOf(editor.value)
        onActivated: i => editor.set(editor.def.options[i])
    }

    BText {
        id: info

        anchors.top: seg.bottom
        anchors.topMargin: Theme.space.xs
        anchors.right: parent.right
        width: parent.width
        horizontalAlignment: Text.AlignRight
        wrapMode: Text.Wrap
        visible: editor.status !== ""
        text: editor.status
        role: "caption"
        tone: "muted"
    }
}
