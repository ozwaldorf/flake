local wezterm = require 'wezterm'

require("bar").setup({})

return {
  font = wezterm.font 'FiraCode Nerd Font',
  font_size = 10,
	use_fancy_tab_bar = false,
  tab_bar_at_bottom = false,
  tab_max_width = 32,
  hide_tab_bar_if_only_one_tab = true,
  window_background_opacity = 0.9,
  text_background_opacity = 1.0,
  tab_bar_style = {
    new_tab = wezterm.format({
      { Foreground = { Color = "#181825" } },
      { Background = { Color = "rgba(0,0,0,0)" } },
      { Text = " " .. utf8.char(0xe0b6) },
      { Foreground = { Color = "#cdd6f4" } },
      { Background = { Color = "#181825" } }, 
      { Text = "+" },
      { Foreground = { Color = "#181825" } },
      { Background = { Color = "rgba(0,0,0,0)" } }, 
      { Text = utf8.char(0xe0b4) }
    }),
    new_tab_hover = wezterm.format({ 
        { Foreground = { Color = "#181825" } },
        { Background = { Color = "rgba(0,0,0,0)" } },
        { Text = " " .. utf8.char(0xe0b6) },
        { Foreground = { Color = "#cdd6f4" } },
        { Background = { Color = "#181825" } }, 
        { Attribute = { Italic = false } },
        { Text = "+" },
        { Foreground = { Color = "#181825" } },
        { Background = { Color = "rgba(0,0,0,0)" } }, 
        { Text = utf8.char(0xe0b4) }
      }) 
  },
  window_decorations = "NONE",
  window_padding = {
    left = '1cell',
    right = '1cell',
    top = '0.5cell',
    bottom = '0.5cell',
  },
	color_scheme = "Catppuccin Mocha",
  colors = {
    tab_bar = {
      background = 'rgba(17,17,27,0.0)'
    }
  }
}
