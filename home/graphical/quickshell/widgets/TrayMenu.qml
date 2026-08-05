pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// Themed replacement for the platform tray menu. QsMenuOpener exposes the
// DBusMenu tree as a model, so the entries are rendered here rather than handed
// to Qt's native widget menu, which ignores the shell's styling.
//
// Submenus open as their own instances of this component, anchored to the row
// that spawned them, so the tree nests to any depth.
// Layer surface rather than a PopupWindow: xdg_popup surfaces do not pick up
// the compositor blur reliably, and everything else in the shell is a
// PanelWindow, so this behaves consistently with them.
PanelWindow {
    id: root

    // screen to place the menu on; not required, submenus are URL loaded
    property var screenData: null

    // Handle to render; the top level passes the tray item's menu, a submenu
    // passes the entry that owns it. Not required properties: submenus are
    // created by a URL Loader, which cannot supply them at construction.
    property var handle: null

    // item the menu is positioned against, and which side it opens toward
    property var anchorItem: null
    property bool anchorRight: false

    // A submenu opens beside its parent row rather than below it, and its
    // anchor already lives in a screen sized window.
    property bool submenu: false
    property real parentEdgeLeft: 0
    property real parentEdgeRight: 0

    // closes this menu and everything under it
    signal closeRequested

    readonly property real menuWidth: 220
    readonly property real menuHeight: layout.implicitHeight + Theme.spaceXs * 2

    // Horizontal offset of the anchor's window from the screen's left edge.
    // mapToItem(null) is window local, and the control centre is a right
    // anchored window on the right hand monitor, so its local x is not a screen
    // coordinate. This menu spans the whole screen, so the two have to agree.
    property real anchorWindowX: 0

    // Position in screen space, sampled when the menu opens. mapToItem is a
    // plain call with no dependency tracking, so it cannot be a live binding;
    // recomputing on open is enough since the anchor does not move while shown.
    property point origin: Qt.point(0, 0)

    function syncOrigin() {
        if (anchorItem)
            origin = anchorItem.mapToItem(null, 0, 0);
    }

    readonly property real originScreenX: origin.x + anchorWindowX

    // Top level drops below the tray icon; a submenu sits beside the parent
    // panel, flipping to its other side when there is no room.
    readonly property real menuX: {
        if (!submenu)
            return anchorRight ? Math.max(Theme.spaceXs, originScreenX + (anchorItem?.width ?? 0) - menuWidth) : Math.min(originScreenX, root.width - menuWidth - Theme.spaceXs);

        const toRight = parentEdgeRight + Theme.spaceXs;
        const toLeft = parentEdgeLeft - menuWidth - Theme.spaceXs;
        if (anchorRight)
            return toLeft >= Theme.spaceXs ? toLeft : toRight;
        return toRight + menuWidth <= root.width - Theme.spaceXs ? toRight : toLeft;
    }

    readonly property real menuY: {
        // a submenu aligns to its row, the top level drops below the icon
        const desired = submenu ? origin.y : origin.y + (anchorItem?.height ?? 0) + Theme.spaceXs;
        return Math.max(Theme.spaceXs, Math.min(desired, root.height - menuHeight - Theme.spaceXs));
    }

    screen: screenData
    color: "transparent"
    visible: false

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay

    // only the menu itself takes input; the rest of the screen stays clickable
    mask: Region {
        x: root.menuX
        y: root.menuY
        width: root.menuWidth
        height: root.menuHeight
    }

    // Blurred like every other surface. BackgroundEffect attaches to any
    // ProxyWindowBase, which is what PopupWindow derives from.
    BackgroundEffect.blurRegion: Region {
        x: root.menuX
        y: root.menuY
        width: root.menuWidth
        height: root.menuHeight
        radius: Theme.rounding
    }


    onVisibleChanged: {
        if (visible)
            syncOrigin();
        if (!visible) {
            if (openSubmenu)
                openSubmenu.visible = false;
            openSubmenu = null;
        }
    }

    // closing this level closes everything under it
    onCloseRequested: visible = false

    // at most one submenu open at a time, so moving between rows swaps it
    property var openSubmenu: null

    // Dismiss when the pointer leaves the whole tree. Checked on a delay so
    // travelling between a row and its submenu does not read as leaving, and
    // only the root actually closes so the dismissal is consistent.
    readonly property bool pointerInside: menuHover.hovered || (openSubmenu?.pointerInside ?? false)

    onPointerInsideChanged: {
        if (pointerInside)
            leaveTimer.stop();
        else
            leaveTimer.restart();
    }

    Timer {
        id: leaveTimer

        interval: Theme.exitDelay
        onTriggered: {
            if (!root.pointerInside)
                root.closeRequested();
        }
    }

    QsMenuOpener {
        id: opener

        menu: root.handle
    }

    Rectangle {
        x: root.menuX
        y: root.menuY
        width: root.menuWidth
        height: root.menuHeight

        radius: Theme.rounding
        color: Theme.surfaceFill
        border.width: 1
        border.color: Theme.surface1

        HoverHandler {
            id: menuHover
        }

        Column {
            id: layout

            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: 1

            Repeater {
                model: opener.children

                Item {
                    id: entry

                    required property var modelData

                    readonly property bool separator: modelData.isSeparator
                    readonly property bool checkable: modelData.buttonType !== QsMenuButtonType.None
                    readonly property bool checked: modelData.checkState === Qt.Checked

                    width: layout.width
                    implicitHeight: separator ? Theme.spaceXs * 2 + 1 : 28

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - Theme.spaceXs * 2
                        height: 1
                        color: Theme.surface1
                        visible: entry.separator
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        color: entryHover.hovered && entry.modelData.enabled ? Theme.surface1 : "transparent"
                        visible: !entry.separator

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        // check or radio state
                        Rectangle {
                            id: marker

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spaceXs
                            anchors.verticalCenter: parent.verticalCenter

                            implicitWidth: 11
                            implicitHeight: 11
                            radius: entry.modelData.buttonType === QsMenuButtonType.RadioButton ? 5.5 : 2

                            visible: entry.checkable
                            color: entry.checked ? Theme.blue : "transparent"
                            border.width: 1
                            border.color: entry.checked ? Theme.blue : Theme.surface2

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }

                        Image {
                            id: entryIcon

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spaceXs
                            anchors.verticalCenter: parent.verticalCenter

                            width: 14
                            height: 14
                            // Names come through as theme icon names, not paths,
                            // so they have to be resolved. Many arrive with a
                            // -symbolic suffix the theme does not carry, so fall
                            // back to the bare name before giving up. The bool
                            // overload returns empty on a miss instead of
                            // warning about a missing texture.
                            source: {
                                const name = entry.modelData.icon;
                                if (!name)
                                    return "";
                                const direct = Quickshell.iconPath(name, true);
                                if (direct)
                                    return direct;
                                const bare = name.replace(/-symbolic$/, "");
                                return bare !== name ? Quickshell.iconPath(bare, true) : "";
                            }
                            // sourceSize pinned or Qt requests at the implicit
                            // size, which is where the 100x100 lookups came from
                            sourceSize.width: 14
                            sourceSize.height: 14
                            visible: status === Image.Ready && !entry.checkable
                            asynchronous: true
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: entry.checkable || entryIcon.visible ? Theme.spaceXs + 18 : Theme.spaceXs
                            anchors.right: submenuArrow.left
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter

                            text: entry.modelData.text
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: entry.modelData.enabled ? Theme.subtext0 : Theme.surface2
                            elide: Text.ElideRight
                        }

                        Text {
                            id: submenuArrow

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spaceXs
                            anchors.verticalCenter: parent.verticalCenter

                            text: ">"
                            font.family: Theme.font
                            font.pixelSize: 10
                            color: Theme.overlay0
                            visible: entry.modelData.hasChildren
                        }

                        // Submenu as another instance of this component. Opened
                        // on hover like a normal menu, and closed when another
                        // row takes over.
                        // Loaded by URL rather than by type name: QML rejects a
                        // component that references itself, so recursion has to
                        // be deferred to runtime.
                        Loader {
                            id: submenuLoader

                            // Only instantiated once the row is actually opened.
                            // Loading eagerly gives every branch a live
                            // QsMenuOpener, and those subscriptions retrigger
                            // DBusMenu layout updates that empty and refill this
                            // level's model in a loop.
                            active: false
                            source: "TrayMenu.qml"

                            onLoaded: {
                                item.screenData = root.screenData;
                                // Deliberately not inherited: a submenu anchors
                                // to a row inside this window, which already
                                // spans the screen, so its origin is screen
                                // space. Passing the offset would double count.
                                item.anchorWindowX = 0;
                                item.submenu = true;
                                item.parentEdgeLeft = Qt.binding(() => root.menuX);
                                item.parentEdgeRight = Qt.binding(() => root.menuX + root.menuWidth);
                                item.handle = entry.modelData;
                                item.anchorItem = entry;
                                item.anchorRight = Qt.binding(() => root.anchorRight);
                                item.closeRequested.connect(root.closeRequested);
                            }
                        }

                        HoverHandler {
                            id: entryHover

                            cursorShape: entry.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onHoveredChanged: {
                                if (!hovered)
                                    return;
                                // swap which branch is open as the pointer moves
                                if (root.openSubmenu && root.openSubmenu !== submenuLoader.item)
                                    root.openSubmenu.visible = false;
                                if (entry.modelData.hasChildren && entry.modelData.enabled) {
                                    // instantiate on demand, not up front
                                    submenuLoader.active = true;
                                    submenuLoader.item.visible = true;
                                    root.openSubmenu = submenuLoader.item;
                                } else {
                                    root.openSubmenu = null;
                                }
                            }
                        }

                        TapHandler {
                            enabled: entry.modelData.enabled && !entry.modelData.hasChildren
                            onTapped: {
                                entry.modelData.triggered();
                                // dismiss the whole tree, not just this level
                                root.closeRequested();
                            }
                        }
                    }
                }
            }
        }
    }
}
