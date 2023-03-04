local wezterm = require 'wezterm'

return {
  font = wezterm.font 'FiraCode Nerd Font',
  font_size = 10.5,
	use_fancy_tab_bar = false,
  tab_bar_at_bottom = true,
  hide_tab_bar_if_only_one_tab = true,
  window_background_opacity = 0.9,
  text_background_opacity = 0.8,
  window_decorations = "NONE",
  window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
  },
	color_scheme = "Catppuccin Mocha"
}
