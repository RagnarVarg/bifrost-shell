pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Runs a command and calls back once with (exitCode, stdout, stderr).
// Quickshell may deliver `exited` before the output streams finish, so the
// callback waits for all three. Exit code 124 means the timeout fired.
// Pass `owner` (the calling item) to skip the callback if it was destroyed
// in the meantime.
Singleton {
    id: root

    readonly property int defaultTimeoutMs: 10000

    function run(command: var, callback: var, timeoutMs: int, owner: var, inputText: var) {
        const p = processComponent.createObject(root, {
            command: command,
            inputText: inputText || "",
            callback: callback || null,
            owner: owner || null,
            hasOwner: !!owner,
            timeoutMs: timeoutMs > 0 ? timeoutMs : defaultTimeoutMs
        });
        p.running = true;
    }

    Component {
        id: processComponent

        Process {
            id: proc

            property string inputText: ""
            stdinEnabled: inputText !== ""
            onStarted: {
                if (inputText !== "") write(inputText);
            }
            property var callback: null
            property var owner: null
            property bool hasOwner: false
            property int timeoutMs: 10000
            property int exitCode: -1
            property bool exitSeen: false
            property bool outSeen: false
            property bool errSeen: false
            property bool done: false

            function finish() {
                if (done || !exitSeen || !outSeen || !errSeen)
                    return;
                done = true;
                timer.stop();
                // Destroyed QObject wrappers stay truthy; Qt.isQtObject tells.
                if (callback && (!hasOwner || (owner && Qt.isQtObject(owner)))) {
                    try {
                        callback(exitCode, out.text || "", err.text || "");
                    } catch (e) {
                        console.error("[bifrost] Exec callback failed for", JSON.stringify(command), e);
                    }
                }
                proc.destroy();
            }

            stdout: StdioCollector {
                id: out

                onStreamFinished: {
                    proc.outSeen = true;
                    proc.finish();
                }
            }
            stderr: StdioCollector {
                id: err

                onStreamFinished: {
                    proc.errSeen = true;
                    proc.finish();
                }
            }
            onExited: code => {
                exitCode = code;
                exitSeen = true;
                finish();
            }

            property Timer timer: Timer {
                interval: proc.timeoutMs
                running: proc.running
                onTriggered: {
                    proc.exitCode = 124;
                    proc.exitSeen = proc.outSeen = proc.errSeen = true;
                    proc.running = false;
                    proc.finish();
                }
            }
        }
    }
}
