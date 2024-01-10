-- default settings
require("mini.align").setup({})
require("mini.cursorword").setup({})
require("mini.comment").setup({})
require("mini.surround").setup({})
--require("mini.tabline").setup({})
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
-- require("config.mini.statusline")
