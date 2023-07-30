-- default settings
require("mini.cursorword").setup({})
require("mini.comment").setup({})
require("mini.surround").setup({})
require("mini.tabline").setup({})
-- require("mini.completion").setup({
--   window = {
--     info = { height = 25, width = 80, border = { "╔", "═", "╗", "║", "╝", "═", "╚", "║" } },
--     signature = { height = 25, width = 80, border = { "╔", "═", "╗", "║", "╝", "═", "╚", "║" } },
--   },
-- })
require("mini.indentscope").setup({})
require("mini.pairs").setup({})
require("mini.jump2d").setup({
  mappings = {
    start_jumping = "J",
  },
})
require("mini.bufremove").setup({})
require("mini.doc").setup({})
require("mini.ai").setup({})

-- custom settings
require("config.mini.starter")
require("config.mini.statusline")
