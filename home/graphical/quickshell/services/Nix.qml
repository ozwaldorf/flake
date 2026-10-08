pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Programs in nixpkgs that are not installed: binaries matched by name in the
// nix-index database, then fetched or built on demand with the progress nix
// reports as it goes, and started once they land in the store.
Singleton {
    id: root

    // ---- lookup ----

    // The prefix asked for, and the one the matches are for; the two differ
    // while a lookup is in flight. Matches are [{ bin, attr }], best first.
    property string wanted: ""
    property string matchedPrefix: ""
    property var matches: []
    readonly property bool searching: wanted !== matchedPrefix

    readonly property int perBin: 2
    readonly property int maxMatches: 6

    function lookup(prefix) {
        if (prefix === wanted)
            return;
        wanted = prefix;
        if (!/^[A-Za-z0-9._+-]{2,}$/.test(prefix)) {
            debounce.stop();
            matches = [];
            matchedPrefix = prefix;
            return;
        }
        debounce.restart();
    }

    // A lookup scans the whole database, most of a second, so it waits for
    // typing to settle
    Timer {
        id: debounce

        interval: 150
        onTriggered: locate.exec(["sh", "-c", 'printf "%s\\n" "$1"; exec nix-locate --at-root --type x --type s --regex "/bin/$2[^/]*$"', "sh", root.wanted, root.wanted.replace(/[.+]/g, "\\$&")])
    }

    Process {
        id: locate

        // The prefix comes back as the first line, so the output of a lookup
        // replaced mid-scan is not taken for the current one
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const prefix = lines.shift();
                if (prefix !== root.wanted)
                    return;
                root.matches = root.rank(prefix, lines);
                root.matchedPrefix = prefix;
            }
        }
    }

    // Exact names first, then the shortest, preferring an attribute named
    // for its binary over one that only bundles it or is nested in a set
    function rank(prefix, lines) {
        const found = [];
        const seen = {};
        for (const line of lines) {
            const parts = line.trim().split(/\s+/);
            const attr = (parts[0] ?? "").replace(/\.out$/, "");
            const path = parts[parts.length - 1] ?? "";
            if (attr === "" || attr.startsWith("("))
                continue;
            const bin = path.slice(path.lastIndexOf("/") + 1);
            const key = `${bin} ${attr}`;
            if (seen[key])
                continue;
            seen[key] = true;
            const related = attr.toLowerCase().includes(bin.toLowerCase().replace(/[-_.0-9]+$/, ""));
            found.push({
                bin: bin,
                attr: attr,
                score: [bin === prefix ? 0 : 1, bin.length, attr === bin ? 0 : (related ? 1 : 3) + (attr.includes(".") ? 1 : 0), attr.length]
            });
        }
        found.sort((a, b) => {
            for (let i = 0; i < a.score.length; i++)
                if (a.score[i] !== b.score[i])
                    return a.score[i] - b.score[i];
            return a.attr.localeCompare(b.attr);
        });
        const counts = {};
        const kept = [];
        for (const f of found) {
            counts[f.bin] = (counts[f.bin] ?? 0) + 1;
            if (counts[f.bin] <= perBin)
                kept.push({
                    bin: f.bin,
                    attr: f.attr
                });
            if (kept.length === maxMatches)
                break;
        }
        return kept;
    }

    // ---- running ----

    // What is being fetched, { bin, attr, args }, or null. One at a time.
    property var target: null
    readonly property bool busy: target !== null

    // 0 to 1, or -1 while there is nothing to measure it by
    property real progress: -1
    property string status: ""
    property string error: ""

    signal launched

    function isTarget(m) {
        return target !== null && target.bin === m.bin && target.attr === m.attr;
    }

    function start(bin, attr, args) {
        if (build.running || probe.running)
            return;
        target = {
            bin: bin,
            attr: attr,
            args: args
        };
        error = "";
        progress = -1;
        status = `Evaluating nixpkgs#${attr}`;
        job = {
            buildsId: -1,
            builds: [0, 0],
            building: "",
            buildId: -1,
            phase: "",
            downloads: {},
            downloadTotal: 0
        };
        build.exec({
            command: ["nix", "build", "--no-link", "--print-out-paths", "--impure", "--log-format", "internal-json", "-v", `nixpkgs#${attr}`],
            environment: {
                NIXPKGS_ALLOW_UNFREE: "1"
            }
        });
    }

    function cancel() {
        if (build.running)
            build.signal(15);
        target = null;
        error = "";
    }

    // Activity and result types from nix's internal-json log
    readonly property int actFileTransfer: 101
    readonly property int actBuilds: 104
    readonly property int actBuild: 105
    readonly property int resSetPhase: 104
    readonly property int resProgress: 105
    readonly property int resSetExpected: 106

    property var job: ({})

    function parse(line) {
        if (!line.startsWith("@nix "))
            return;
        let ev;
        try {
            // Activity ids run past what a double holds exactly, and would
            // collide as numbers
            ev = JSON.parse(line.slice(5).replace(/"(id|parent)":(\d+)/g, '"$1":"$2"'));
        } catch (e) {
            return;
        }
        const s = job;
        const f = ev.fields ?? [];
        if (ev.action === "start") {
            // narinfo lookups are file transfers too, but not part of the total
            if (ev.type === actFileTransfer && /\/nar\//.test(f[0] ?? ""))
                s.downloads[ev.id] = 0;
            else if (ev.type === actBuilds)
                s.buildsId = ev.id;
            else if (ev.type === actBuild) {
                s.buildId = ev.id;
                s.building = (f[0] ?? "").replace(/^\/nix\/store\/[^-]+-/, "").replace(/\.drv$/, "");
                s.phase = "";
            }
        } else if (ev.action === "stop") {
            if (ev.id === s.buildId) {
                s.buildId = -1;
                s.building = "";
            }
        } else if (ev.action === "result") {
            if (ev.type === resProgress) {
                if (ev.id in s.downloads)
                    s.downloads[ev.id] = f[0];
                else if (ev.id === s.buildsId)
                    s.builds = [f[0], f[1]];
            } else if (ev.type === resSetExpected && f[0] === actFileTransfer) {
                s.downloadTotal = f[1];
            } else if (ev.type === resSetPhase && ev.id === s.buildId) {
                s.phase = f[0];
            }
        } else if (ev.action === "msg") {
            // Store optimisation logs at the error level too, so an error is
            // known by its text; the cause is the innermost one, under any
            // evaluation trace
            const lines = ev.msg.replace(/\x1b\[[0-9;]*m/g, "").split("\n").map(l => l.trim()).filter(l => l.startsWith("error:"));
            if (lines.length > 0)
                error = lines.pop().replace(/^error:\s*/, "");
        }
        report();
    }

    function mib(bytes) {
        return (bytes / 1048576).toFixed(1);
    }

    function report() {
        const s = job;
        if (s.building !== "") {
            const count = s.builds[1] > 1 ? `, ${s.builds[0] + 1} of ${s.builds[1]}` : "";
            status = `Building ${s.building}${s.phase ? ` (${s.phase})` : ""}${count}`;
            progress = -1;
        } else if (s.downloadTotal > 0) {
            let done = 0;
            for (const id in s.downloads)
                done += s.downloads[id];
            status = `Downloading ${mib(done)} / ${mib(s.downloadTotal)} MiB`;
            progress = Math.min(1, done / s.downloadTotal);
        }
    }

    Process {
        id: build

        stdout: StdioCollector {
            id: buildOut
        }
        stderr: SplitParser {
            onRead: data => root.parse(data)
        }

        onExited: code => {
            if (root.target === null)
                return;
            if (code !== 0) {
                root.error = root.error || `nix build exited with ${code}`;
                root.progress = -1;
                root.status = root.error;
                return;
            }
            root.status = "Starting";
            root.progress = 1;
            probe.exec(["sh", "-c", 'b=$1; shift; for p; do [ -x "$p/bin/$b" ] && echo "bin $p/bin/$b"; [ -d "$p/share/applications" ] && echo gui; done; true', "sh", root.target.bin, ...buildOut.text.trim().split("\n")]);
        }
    }

    // Which output holds the binary, and whether any ships a desktop entry:
    // one with an entry is a graphical app and runs detached, anything else
    // runs in a terminal that stays once it exits
    Process {
        id: probe

        stdout: StdioCollector {
            onStreamFinished: {
                const t = root.target;
                if (t === null)
                    return;
                const lines = text.split("\n");
                const bin = lines.find(l => l.startsWith("bin "))?.slice(4);
                if (!bin) {
                    root.error = `no bin/${t.bin} in nixpkgs#${t.attr}`;
                    root.status = root.error;
                    root.progress = -1;
                    return;
                }
                const line = `'${bin.replace(/'/g, "'\\''")}'${t.args ? ` ${t.args}` : ""}`;
                if (lines.includes("gui"))
                    Quickshell.execDetached(["niri", "msg", "action", "spawn-sh", "--", line]);
                else
                    Quickshell.execDetached(["niri", "msg", "action", "spawn", "--", "env", `LAUNCHER_RUN=${line}`, "rio"]);
                root.target = null;
                root.launched();
            }
        }
    }
}
