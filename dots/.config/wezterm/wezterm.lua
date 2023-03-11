local wezterm = require 'wezterm'

require("bar").setup({
  dividers = false, -- or "slant_left", "arrows", "rounded", false
  indicator = {
    leader = {
      enabled = true,
      off = " ",
      on = " ",
    },
    mode = {
      enabled = true,
      names = {
        resize_mode = "RESIZE",
        copy_mode = "VISUAL",
        search_mode = "SEARCH",
      },
    },
  },
  tabs = {
    numerals = "arabic", -- or "roman"
    pane_count = "superscript", -- or "subscript", false
    brackets = {
      active = { "", "." },
      inactive = { "", "." },
    },
  },
  clock = { -- note that this overrides the whole set_right_status
    enabled = true,
    format = "%H:%M:%S", -- use https://wezfurlong.org/wezterm/config/lua/wezterm.time/Time/format.html
  },
})

return {
  font = wezterm.font 'FiraCode Nerd Font',
  font_size = 10,
	use_fancy_tab_bar = false,
  tab_bar_at_bottom = true,
  hide_tab_bar_if_only_one_tab = true,
  window_background_opacity = 0.9,
  text_background_opacity = 1.0,
  window_decorations = "NONE",
  window_padding = {
    left = 5,
    right = 5,
    top = 5,
    bottom = 5,
  },
	color_scheme = "Catppuccin Mocha"
}
