import QtQuick

// Placeholder for Niri support. Detection works (NIRI_SOCKET); state and
// actions will come from Niri's JSON IPC (`niri msg --json`, event stream).
// All capabilities stay false until implemented, so Settings hides the
// features that depend on them.
CompositorBackend {
    kind: "niri"
    displayName: "Niri"
}
