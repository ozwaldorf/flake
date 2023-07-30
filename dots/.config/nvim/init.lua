-- Mostly based off of https://github.com/alpha2phi/neovim-for-minimalist, licensed under MIT.

local cmd = vim.cmd
local fn = vim.fn
local api = vim.api

-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Global object
_G.NVMM = {}

local packer_bootstrap = false -- Indicate first time installation

-- packer.nvim configuration
local conf = {
  profile = {
    enable = true,
    threshold = 0, -- the amount in ms that a plugins load time must be over for it to be included in the profile
  },

  display = {
    open_fn = function()
      return require("packer.util").float({ border = "rounded" })
    end,
  },
}

local function packer_init()
  -- Check if packer.nvim is installed
  local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
  if fn.empty(fn.glob(install_path)) > 0 then
    packer_bootstrap = fn.system({
      "git",
      "clone",
      "--depth",
      "1",
      "https://github.com/wbthomason/packer.nvim",
      install_path,
    })
    cmd([[packadd packer.nvim]])
  end

  -- Run PackerCompile if there are changes in this file
  local packerGrp = api.nvim_create_augroup("packer_user_config", { clear = true })
  api.nvim_create_autocmd(
    { "BufWritePost" },
    { pattern = "init.lua", command = "source <afile> | PackerCompile", group = packerGrp }
  )
end

-- Plugins
local function plugins(use)
  use({ "wbthomason/packer.nvim" })
  use({ "kyazdani42/nvim-web-devicons" })
  use({ "nvim-lua/plenary.nvim" })
  use({
    "TimUntersberger/neogit",
    cmd = { "Neogit" },
    config = function()
      require("neogit").setup({})
    end,
  })
  use({
    "echasnovski/mini.nvim",
    config = function()
      require("config.mini")
    end,
  })
  use({
    "neovim/nvim-lspconfig",
    --event = "BufReadPre",
    requires = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      require("config.lsp")
    end,
  })
  use({
    "j-hui/fidget.nvim",
    config = function()
      require("fidget").setup({
        window = { blend = 0 },
        text = {
          spinner = "flip",
          done = "",
        },
      })
    end
  })
  -- Autocompletion framework
  use({
    "hrsh7th/nvim-cmp",
    config = function()
      require("config.cmp")
    end
  })
  use({
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-vsnip",
    "hrsh7th/vim-vsnip",
    after = { "hrsh7th/nvim-cmp" },
    requires = { "hrsh7th/nvim-cmp" },
  })
  use({ 'simrat39/rust-tools.nvim' })
  use {
    'saecki/crates.nvim',
    tag = 'v0.3.0',
    requires = { 'nvim-lua/plenary.nvim' },
    config = function()
      require("crates").setup({})
    end,
  }
  use({
    "nvim-treesitter/nvim-treesitter",
    run = ":TSUpdate",
    config = function()
      require("config.treesitter")
    end,
  })
  use({ "nvim-treesitter/playground" })
  use({
    'simrat39/symbols-outline.nvim',
    config = function()
      require("symbols-outline").setup()
    end
  })
  use({
    'nvim-tree/nvim-tree.lua',
    requires = {
      'nvim-tree/nvim-web-devicons', -- optional
    },
    config = function()
      require("nvim-tree").setup()
    end,
  })
  use({
    "catppuccin/nvim",
    as = "catppuccin",
    config = function()
      require("catppuccin").setup({
        transparent_background = true,
        integrations = {
          mini = true
        },
      })
      vim.cmd.colorscheme "catppuccin"
    end,
  })
  use({
    "lewis6991/gitsigns.nvim",
    config = function()
      require('gitsigns').setup()
    end
  })
  --use({ "" })

  -- Bootstrap Neovim
  if packer_bootstrap then
    print("Neovim restart is required after installation!")
    require("packer").sync()
  end
end

-- packer.nvim
packer_init()
local packer = require("packer")
packer.init(conf)
packer.startup(plugins)

-- keybindings
require("config.keybinds");
