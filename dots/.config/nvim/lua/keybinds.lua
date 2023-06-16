-- Code navigation and shortcuts
vim.keymap.set("n", "<c-]>", vim.lsp.buf.definition, keymap_opts)
vim.keymap.set("n", "K", vim.lsp.buf.hover, keymap_opts)
vim.keymap.set("n", "gD", vim.lsp.buf.implementation, keymap_opts)
vim.keymap.set("n", "<c-k>", vim.lsp.buf.signature_help, keymap_opts)
vim.keymap.set("n", "1gD", vim.lsp.buf.type_definition, keymap_opts)
vim.keymap.set("n", "gr", vim.lsp.buf.references, keymap_opts)
vim.keymap.set("n", "g0", vim.lsp.buf.document_symbol, keymap_opts)
vim.keymap.set("n", "gW", vim.lsp.buf.workspace_symbol, keymap_opts)
vim.keymap.set("n", "gd", vim.lsp.buf.definition, keymap_opts)
vim.keymap.set("n", "ga", vim.lsp.buf.code_action, keymap_opts)

-- Goto previous/next diagnostic warning/error
vim.keymap.set("n", "g[", vim.diagnostic.goto_prev, keymap_opts)
vim.keymap.set("n", "g]", vim.diagnostic.goto_next, keymap_opts)

-- Tree view
local api = require("nvim-tree.api")
local function open_tree()
    api.tree.toggle({
      find_file = true,
      update_root = true,
    })
end

vim.keymap.set('n', 't', open_tree)

vim.keymap.set('n', 'H', '<Cmd>BufferLineCyclePrev<CR>')
vim.keymap.set('n', 'L', '<Cmd>BufferLineCycleNext<CR>')

-- RustCodeAction
vim.keymap.set('n', '<C-.>', '<Cmd>RustCodeAction<CR>')
vim.keymap.set('i', '<C-.>', '<Cmd>RustCodeAction<CR>')
vim.keymap.set('v', '<C-.>', '<Cmd>RustCodeAction<CR>')

-- Save
vim.keymap.set('n', '<C-s>', '<Esc>:w!<CR>')
vim.keymap.set('i', '<C-s>', '<Esc>:w!<CR>')
vim.keymap.set('v', '<C-s>', '<Esc>:w!<CR>')

-- Copy
vim.keymap.set('n', '<C-c>', '"*y')
vim.keymap.set('i', '<C-c>', '<Esc>"*y')
vim.keymap.set('v', '<C-c>', '"*y')

-- Paste
vim.keymap.set('n', '<C-p>', '"*p')
vim.keymap.set('i', '<C-p>', '<Esc>"*p')
vim.keymap.set('v', '<C-p>', '"*p')

