require("nvim-treesitter.configs").setup({
  ensure_installed = { "lua", "python", "rust", "bash" },
  highlight = {
    enable = true,
  },
})
