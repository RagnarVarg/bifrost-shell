import QtQuick
import Quickshell.Io

// Synchronous one-shot JSON reader: read(path) -> { ok, data, missing, error }.
FileView {
    id: reader

    blockLoading: true
    printErrors: false

    function read(file: string): var {
        if (path === file)
            reload();
        else
            path = file;
        waitForJob();
        if (!loaded)
            return { ok: false, missing: true, error: "not found: " + file };
        try {
            return { ok: true, data: JSON.parse(text()) };
        } catch (e) {
            return { ok: false, missing: false, error: file + ": " + e.message };
        }
    }
}
