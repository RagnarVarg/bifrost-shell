import QtQuick
import Quickshell.Io

// Quickshell FileView wrapped behind a small, stable API:
//   readNow() -> string | null     synchronous read (null = missing)
//   readFresh()                    same, forcing a re-read
//   write(text)                    atomic write, creates parent dirs
//   writeNow(text)                 same, but returns only once it is on disk
//   contentChanged(text, exists)   initial load and external modifications
//
// Quickshell can only watch a file whose directory exists when watching
// starts, so a watched file creates its parent directory and re-arms.
FileView {
    id: file

    property bool watch: true
    property bool exists: false

    signal contentChanged(string content, bool exists)

    blockLoading: true
    watchChanges: watch
    atomicWrites: true
    printErrors: false

    function readNow(): var {
        waitForJob();
        exists = loaded;
        return loaded ? text() : null;
    }

    // Re-reads the file even if the path is unchanged (e.g. /proc files).
    function readFresh(): var {
        reload();
        return readNow();
    }

    function write(content: string) {
        setText(content);
    }

    function writeNow(content: string) {
        setText(content);
        waitForJob();
    }

    function rearm() {
        const p = path;
        path = "";
        path = p;
    }

    onFileChanged: reload()
    onLoaded: {
        exists = true;
        contentChanged(text(), true);
    }
    onLoadFailed: err => {
        if (err === FileViewError.FileNotFound) {
            exists = false;
            contentChanged("", false);
        } else {
            console.error("[bifrost] cannot read", path, FileViewError.toString(err));
        }
    }

    Component.onCompleted: {
        if (!watch || !path)
            return;
        const dir = path.substring(0, path.lastIndexOf("/"));
        Exec.run(["mkdir", "-p", dir], exitCode => {
            if (exitCode === 0 && !file.exists)
                file.rearm();
        });
    }
}
