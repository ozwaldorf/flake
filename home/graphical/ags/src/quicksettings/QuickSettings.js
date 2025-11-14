import Widget from "resource:///com/github/Aylur/ags/widget.js";
import PopupWindow from "../misc/PopupWindow.js";
import { AppMixer, Microhone, SinkSelector, Volume } from "./widgets/Volume.js";
import { NetworkToggle, WifiSelection } from "./widgets/Network.js";
import { BluetoothDevices, BluetoothToggle } from "./widgets/Bluetooth.js";
import { ThemeSelector, ThemeToggle } from "./widgets/Theme.js";
import App from "resource:///com/github/Aylur/ags/app.js";
import Media from "./widgets/Media.js";
import Brightness from "./widgets/Brightness.js";
import DND from "./widgets/DND.js";
import MicMute from "./widgets/MicMute.js";
import Battery from "resource:///com/github/Aylur/ags/service/battery.js";
import PowerMenu from "../services/powermenu.js";
import Avatar from "../misc/Avatar.js";
import options from "../options.js";
import icons from "../icons.js";
import { openSettings } from "../settings/theme.js";
import { uptime } from "../variables.js";

const Row = (toggles = [], menus = []) =>
  Widget.Box({
    vertical: true,
    children: [
      Widget.Box({
        class_name: "row horizontal",
        children: toggles,
      }),
      ...menus,
    ],
  });

const Homogeneous = (toggles) =>
  Widget.Box({
    homogeneous: true,
    children: toggles,
  });

export default () =>
  PopupWindow({
    name: "quicksettings",
    connections: [
      [
        options.bar.position,
        (self) => {
          self.anchor = ["right", options.bar.position.value];
          if (options.bar.position.value === "top") {
            self.transition = "slide_down";
          }

          if (options.bar.position.value === "bottom") {
            self.transition = "slide_up";
          }
        },
      ],
    ],
    child: Widget.Box({
      vertical: true,
      children: [
        Widget.Box({
          class_name: "header horizontal",
          children: [
            Avatar(),
            Widget.Box({
              hpack: "start",
              class_name: "battery horizontal",
              children: [
                Widget.Icon({ binds: [["icon", Battery, "icon-name"]] }),
                Widget.Label({
                  binds: [["label", Battery, "percent", (p) => `${p}%`]],
                }),
              ],
            }),
            Widget.Box({
              hpack: "end",
              vpack: "center",
              hexpand: true,
              children: [
                // Widget.Label({
                //   class_name: "uptime",
                //   binds: [["label", uptime, "value", (v) => `up: ${v}`]],
                // }),
                DND(),
                MicMute(),
                Widget.Button({
                  on_clicked: () => {
                    App.closeWindow("quicksettings");
                    openSettings();
                  },
                  child: Widget.Icon(icons.ui.settings),
                }),
                Widget.Button({
                  on_clicked: () => {
                    App.closeWindow("quicksettings");
                    App.openWindow("powermenu");
                  },
                  child: Widget.Icon(icons.powermenu.shutdown),
                }),
              ],
            }),
          ],
        }),
        Widget.Box({
          class_name: "sliders-box vertical",
          vertical: true,
          children: [
            Row([Volume()], [SinkSelector(), AppMixer()]),
            Microhone(),
            Brightness(),
          ],
        }),
        Row(
          [Homogeneous([NetworkToggle(), BluetoothToggle()])],
          [WifiSelection(), BluetoothDevices()],
        ),
        Row([ThemeToggle()], [ThemeSelector()]),
        Media(),
      ],
    }),
  });
