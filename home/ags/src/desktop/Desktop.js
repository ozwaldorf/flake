import Widget from "resource:///com/github/Aylur/ags/widget.js";
import DesktopMenu from "./DesktopMenu.js";
import options from "../options.js";

/** @param {number} monitor */
export default (monitor) =>
  Widget.Window({
    monitor,
    name: `desktop${monitor}`,
    layer: "bottom",
    class_name: "desktop",
    anchor: ["top", "bottom", "left", "right"],
    child: Widget.EventBox({
      on_secondary_click: (_, event) => DesktopMenu().popup_at_pointer(event),
    }),
  });
