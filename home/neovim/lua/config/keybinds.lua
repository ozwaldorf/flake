-- Save
vim.keymap.set({ 'n', 'i', 'v' }, '<C-s>', '<Esc>:w!<CR>')

-- Tree view
local api = require("nvim-tree.api")
local function open_tree()
  api.tree.toggle({
    find_file = true,
    update_root = true,
  })
end
vim.keymap.set('n', 't', open_tree)
vim.keymap.set('n', 'T', "<Esc>:SymbolsOutline<CR>")
vim.keymap.set('n', 'B', "<Esc>:ToggleBlame window<CR>")
