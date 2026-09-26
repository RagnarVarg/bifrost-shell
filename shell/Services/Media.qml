pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The most relevant MPRIS player: the playing one, else the first.
Singleton {
    readonly property var players: Mpris.players ? Mpris.players.values : []
    property string selectedPlayer: ""
    readonly property var player: players.find(p => p.dbusName === selectedPlayer) || players.find(p => p.isPlaying) || players[0] || null
    onPlayersChanged: if (selectedPlayer && !players.some(p => p.dbusName === selectedPlayer)) selectedPlayer = ""

    function selectPlayer(name: string) {
        selectedPlayer = players.some(p => p.dbusName === name) ? name : "";
    }
    readonly property bool available: player !== null
    readonly property string title: player ? (player.trackTitle || player.identity) : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string art: player ? (player.trackArtUrl || "") : ""
    readonly property bool playing: player ? player.isPlaying : false
    readonly property bool canToggle: player ? player.canTogglePlaying : false
    readonly property bool canControl: player ? player.canControl : false
    readonly property bool canPrevious: player ? player.canGoPrevious : false
    readonly property bool canNext: player ? player.canGoNext : false
    // Seconds; MPRIS doesn't push the position, so it is re-read every second
    // while someone has retained the service (a progress bar is visible).
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property real position: player && player.positionSupported ? player.position : 0
    property int users: 0

    function retain() {
        users++;
    }

    function release() {
        users = Math.max(0, users - 1);
    }

    function clock(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        const m = Math.floor(s / 60);
        return (m >= 60 ? Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0") : m) + ":" + String(s % 60).padStart(2, "0");
    }

    Timer {
        running: users > 0 && playing
        interval: 1000
        repeat: true
        onTriggered: if (player)
            player.positionChanged()
    }

    function togglePlaying() {
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }

    function next() {
        if (player && player.canGoNext)
            player.next();
    }

    function stop() {
        if (player && player.canControl)
            player.stop();
    }

    function previous() {
        if (player && player.canGoPrevious)
            player.previous();
    }
}
