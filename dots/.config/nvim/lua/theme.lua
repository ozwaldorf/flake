require("catppuccin").setup({
    flavour = "mocha", -- latte, frappe, macchiato, mocha
    background = { -- :h background
        light = "latte",
        dark = "mocha",
    },
    transparent_background = true,
    show_end_of_buffer = false, -- show the '~' characters after the end of buffers
    term_colors = true,
    dim_inactive = {
        enabled = false,
        shade = "dark",
        percentage = 0.15,
    },
    no_italic = false, -- Force no italic
    no_bold = false, -- Force no bold
    styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        loops = {},
        functions = {},
        keywords = {},
        strings = {},
        variables = {},
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
    },
    color_overrides = {},
    custom_highlights = {},
    integrations = {
        --bufferline = true,
        --barbar = true,
        aerial = true,
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        telescope = true,
        notify = true,
        mini = false,
        noice = true,
        -- For more plugins integrations please scroll down (https://github.com/catppuccin/nvim#integrations)
    },
})

-- setup must be called before loading
vim.cmd.colorscheme "catppuccin"

vim.opt.guifont = { "FiraCode Mono Nerd Font", "h4" }

--require("notify").setup({
--  background_colour = "#000000",
--})

require("startup").setup({theme = "dashboard"})

require("bufferline").setup {
  options = {
    theme = "catppuccin",
    separator_style = "thin",
    offsets = {                       
      {
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

-- OR setup with some options
require("nvim-tree").setup({
  sort_by = "case_sensitive",
  view = {
    hide_root_folder = true,
    width = 30,
    mappings = {
      list = {
        { key = "u", action = "dir_up" },
      },
    },
  },
  renderer = {
    group_empty = true,
  },
  filters = {
    dotfiles = false,
  },
  tab = {
    sync = {
      open = true,
      close = true,
      ignore = {},
    },
  },
})

require("gitsigns").setup({
  signs = {
    add          = { text = '│' },
    change       = { text = '│' },
    delete       = { text = '_' },
    topdelete    = { text = '‾' },
    changedelete = { text = '~' },
    untracked    = { text = '┆' },
  },
  signcolumn = true,  -- Toggle with `:Gitsigns toggle_signs`
  numhl      = false, -- Toggle with `:Gitsigns toggle_numhl`
  linehl     = false, -- Toggle with `:Gitsigns toggle_linehl`
  word_diff  = false, -- Toggle with `:Gitsigns toggle_word_diff`
  watch_gitdir = {
    interval = 1000,
    follow_files = true
  },
  attach_to_untracked = true,
  current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
  current_line_blame_opts = {
    virt_text = true,
    virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
    delay = 1000,
    ignore_whitespace = false,
  },
  current_line_blame_formatter = '<author>, <author_time:%Y-%m-%d> - <summary>',
  sign_priority = 6,
  update_debounce = 100,
  status_formatter = nil, -- Use default
  max_file_length = 40000, -- Disable if file is longer than this (in lines)
  preview_config = {
    -- Options passed to nvim_open_win
    border = 'single',
    style = 'minimal',
    relative = 'cursor',
    row = 0,
    col = 1
  },
  yadm = {
    enable = false
  },
})

require("aerial").setup({
  -- optionally use on_attach to set keymaps when aerial has attached to a buffer
  on_attach = function(bufnr)
    -- Jump forwards/backwards with '{' and '}'
    vim.keymap.set('n', '{', '<cmd>AerialPrev<CR>', {buffer = bufnr})
    vim.keymap.set('n', '}', '<cmd>AerialNext<CR>', {buffer = bufnr})
  end,
  open_automatic = true
})
-- You probably also want to set a keymap to toggle aerial
vim.keymap.set('n', '<leader>a', '<cmd>AerialToggle!<CR>')

local empty = require('lualine.component'):extend()
function empty:draw(default_highlight)
  self.status = ''
  self.applied_separator = ''
  self:apply_highlights(default_highlight)
  self:apply_section_separators()
  return self.status
end

require("lualine").setup({
    options = {
      icons_enabled = true,
      theme = "catppuccin",
      globalstatus = true,
      modifiable = true,
      component_separators = { left = "", right = ""},
		  section_separators = { left = "", right = "" },
      disabled_filetypes = {
		  	statusline = {},
			  winbar = {},
		  },
		  ignore_focus = {},
		  always_divide_middle = true,
    },
    sections = {
	   	lualine_a = { 
        { "mode", separator = { left = ' ', right = '' }, right_padding = 0 },
        { empty, color = { fg = "#fff", bg = "#fff" } }
      },
	    lualine_c = { "branch", "diff", "diagnostics" },
      lualine_b = { "filename" },
		  lualine_x = { "encoding", "progress" },
		  lualine_y = { "filetype" },
	    lualine_z = { { "location", separator = { right = '' }, left_padding = 2 } },
    },
	  inactive_sections = {
	    lualine_a = {},
	    lualine_b = {},
		  lualine_c = { "filename" },
		  lualine_x = { "location" },
	    lualine_y = {},
	    lualine_z = {},
	  },
	  tabline = {},
	  winbar = {},
	  inactive_winbar = {},
    extensions = {"nvim-tree"},
})

require("nvim-autopairs").setup({
  disable_filetype = { "TelescopePrompt", "vim" },
})

require("noice").setup({
  lsp = {
    -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
      ["cmp.entry.get_documentation"] = true,
    },
  },
  -- you can enable a preset for easier configuration
  presets = {
    bottom_search = false, -- use a classic bottom cmdline for search
    command_palette = true, -- position the cmdline and popupmenu together
    long_message_to_split = true, -- long messages will be sent to a split
    inc_rename = false, -- enables an input dialog for inc-rename.nvim
    lsp_doc_border = true, -- add a border to hover docs and signature help
  },
})

-- Tab size
vim.o.expandtab = true
vim.o.smartindent = true
vim.o.tabstop = 2
vim.o.shiftwidth = 2

-- Line numbers
-- Relative in normal mode, exact in insert mode
vim.wo.number = true
vim.opt.relativenumber = true

isNvimTree = function()
  return vim.fn.expand('%'):find("^NvimTree") ~= nil
end
vim.api.nvim_create_autocmd("InsertEnter", {
  callback = function()
    if not isNvimTree() then
      vim.opt.relativenumber = false
    end
  end,
})
vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function() 
    if not isNvimTree() then
      vim.opt.relativenumber = true
    end
  end,
})

