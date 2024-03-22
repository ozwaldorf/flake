local wezterm = require 'wezterm'

local tab_colors = {
  "Navy", "Red", "Green", "Olive", "Maroon", "Purple", "Teal", "Lime", "Yellow", "Blue", "Fuchsia", "Aqua"
}
local tab_bg = "rgba(22,22,22,0.8)"

wezterm.on(
  'format-tab-title',
  function(tab)
    if tab.is_active then
      local accent = tab_colors[(tab.tab_index % #tab_colors) + 1]
      return wezterm.format({
        { Background = { Color = tab_bg } },
        { Foreground = { AnsiColor = accent } },
        { Text = ' ' .. wezterm.nerdfonts.ple_left_half_circle_thick },
        { Background = { AnsiColor = accent } },
        { Foreground = { Color = tab_bg } },
        { Text = tostring(tab.tab_index) },
        { Background = { Color = tab_bg } },
        { Foreground = { AnsiColor = accent } },
        { Text = wezterm.nerdfonts.ple_right_half_circle_thick },
      })
    else
      return ' ' .. tab.tab_index
    end
  end
)

return {
  font = wezterm.font_with_fallback {
    'Berkeley Mono',
    --'Dank Mono',
    --'Gintronic',
    --'PragmataPro Mono Liga',
    --'Fira Code Nerd Font',
    'Symbols Nerd Font',
  },
  font_size = 10,
  window_background_opacity = 0.8,
  text_background_opacity = 1.0,
  -- window_decorations = "NONE",
  window_padding = {
    left = '4.5cell',
    right = '4.0cell',
    top = '2.2cell',
    bottom = '2.0cell',
  },
  color_scheme = "Carburator",
  inactive_pane_hsb = {
    saturation = 1.0,
    brightness = 1.0,
  },
  use_fancy_tab_bar = false,
  tab_bar_at_bottom = false,
  colors = {
    tab_bar = {
      active_tab = { bg_color = tab_bg, fg_color = "#f4f4f4" },
      inactive_tab = { bg_color = tab_bg, fg_color = "#f4f4f4" },
      inactive_tab_hover = { bg_color = tab_bg, fg_color = "#f4f4f4", italic = false }
    }
  },
  tab_bar_style = {
    new_tab = "",
    new_tab_hover = ""
  },
  tab_max_width = 32,
  hide_tab_bar_if_only_one_tab = true,
  default_cursor_style = 'BlinkingBlock',
  warn_about_missing_glyphs = false
}
