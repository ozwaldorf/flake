local wezterm = require 'wezterm'

local disabled_new_tab = {
  new_tab = "",
  new_tab_hover = "",
}

--require("bar").setup({})

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
  window_decorations = "NONE",
  window_padding = {
    left = '0.4cell',
    right = '0.4cell',
    top = '0.1cell',
    bottom = '0.1cell',
  },
  color_scheme = "Carburator",
  inactive_pane_hsb = {
    saturation = 1.0,
    brightness = 1.0,
  },
  use_fancy_tab_bar = false,
  tab_bar_at_bottom = false,
  tab_bar_style = disabled_new_tab,
  tab_max_width = 32,
  hide_tab_bar_if_only_one_tab = true,
  default_cursor_style = 'BlinkingBlock'
}
