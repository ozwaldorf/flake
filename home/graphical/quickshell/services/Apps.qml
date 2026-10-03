pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The launcher's results: desktop entries ranked by a fuzzy match and by how
// often and lately each was launched, a calculator for a query that reads as
// arithmetic, and the query itself as a shell command to fall back on.
//
// Everything is spawned through niri rather than from the shell: the shell's
// unit kills its whole cgroup on a restart, and would take every app launched
// from it along.
Singleton {
    id: root

    readonly property var entries: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    // id -> { count, last }, last in epoch seconds. Replaced rather than
    // mutated so bindings reading through it re-evaluate.
    property var usage: ({})

    readonly property string dir: Quickshell.statePath("launcher")

    FileView {
        id: usageFile

        path: `${root.dir}/usage.json`
        printErrors: false

        onLoaded: {
            try {
                root.usage = JSON.parse(text()) ?? {};
            } catch (e) {
                root.usage = {};
            }
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dir])

    // Weighted by age so a burst of launches last month does not outrank what
    // is in use this week.
    function frecency(id) {
        const u = usage[id];
        if (!u)
            return 0;
        const days = (Date.now() / 1000 - u.last) / 86400;
        const weight = days < 1 ? 4 : days < 7 ? 2 : days < 30 ? 1 : 0.5;
        return u.count * weight;
    }

    function record(id) {
        const next = Object.assign({}, usage);
        next[id] = {
            count: (usage[id]?.count ?? 0) + 1,
            last: Math.floor(Date.now() / 1000)
        };
        usage = next;
        usageFile.setText(JSON.stringify(next));
    }

    // Subsequence match, scored for runs of consecutive characters and for
    // landing on the start of a word; -1 when the query is not in the text,
    // or only as letters strewn through it, which any short query finds in
    // some name and which would bury the run rows under noise.
    function fuzzy(query, text) {
        if (!text)
            return -1;
        const t = text.toLowerCase();
        if (t.startsWith(query))
            return 100 + query.length * 10 - t.length * 0.1;
        let score = 0;
        let run = 0;
        let ti = 0;
        for (let qi = 0; qi < query.length; qi++) {
            const c = query[qi];
            const found = t.indexOf(c, ti);
            if (found < 0)
                return -1;
            run = found === ti ? run + 1 : 0;
            score += 1 + run * 3;
            if (found === 0 || /[\s\-_.]/.test(t[found - 1]))
                score += 6;
            score -= Math.min(found - ti, 5) * 0.5;
            ti = found + 1;
        }
        return score < query.length * 2.5 ? -1 : Math.max(0, score - t.length * 0.1);
    }

    function matchEntry(query, e) {
        const name = fuzzy(query, e.name);
        const others = [e.genericName, ...(e.keywords ?? [])].map(s => fuzzy(query, s));
        const best = Math.max(name, others.length ? Math.max(...others) * 0.6 : -1);
        return best;
    }

    // Arithmetic only: numbers, operators, brackets and a few Math names. The
    // check is what keeps the evaluation below from running anything else.
    readonly property var mathNames: ["sqrt", "cbrt", "abs", "floor", "ceil", "round", "sin", "cos", "tan", "asin", "acos", "atan", "log", "log2", "log10", "exp", "min", "max", "pow", "pi", "e"]

    function calculate(query) {
        if (!/[0-9]/.test(query) || !/^[0-9a-z+\-*/%^().,\s]+$/i.test(query))
            return null;
        const words = query.match(/[a-z]+[0-9]*/gi) ?? [];
        if (words.some(w => !mathNames.includes(w.toLowerCase())))
            return null;
        if (!/[+\-*/%^(]/.test(query) && words.length === 0)
            return null;
        try {
            const expr = query.replace(/\^/g, "**").replace(/[a-z]+[0-9]*/gi, w => {
                const name = w.toLowerCase();
                return `Math.${name === "pi" || name === "e" ? name.toUpperCase() : name}`;
            });
            const value = new Function(`return (${expr});`)();
            if (typeof value !== "number" || !isFinite(value))
                return null;
            return String(Number.isInteger(value) ? value : parseFloat(value.toPrecision(12)));
        } catch (e) {
            return null;
        }
    }

    function search(text) {
        const query = text.trim().toLowerCase();
        const results = [];

        if (query === "") {
            return entries.slice().sort((a, b) => frecency(b.id) - frecency(a.id) || a.name.localeCompare(b.name)).map(e => ({
                        kind: "app",
                        entry: e
                    }));
        }

        const value = calculate(text.trim());
        if (value !== null)
            results.push({
                kind: "calc",
                title: value,
                detail: text.trim()
            });

        const apps = [];
        for (const e of entries) {
            const s = matchEntry(query, e);
            if (s >= 0)
                apps.push({
                    entry: e,
                    score: s + Math.min(frecency(e.id), 40)
                });
        }
        apps.sort((a, b) => b.score - a.score);
        for (const a of apps.slice(0, 40))
            results.push({
                kind: "app",
                entry: a.entry
            });

        results.push({
            kind: "term",
            title: text.trim(),
            detail: "Run in terminal"
        }, {
            kind: "run",
            title: text.trim(),
            detail: "Run detached"
        });
        return results;
    }

    function activate(result) {
        if (result.kind === "app") {
            const e = result.entry;
            record(e.id);
            const command = e.runInTerminal ? ["rio", "-e", ...e.command] : e.command;
            Quickshell.execDetached(["niri", "msg", "action", "spawn", "--", ...command]);
        } else if (result.kind === "calc") {
            Quickshell.execDetached(["wl-copy", "--", result.title]);
        } else if (result.kind === "term") {
            // Handed to the shell's own startup, which enters it at the first
            // prompt as though typed: the shell starts as it always does, and
            // stays once the command exits.
            Quickshell.execDetached(["niri", "msg", "action", "spawn", "--", "env", `LAUNCHER_RUN=${result.title}`, "rio"]);
        } else if (result.kind === "run") {
            Quickshell.execDetached(["niri", "msg", "action", "spawn-sh", "--", result.title]);
        }
    }
}
