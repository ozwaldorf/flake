/**
 * A Theme is a set of options that will be applied
 * ontop of the default values. see options.js for possible options
 */
import { lightColors, Theme, WP } from "./settings/theme.js";

export default [
  Theme({
    name: "Carburetor",
    "spacing": 16,
    "padding": 18,
    "radii": 30,
    "popover_padding_multiplier": 1,
    "color.red": "#fa4d56",
    "color.green": "#42be65",
    "color.yellow": "#fddc69",
    "color.blue": "#4589ff",
    "color.magenta": "#be95ff",
    "color.teal": "#3ddbd9",
    "color.orange": "#ff832b",
    "theme.scheme": "dark",
    "theme.bg": "#161616",
    "theme.fg": "#f4f4f4",
    "theme.accent.accent": "$blue",
    "theme.accent.fg": "#f4f4f4",
    "theme.accent.gradient": "to right, $accent, lighten($accent, 6%)",
    "theme.widget.bg": "$fg-color",
    "theme.widget.opacity": 94,
    "border.color": "$fg-color",
    "border.opacity": 100,
    "border.width": 0,
    "hypr.inactive_border": "rgba(333333ff)",
    "hypr.wm_gaps_multiplier": 2,
    "font.font": "Cantarell 10",
    "font.mono": "Berkeley Mono Regular",
    "font.size": 12,
    "applauncher.width": 500,
    "applauncher.height": 500,
    "applauncher.icon_size": 52,
    "bar.position": "top",
    "bar.style": "normal",
    "bar.flat_buttons": true,
    "bar.separators": false,
    "bar.icon": "distro-icon",
    "battery.bar.width": 50,
    "battery.bar.height": 13,
    "battery.bar.full": false,
    "battery.low": 30,
    "battery.medium": 50,
    "desktop.wallpaper.fg": "#fff",
    "desktop.avatar": "/home/oz/.config/term.png",
    "desktop.screen_corners": false,
    "desktop.clock.enable": true,
    "desktop.clock.position": "center center",
    "desktop.drop_shadow": true,
    "desktop.shadow": "rgba(0, 0, 0, .6)",
    "desktop.dock.icon_size": 56,
    "desktop.dock.pinned_apps": [
      "firefox",
      "org.wezfurlong.wezterm",
      "org.gnome.Nautilus",
      "org.gnome.Calendar",
      "obsidian",
      "transmission-gtk",
      "caprine",
      "teams-for-linux",
      "discord",
      "spotify",
      "com.usebottles.bottles",
      "org.gnome.Software",
    ],
    "notifications.black_list": [
      "Spotify",
    ],
    "notifications.position": [
      "bottom",
    ],
    "notifications.width": 550,
    "dashboard.sys_info_size": 70,
    "mpris.black_list": [
      "Caprine",
    ],
    "mpris.preferred": "spotify",
    "workspaces": 7,
  }),
];