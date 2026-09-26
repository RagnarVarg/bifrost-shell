import QtQuick
import qs.Core
import qs.Compositor
import qs.Services
import qs.Components.Controls
import qs.Components.Text

PageBase {
    id: page
    required property string kind
    title: kind === "keyboard" ? I18n.tr("Keyboard") : kind === "mouse" ? I18n.tr("Mouse") : I18n.tr("Trackpad")
    property string selectedName: ""
    property bool retained: false
    readonly property var available: InputDevices.devices.filter(d => d.kind === kind)
    readonly property var device: available.find(d => d.name === selectedName) || available.find(d => d.main) || available[0] || null
    readonly property var layoutCodes: device ? String(InputDevices.value(device,"kb_layout") || "").split(",").filter(Boolean) : []
    function sync() {
        if (visible && !retained) { retained = true; InputDevices.retain(); }
        else if (!visible && retained) { retained = false; InputDevices.release(); }
    }
    Component.onCompleted: sync()
    onVisibleChanged: sync()
    Component.onDestruction: if (retained) InputDevices.release()
    function setLayout(index, code) {
        const layouts = layoutCodes.slice(); layouts[index] = code;
        const variants = String(InputDevices.value(device,"kb_variant") || "").split(",");
        while (variants.length < layouts.length) variants.push("");
        variants[index] = "";
        InputDevices.set(device,"kb_layout",layouts.join(","));
        InputDevices.set(device,"kb_variant",variants.slice(0,layouts.length).join(","));
    }
    function removeLayout(index) {
        if (layoutCodes.length < 2) return;
        const layouts = layoutCodes.slice(); layouts.splice(index,1);
        const variants = String(InputDevices.value(device,"kb_variant") || "").split(","); variants.splice(index,1);
        InputDevices.set(device,"kb_layout",layouts.join(","));
        InputDevices.set(device,"kb_variant",variants.join(","));
        const active = Object.assign({}, Config.get("input.activeLayouts") || {});
        active[device.name] = 0; Config.set("input.activeLayouts",active);
    }
    BButton { text: I18n.tr("Back to Input"); icon: "chevron-left"; variant: "ghost"; onClicked: SettingsNav.open("input") }
    Banner { visible: InputDevices.applyStatus.ok === false; tone: "warning"; text: I18n.tr("The compositor could not apply the saved settings.") + " " + (InputDevices.applyStatus.message || "") }
    Banner { visible: InputDevices.error !== ""; tone: "warning"; text: I18n.tr(InputDevices.error) }
    Banner {
        visible: !Compositor.supports("inputConfig")
        text: I18n.tr("This compositor does not support input configuration from Bifrost.")
    }
    Row {
        width: parent.width
        spacing: Theme.space.md
        BDropdown {
            width: Math.max(Theme.control.height.lg, parent.width-refreshButton.width-parent.spacing)
            model: page.available.map(d => ({value:d.name,label:d.label}))
            currentValue: page.device ? page.device.name : ""
            placeholder: I18n.tr("No device detected")
            enabled: page.available.length > 1
            onActivated: name => page.selectedName = name
        }
        BButton { id: refreshButton; text: I18n.tr("Refresh"); enabled: !InputDevices.busy; onClicked: InputDevices.refresh() }
    }
    BText {
        width: parent.width
        text: !InputDevices.loaded ? I18n.tr("Detecting input devices…") : !page.device ? I18n.tr("No device detected. Connect a device to configure it.") : page.device.name
        role: "caption"; tone: "muted"; wrapMode: Text.WordWrap
    }
    Banner {
        visible: page.device !== null && !page.device.capabilitiesKnown
        text: I18n.tr("Hardware capabilities could not be read. Only verified compositor controls are shown.")
    }
    BText {
        visible: page.device !== null
        width: parent.width
        text: I18n.tr("Changes are saved for this device and applied live. Unedited fields keep the existing compositor configuration.")
        role: "caption"; tone: "muted"; wrapMode: Text.WordWrap
    }
    Card {
        visible: page.kind === "keyboard" && page.device !== null
        BText { text: I18n.tr("Keyboard layouts"); role: "heading" }
        BText { width: parent.width; text: I18n.tr("The first layout is used for shortcuts unless the compositor is configured otherwise."); role: "caption"; tone: "muted"; wrapMode: Text.WordWrap }
        Repeater {
            model: page.kind === "keyboard" ? page.layoutCodes : []
            delegate: Column {
                required property int index
                required property string modelData
                id: layoutRow
                width: parent.width; spacing: Theme.space.sm
                BDropdown {
                    width: parent.width; searchable: true
                    model: InputDevices.catalog.layouts
                    currentValue: layoutRow.modelData
                    onActivated: code => page.setLayout(layoutRow.index,code)
                }
                BDropdown {
                    width: parent.width; searchable: true
                    model: [{value:"",label:I18n.tr("Default variant")}].concat((InputDevices.catalog.layouts.find(l => l.value === layoutRow.modelData) || {}).variants || [])
                    currentValue: String(InputDevices.value(page.device,"kb_variant") || "").split(",")[layoutRow.index] || ""
                    onActivated: variant => {
                        const vs = String(InputDevices.value(page.device,"kb_variant") || "").split(",");
                        while (vs.length < page.layoutCodes.length) vs.push("");
                        vs[layoutRow.index] = variant;
                        InputDevices.set(page.device,"kb_variant",vs.join(","));
                    }
                }
                Flow {
                    width: parent.width; spacing: Theme.space.sm
                    BButton {
                        text: page.device && page.device.activeLayout === layoutRow.index ? I18n.tr("Active layout") : I18n.tr("Use this layout")
                        selected: page.device !== null && page.device.activeLayout === layoutRow.index
                        onClicked: {
                            const next = Object.assign({},Config.get("input.activeLayouts") || {});
                            next[page.device.name] = layoutRow.index;
                            Config.set("input.activeLayouts",next);
                            Compositor.switchInputLayout(page.device.name,layoutRow.index,ok => { if (!ok) InputDevices.error = "Could not switch keyboard layout"; activeRefresh.restart(); });
                        }
                    }
                    BButton { text: I18n.tr("Remove"); enabled: page.layoutCodes.length > 1; onClicked: page.removeLayout(layoutRow.index) }
                }
            }
        }
        BButton {
            text: I18n.tr("Add layout")
            enabled: page.layoutCodes.length < 4 && InputDevices.catalog.layouts.length > 0
            onClicked: {
                const next = InputDevices.catalog.layouts.find(l => l.value === "us" && page.layoutCodes.indexOf(l.value) < 0) || InputDevices.catalog.layouts.find(l => page.layoutCodes.indexOf(l.value) < 0);
                if (next) page.setLayout(page.layoutCodes.length,next.value);
            }
        }
        Repeater {
            model: [{prefix:"grp:",label:I18n.tr("Layout switch shortcut")},{prefix:"caps:",label:I18n.tr("Caps Lock behavior")},{prefix:"compose:",label:I18n.tr("Compose key")},{prefix:"altwin:",label:I18n.tr("Modifier remapping")},{prefix:"ctrl:",label:I18n.tr("Control key remapping")}]
            delegate: Column {
                required property var modelData
                width: parent.width; spacing: Theme.space.sm
                BText { text: parent.modelData.label; role: "label" }
                BDropdown {
                    width: parent.width; searchable: true
                    model: [{value:"",label:I18n.tr("Default")}].concat(InputDevices.catalog.options.filter(o => o.value.startsWith(parent.modelData.prefix) || (parent.modelData.prefix === "caps:" && o.value === "ctrl:nocaps")))
                    currentValue: InputDevices.option(page.device,parent.modelData.prefix)
                    onActivated: value => InputDevices.setOption(page.device,parent.modelData.prefix,value)
                }
            }
        }
        BButton {
            text: I18n.tr("Restore previous keyboard layout and options")
            visible: page.device !== null && !!InputDevices.saved[page.device.name] && ["kb_layout","kb_variant","kb_options"].some(k => InputDevices.saved[page.device.name].values[k] !== undefined)
            onClicked: {
                for (const k of ["kb_layout","kb_variant","kb_options"]) InputDevices.reset(page.device,k);
                const active = Object.assign({},Config.get("input.activeLayouts") || {});
                delete active[page.device.name]; Config.set("input.activeLayouts",active);
            }
        }
        BText { text: I18n.tr("Test your keyboard"); role: "label" }
        BTextField { width: parent.width; placeholder: I18n.tr("Type here to test the selected layout") }
    }
    Card {
        visible: page.device !== null
        Repeater {
            model: InputDevices.fields.filter(f => ["kb_layout","kb_variant","kb_options"].indexOf(f.key) < 0 && InputDevices.supported(page.device,f))
            delegate: InputControl { required property var modelData; device: page.device; definition: modelData }
        }
    }
    InputGestures {
        visible: page.kind === "trackpad" && page.device !== null && page.device.capabilities.gestures === true
        device: page.device
    }
    Timer { id: activeRefresh; interval: 1200; onTriggered: InputDevices.refresh() }
}
