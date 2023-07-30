require("nvim-treesitter.configs").setup({
  ensure_installed = { "lua", "python", "rust" },
  highlight = {
    enable = true,
  },
})
