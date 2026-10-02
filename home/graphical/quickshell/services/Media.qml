pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Which Mpris player the shell presents, shared by the panel's card and the
// toast so the two never disagree about what is playing.
Singleton {
    id: root

    // Whichever player is actually playing, else the one already being shown
    // while it is still around, else the first. Holding the last pick stops a
    // pause from flipping the card to some other idle player.
    //
    // Picked imperatively rather than bound: the choice depends on what it was
    // last time, which a binding cannot read without looping on itself.
    property var player: null

    function pick() {
        const all = Mpris.players.values;
        const playing = all.find(p => p.isPlaying);
        if (playing)
            player = playing;
        else if (!all.includes(player))
            player = all.length > 0 ? all[0] : null;
    }

    Component.onCompleted: pick()

    Connections {
        target: Mpris.players

        function onValuesChanged() {
            root.pick();
        }
    }

    Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property var modelData

            target: modelData

            function onIsPlayingChanged() {
                root.pick();
            }
        }
    }

    // What identifies a track: the id is the reliable part, and the title
    // stands in for players that reuse one object path across everything they
    // play, which Firefox does for every tab.
    //
    // The id arrives as a stringified QDBusObjectPath rather than a bare path,
    // so it is only ever compared against itself, never parsed.
    function trackKey(p) {
        return p ? (p.metadata?.["mpris:trackid"] ?? "") + "\n" + (p.trackTitle ?? "") : "";
    }

    // the page a browser player is on, which Quickshell only carries in the
    // raw metadata map
    function pageUrl(p) {
        return p?.metadata?.["xesam:url"] ?? "";
    }
}
