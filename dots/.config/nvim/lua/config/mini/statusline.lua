local function lsp_clients()
  local buf_clients = vim.lsp.buf_get_clients()
  if next(buf_clients) == nil then
    return ""
  end
  local buf_client_names = {}
  for _, client in pairs(buf_clients) do
    if client.name ~= "null-ls" then
      table.insert(buf_client_names, client.name)
    end
  end
  return "[" .. table.concat(buf_client_names, ", ") .. "]"
end

vim.api.nvim_set_hl(0, "MiniStatuslineLspClient", {})

local function status_line()
  local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
  local git = MiniStatusline.section_git({ trunc_width = 75 })
  local diagnostics = MiniStatusline.section_diagnostics({ trunc_width = 75 })
  local clients = lsp_clients()

  local fileinfo = MiniStatusline.section_fileinfo({ trunc_width = 120 })
  local location = MiniStatusline.section_location({ trunc_width = 75 })
  return MiniStatusline.combine_groups({
    { hl = mode_hl,                 strings = { mode } },
    { hl = "MiniStatuslineDevinfo", strings = { git, diagnostics } },
    "%<",
    { hl = "MiniStatuslineLspClient", strings = { clients } },
    { hl = "MiniStatuslineLspClient", strings = {} },
    "%=",
    { hl = "MiniStatuslineFileinfo", strings = { fileinfo } },
    { hl = mode_hl,                  strings = { location } },
  })
end

local opts = {
  content = {
    active = status_line,
    inactive = nil,
  },
  use_icons = true,
  set_vim_settings = false,
}
require("mini.statusline").setup(opts)
