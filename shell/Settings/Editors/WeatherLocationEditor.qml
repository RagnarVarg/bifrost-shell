import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text

EditorBase {
    id: editor
    wide: true
    implicitHeight: layout.implicitHeight
    property var results: []
    property var request: null
    property string message: ""
    function search() {
        if (request) { const old=request; request=null; old.abort(); }
        results = [];
        if (query.text.trim().length < 2) return;
        message = I18n.tr("Searching…");
        const xhr = new XMLHttpRequest(); request=xhr;
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || editor.request !== xhr) return;
            editor.request=null; timeout.stop();
            try {
                if (xhr.status !== 200) throw new Error("request");
                const data=JSON.parse(xhr.responseText);
                editor.results=(data.results || []).filter(r => typeof r.latitude === "number" && typeof r.longitude === "number").map(r => ({name:[r.name,r.admin1,r.country].filter(Boolean).join(", "),lat:r.latitude,lon:r.longitude,zone:r.timezone || ""}));
                editor.message=editor.results.length ? "" : I18n.tr("No locations found");
            } catch(e) { editor.message=I18n.tr("Location search unavailable. Try again."); }
        };
        xhr.open("GET","https://geocoding-api.open-meteo.com/v1/search?count=8&language=en&name="+encodeURIComponent(query.text.trim()));
        timeout.restart(); xhr.send();
    }
    Component.onDestruction: if (request) { const old=request; request=null; old.abort(); }
    Timer { id: timeout; interval: 10000; onTriggered: { if(editor.request) { const old=editor.request; editor.request=null; old.abort(); editor.message=I18n.tr("Location search unavailable. Try again."); } } }
    Column {
        id: layout
        width: parent.width
        spacing: Theme.space.sm
        BText { width: parent.width; text: editor.value && editor.value.name ? editor.value.name : I18n.tr("Automatic location"); role: "caption"; wrapMode: Text.Wrap }
        BTextField { id: query; width: parent.width; placeholder: I18n.tr("City or postal code"); onAccepted: editor.search() }
        Flow {
            width: parent.width
            spacing: Theme.space.sm
            BButton { text: I18n.tr("Search"); enabled: !editor.request && query.text.trim().length >= 2; onClicked: editor.search() }
            BButton { text: I18n.tr("Use automatic location"); enabled: !!(editor.value && editor.value.name); onClicked: { editor.set({}); editor.results=[]; } }
        }
        BText { width: parent.width; visible: text !== ""; text: editor.message; role: "caption"; wrapMode: Text.Wrap }
        Repeater {
            model: editor.results
            delegate: BButton {
                required property var modelData
                width: parent.width
                text: modelData.name
                onClicked: { editor.set(modelData); editor.results=[]; }
            }
        }
        BText { text: I18n.tr("Location search: Open-Meteo / GeoNames"); role: "caption"; tone: "muted" }
    }
}
