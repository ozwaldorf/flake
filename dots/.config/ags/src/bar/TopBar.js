import SystemTray from "resource:///com/github/Aylur/ags/service/systemtray.js";
import Widget from "resource:///com/github/Aylur/ags/widget.js";
import Variable from "resource:///com/github/Aylur/ags/variable.js";
import Notifications from "resource:///com/github/Aylur/ags/service/notifications.js";
import Mpris from "resource:///com/github/Aylur/ags/service/mpris.js";
import OverviewButton from "./buttons/OverviewButton.js";
import MediaIndicator from "./buttons/MediaIndicator.js";
import DateButton from "./buttons/DateButton.js";
import NotificationIndicator from "./buttons/NotificationIndicator.js";
import SysTray from "./buttons/SysTray.js";
import ColorPicker from "./buttons/ColorPicker.js";
import SystemIndicators from "./buttons/SystemIndicators.js";
import ScreenRecord from "./buttons/ScreenRecord.js";
import SubMenu from "./buttons/SubMenu.js";
import Recorder from "../services/screenrecord.js";
import options from "../options.js";

const submenuItems = Variable(1);
SystemTray.connect("changed", () => {
  submenuItems.setValue(SystemTray.items.length + 1);
});

/**
 * @template T
 * @param {T=} service
 * @param {(self: T) => boolean=} condition
 */
const SeparatorDot = (service, condition) => {
  const visibility = (self) => {
    if (!options.bar.separators.value) return (self.visible = false);

    self.visible = condition && service
      ? condition(service)
      : options.bar.separators.value;
  };

  const conn = service ? [[service, visibility]] : [];
  return Widget.Separator({
    connections: [["draw", visibility], ...conn],
    binds: [["visible", options.bar.separators]],
    vpack: "center",
  });
};

const OptionalWorkspaces = async () => {
  try {
    return (await import('./buttons/Workspaces.js')).default();
  } catch {
    return (await import('./buttons/SwayWorkspaces.js')).default();
  }
};

const Start = () =>
  Widget.Box({
    class_name: "start",
    setup: async box => {
      box.children = [
        await OptionalWorkspaces(),
        SeparatorDot(),
        Widget.Box({ hexpand: true }),
        NotificationIndicator(),
        SeparatorDot(Notifications, (n) => n.notifications.length > 0 || n.dnd),
      ];
    },
  });

const Center = () =>
  Widget.Box({
    class_name: "center",
    children: [DateButton()],
  });

const End = () =>
  Widget.Box({
    class_name: "end",
    children: [
      SeparatorDot(Mpris, (m) => m.players.length > 0),
      MediaIndicator(),
      Widget.Box({ hexpand: true }),

      SubMenu({
        items: submenuItems,
        children: [SysTray(), ColorPicker()],
      }),

      SeparatorDot(),
      ScreenRecord(),
      SeparatorDot(Recorder, (r) => r.recording),
      SystemIndicators(),
    ],
  });

/** @param {number} monitor */
export default (monitor) =>
  Widget.Window({
    name: `bar${monitor}`,
    class_name: "transparent",
    exclusivity: "exclusive",
    monitor,
    binds: [
      [
        "anchor",
        options.bar.position,
        "value",
        (pos) => [pos, "left", "right"],
      ],
    ],
    child: Widget.CenterBox({
      class_name: "panel",
      start_widget: Start(),
      center_widget: Center(),
      end_widget: End(),
    }),
  });
