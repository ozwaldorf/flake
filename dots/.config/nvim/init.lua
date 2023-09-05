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
    "akinsho/bufferline.nvim",
    config = function()
      require("bufferline").setup {
        options = {
          theme = "catppuccin",
          separator_style = { "│", "│" },
          offsets = { {
            filetype = "NvimTree",
            --text = function()
            --  return vim.fn.getcwd()
            --end,
            text = "File Explorer",
            highlight = "Directory",
            separator = "│"
          }
          }
        }
      }
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
    "onsails/lspkind.nvim",
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
  use {
    "cshuaimin/ssr.nvim",
    module = "ssr",
    -- Calling setup is optional.
    config = function()
      require("ssr").setup {
        border = "rounded",
        min_width = 50,
        min_height = 5,
        max_width = 120,
        max_height = 25,
        keymaps = {
          close = "q",
          next_match = "n",
          prev_match = "N",
          replace_confirm = "<cr>",
          replace_all = "<leader><cr>",
        },
      }
    end
  }
  use({
    'simrat39/symbols-outline.nvim',
    config = function()
      require("symbols-outline").setup()
      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'Outline' },
        command = "setlocal nospell"
      })
    end
  })
  use({
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("todo-comments").setup()
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
    "lewis6991/gitsigns.nvim",
    config = function()
      require('gitsigns').setup()
    end
  })
  use({
    "petertriho/nvim-scrollbar",
    config = function()
      require("scrollbar").setup({
        handlers = {
          handle = false,
          gitsigns = true,
        },
        excluded_filetypes = {
          "Outline",
          "NvimTree",
          "starter",
          "NeogitStatus",
        },
      })
    end
  })
  use({
    'krivahtoo/silicon.nvim',
    branch = 'nvim-0.9',
    run = './install.sh build',
    config = function()
      require('silicon').setup({
        font = 'Dank Mono; Symbols Nerd Font',
        -- https://raw.githubusercontent.com/catppuccin/bat/main/Catppuccin-mocha.tmTheme
        -- download and run: `silicon --build-cache`
        theme = 'Catppuccin-mocha',
        gobble = true,
        line_number = true,
        line_pad = 0,
        pad_horiz = 18,
        pad_vert = 20,
        shadow = {
          blur_radius = 3,
          color = '#00000055'
        },
        background = "#00000000",
        window_title = function()
          local file, _ = string.gsub(vim.fn.expand('%'), vim.loop.cwd() .. '/', '')
          return file
        end,
        watermark = {
          text = '@ozwaldorf ',
          color = '#cdd6f4',
          style = 'italic'
        }
      })
    end
  })
  use({
    "catppuccin/nvim",
    as = "catppuccin",
    config = function()
      require("catppuccin").setup({
        transparent_background = false,
        integrations = {
          mini = true,
          bufferline = true,
          mason = true,
          cmp = true,
          lsp_trouble = true,
          nvimtree = true,
          treesitter = true,
          symbols_outline = true,
          gitsigns = true,
          neogit = true,
          fidget = true,
        },
        color_overrides = {
          -- Carburetor
          mocha = {
            rosewater = "#ffd7d9",
            flamingo = "#ffb3b8",
            pink = "#ff7eb6",
            mauve = "#d4bbff",
            red = "#fa4d56",
            maroon = "#ff8389",
            peach = "#ff832b",
            yellow = "#fddc69",
            green = "#42be65",
            teal = "#3ddbd9",
            sky = "#82cfff",
            sapphire = "#78a9ff",
            blue = "#4589ff",
            lavender = "#be95ff",
            text = "#f4f4f4",
            subtext1 = "#e0e0e0",
            subtext0 = "#c6c6c6",
            overlay2 = "#a8a8a8",
            overlay1 = "#8d8d8d",
            overlay0 = "#6f6f6f",
            surface2 = "#525252",
            surface1 = "#393939",
            surface0 = "#262626",
            base = "#161616",
            mantle = "#0b0b0b",
            crust = "#000000"
          },
        }
      })
      vim.cmd.colorscheme "catppuccin"
    end,
  })
  use({
    "brenoprata10/nvim-highlight-colors",
    config = function()
      require("nvim-highlight-colors").setup()
    end
  })
  use({ 'wakatime/vim-wakatime' })

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
require("config.keybinds")
-- require("config.wakadash")

-- disable ~ for empty lines
vim.opt.fillchars = { eob = " " }

-- for spell checking
vim.opt.spell = true
vim.opt.spelllang = { "en_us" }
vim.opt.spelloptions = 'camel'
