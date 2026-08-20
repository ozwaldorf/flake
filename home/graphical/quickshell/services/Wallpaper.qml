pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The desktop background: which image is up, and the CLUT every screen grades
// through.
//
// Images are pulled from Wikimedia Commons rather than a local collection, so
// the set is unbounded and nothing has to be curated by hand. They are stored
// ungraded; the palette is applied on the GPU when they are drawn, which is
// what lets the theme change without touching the files.
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/Pictures/walls/commons`

    // Remembered across restarts so the desktop comes back up on the image it
    // went down on rather than flashing to a default or an empty screen.
    readonly property string statePath: `${Quickshell.statePath("wallpaper")}/current`

    // The Hald CLUT the shader grades through, regenerated at startup so a
    // palette change lands without a stale file surviving. Level 8 holds 64
    // steps per channel in a 512x512 image, which is indistinguishable from
    // the CPU result on photographs and small enough to keep resident.
    readonly property string clutPath: `${Quickshell.statePath("wallpaper")}/carburetor.png`
    readonly property int clutLevel: 8

    // Empty until the CLUT exists. The screens hold off drawing rather than
    // showing one ungraded frame before it lands.
    property bool clutReady: false

    // Qt will not compile GLSL at runtime, so the shader is baked at build time
    // and pointed at from the unit. Falls back to the working tree for a shell
    // started by hand outside the service, where a qsb built next to the source
    // is the only copy there is.
    readonly property url shaderDir: Quickshell.env("QUICKSHELL_SHADERS") ? `file://${Quickshell.env("QUICKSHELL_SHADERS")}/` : Qt.resolvedUrl("../shaders/")

    property string current: ""
    property bool fetching: false
    property string error: ""

    // Written on every change so an external reader (and the next start) can
    // see what is up without asking the shell.
    FileView {
        id: stateFile

        path: root.statePath
        // Created on the first write rather than erroring on a fresh machine
        // where nothing has been set yet.
        printErrors: false

        onLoaded: {
            const saved = text().trim();
            if (saved !== "" && root.current === "")
                restore.check(saved);
            else
                restore.settle();
        }

        // No state to restore, on a fresh machine or after the directory was
        // cleared. Reported as settled anyway: startup waits on this answer,
        // and a load that never resolves would leave the desktop blank.
        onLoadFailed: restore.settle()
    }

    // The saved image may be gone: the directory is a cache, and pruning it
    // between runs is expected. Adopting the path blindly leaves every screen
    // on an image that cannot be loaded, with nothing to trigger a replacement,
    // so it is confirmed to exist before being taken up and a fresh one is
    // fetched when it is not.
    Process {
        id: restore

        property string candidate: ""

        function check(path) {
            candidate = path;
            command = ["test", "-r", path];
            running = true;
        }

        property bool settled: false

        function settle() {
            settled = true;
            root.fetchIfEmpty();
        }

        onExited: exitCode => {
            if (exitCode === 0)
                root.current = restore.candidate;
            settle();
        }
    }

    // Startup pulls a new image only once both halves have reported: the CLUT,
    // without which there is nothing to grade through, and the check on the
    // saved path, without which an image that is still on disk would be passed
    // over and replaced. Called from both, and acts on whichever is last.
    function fetchIfEmpty() {
        if (clutReady && restore.settled && current === "")
            next();
    }

    // Generated rather than shipped: it is derived from the palette, and
    // lutgen produces it in well under a second. Preserving luminosity is what
    // keeps a photograph looking like one, without it the tones flatten
    // towards the palette's own and the image goes grey.
    Process {
        id: makeClut

        // statePath only names the location, it does not create it, and both
        // lutgen and the state write below fail outright on a missing parent.
        command: ["sh", "-c", `mkdir -p "$(dirname "$1")" && exec lutgen generate -p carburetor -P -l "$2" -o "$1"`, "sh", root.clutPath, String(root.clutLevel)]

        onExited: exitCode => {
            if (exitCode === 0) {
                root.clutReady = true;
                root.fetchIfEmpty();
            } else {
                root.error = "could not generate the color palette";
            }
        }
    }

    Process {
        id: fetch

        command: [`${Quickshell.env("HOME")}/.config/quickshell/scripts/fetch-wallpaper.sh`]
        environment: ({
                WALLPAPER_DIR: root.dir
            })

        stdout: StdioCollector {
            id: fetchOut
        }

        onExited: exitCode => {
            root.fetching = false;

            // Commons was unreachable, or nothing in the sample matched the
            // shape a screen wants. Neither is worth reporting as a failure:
            // what is already up stays up and the next attempt is a keypress
            // away.
            if (exitCode !== 0) {
                root.error = "no wallpaper found";
                return;
            }

            const path = fetchOut.text.trim();
            if (path !== "")
                root.setWallpaper(path);
        }
    }

    function setWallpaper(path) {
        if (path === "" || path === current)
            return;

        error = "";
        current = path;
        stateFile.setText(path);
    }

    function next() {
        // The screens keep showing the current image while this runs, so there
        // is nothing to guard beyond not stacking fetches.
        if (fetching)
            return;

        error = "";
        fetching = true;
        fetch.running = true;
    }

    Component.onCompleted: {
        stateFile.reload();
        makeClut.running = true;
    }
}
