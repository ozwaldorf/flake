import TopBar from "./bar/TopBar.js";
import Dashboard from "./dashboard/Dashboard.js";
import QuickSettings from "./quicksettings/QuickSettings.js";
import AppLauncher from "./applauncher/Applauncher.js";
import PowerMenu from "./powermenu/PowerMenu.js";
import Verification from "./powermenu/Verification.js";
import Desktop from "./desktop/Desktop.js";
import Notifications from "./notifications/Notifications.js";
import { init } from "./settings/setup.js";
import { forMonitors } from "./utils.js";
import options from "./options.js";

const windows = () => [
  forMonitors(TopBar),
  forMonitors(Desktop),
  forMonitors(Notifications),
  QuickSettings(),
  Dashboard(),
  AppLauncher(),
  PowerMenu(),
  Verification(),
];

export default {
  onConfigParsed: init,
  windows: windows().flat(1),
  maxStreamVolume: 1.0,
  cacheNotificationActions: false,
  closeWindowDelay: {
    quicksettings: options.transition.value,
    dashboard: options.transition.value,
  },
};
