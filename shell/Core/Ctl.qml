pragma Singleton

import QtQuick
import Quickshell
import qs.Compat

// Runs tools/bifrostctl for data operations (presets, profiles, bundles, DMS
// import) so that logic exists once, in the CLI. Callback: (ok, output, json).
Singleton {
    readonly property string path: Paths.repoDir + "/tools/bifrostctl"

    function run(args: var, callback: var, owner: var) {
        Exec.run(["python3", path].concat(args), (code, out, err) => {
            let data = null;
            try {
                data = JSON.parse(out);
            } catch (e) {}
            if (callback)
                callback(code === 0, (out + err).trim(), data);
        }, 30000, owner);
    }
}
