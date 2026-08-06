pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Site icons for players that name a page but publish no cover art.
//
// A browser tab is the case this exists for: Firefox only sends mpris:artUrl
// when the page sets it through the Media Session API, so most tabs arrive
// with a title and a URL and nothing to draw. The site's own icon is the one
// thing such a URL reliably yields, and it identifies what is playing far
// better than a generic glyph does.
//
// Fetched rather than scraped: the page's HTML would be a request for whatever
// is open, and the sites that withhold artUrl are largely the ones that also
// withhold their OpenGraph tags to a logged out client. A favicon is public,
// small, and one request per host for as long as the cache survives.
Singleton {
    id: root

    // host -> local file path, for hosts that have one. Replaced rather than
    // mutated: a property change on the same object does not re-evaluate the
    // bindings that read through it.
    property var icons: ({})

    // Hosts already tried and settled, successfully or not, so a site with no
    // reachable icon is asked once rather than on every track change. Held
    // separately from the results since a failure has nothing to store.
    property var settled: ({})

    readonly property string dir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/favicons"

    // Hosts waiting on a turn, and the one being fetched. Serialised so a
    // burst of track changes cannot open a connection per change.
    property var queue: []
    property string active: ""

    // Everything below treats a host as opaque and quotes it into the shell,
    // but it reaches this from a URL a player put on the bus, so it is
    // validated to what a hostname can contain before going near a command.
    function hostOf(url) {
        if (!url)
            return "";

        const m = /^https?:\/\/([^/?#]+)/i.exec(url);
        if (!m)
            return "";

        // strip any credentials and port
        const host = m[1].replace(/^.*@/, "").replace(/:\d+$/, "").toLowerCase();

        return /^[a-z0-9.-]+$/.test(host) && host.indexOf("..") < 0 ? host : "";
    }

    // The icon for a URL's host if one is already known, else "". Requests the
    // fetch as a side effect, so a caller can simply bind to this and get the
    // icon once it lands.
    function forUrl(url) {
        const host = hostOf(url);
        if (host === "")
            return "";

        if (icons[host])
            return icons[host];

        request(host);
        return "";
    }

    function request(host) {
        if (host === "" || settled[host] || active === host || queue.indexOf(host) >= 0)
            return;

        queue.push(host);
        pump();
    }

    function pump() {
        if (active !== "" || queue.length === 0)
            return;

        active = queue.shift();
        fetch.running = true;
    }

    // One shot per host: the cache is consulted first, so a hit costs nothing
    // beyond the stat and the fetch only runs the first time a host is seen or
    // after the cache is cleared.
    //
    // Bounded hard on every axis that an unknown host controls: total time,
    // connect time, redirects, and written bytes. A hostile or merely broken
    // server cannot hold the slot open or fill the disk.
    Process {
        id: fetch

        command: ["sh", "-c", "set -e; d=\"$1\"; h=\"$2\"; f=\"$d/$h.ico\"; mkdir -p \"$d\"; if [ -s \"$f\" ]; then echo \"$f\"; exit 0; fi; t=$(mktemp \"$d/.tmp.XXXXXX\"); trap 'rm -f \"$t\"' EXIT; curl -sfL --max-time 8 --connect-timeout 4 --max-redirs 3 --max-filesize 262144 -o \"$t\" \"https://$h/favicon.ico\" || exit 1; [ -s \"$t\" ] || exit 1; mv \"$t\" \"$f\"; trap - EXIT; echo \"$f\"", "sh", root.dir, root.active]

        stdout: StdioCollector {
            id: fetchOut
        }

        onExited: exitCode => {
            const host = root.active;
            const path = fetchOut.text.trim();

            if (exitCode === 0 && path !== "") {
                // Replaced wholesale so anything bound through icons sees the
                // change; assigning into the existing object does not notify.
                const next = Object.assign({}, root.icons);
                next[host] = path;
                root.icons = next;
            }

            const done = Object.assign({}, root.settled);
            done[host] = true;
            root.settled = done;

            root.active = "";
            root.pump();
        }
    }
}
