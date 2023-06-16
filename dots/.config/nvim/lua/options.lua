vim.cmd "set noshowcmd"
vim.cmd "set noshowmode"

-- disable netrw at the very start of your init.lua (strongly advised)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true

-- wrap to prev/next line with arrow keys
vim.o.whichwrap = 'b,s,<,>,[,]'

