local keymap = vim.keymap.set
local api = vim.api

----------------- LSP servers --------------------------
local servers = {
  pyright = {
    settings = {
      python = {
        analysis = {
          typeCheckingMode = "off",
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          diagnosticMode = "workspace",
        },
      },
    },
  },
  lua_ls = {
    settings = {
      Lua = {
        diagnostics = { globals = { 'vim' } }
      }
    }
  }
}

-------------- LSP functions --------------------------

local function keymappings(_, bufnr)
  local opts = { noremap = true, silent = true }

  keymap("n", "K", vim.lsp.buf.hover, { buffer = bufnr })
  keymap("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
  keymap("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)
  keymap("n", "[e", "<cmd>lua vim.diagnostic.goto_prev({severity = vim.diagnostic.severity.ERROR})<CR>", opts)
  keymap("n", "]e", "<cmd>lua vim.diagnostic.goto_next({severity = vim.diagnostic.severity.ERROR})<CR>", opts)

  keymap("n", "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", opts)
  keymap("n", "gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts)
  keymap("n", "gh", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
  keymap("n", "gI", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
  keymap("n", "gb", "<cmd>lua vim.lsp.buf.type_definition()<CR>", opts)

  api.nvim_set_keymap("i", "<Tab>", [[pumvisible() ? "\<C-n>" : "\<Tab>"]], { noremap = true, expr = true })
  api.nvim_set_keymap("i", "<S-Tab>", [[pumvisible() ? "\<C-p>" : "\<S-Tab>"]], { noremap = true, expr = true })
end

local function highlighting(client, bufnr)
  if client.server_capabilities.documentHighlightProvider then
    local lsp_highlight_grp = api.nvim_create_augroup("LspDocumentHighlight", { clear = true })
    api.nvim_create_autocmd("CursorHold", {
      callback = function()
        vim.schedule(vim.lsp.buf.document_highlight)
      end,
      group = lsp_highlight_grp,
      buffer = bufnr,
    })
    api.nvim_create_autocmd("CursorMoved", {
      callback = function()
        vim.schedule(vim.lsp.buf.clear_references)
      end,
      group = lsp_highlight_grp,
      buffer = bufnr,
    })
  end
end

local function lsp_handlers()
  local diagnostics = {
    Error = "",
    Hint = "",
    Information = "",
    Question = "",
    Warning = "",
  }
  local signs = {
    { name = "DiagnosticSignError", text = diagnostics.Error },
    { name = "DiagnosticSignWarn",  text = diagnostics.Warning },
    { name = "DiagnosticSignHint",  text = diagnostics.Hint },
    { name = "DiagnosticSignInfo",  text = diagnostics.Info },
  }
  for _, sign in ipairs(signs) do
    vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = sign.name })
  end

  -- LSP handlers configuration
  local config = {
    float = {
      focusable = true,
      style = "minimal",
      border = "rounded",
    },

    diagnostic = {
      virtual_text = {
        source = "always",
      }, --severity = vim.diagnostic.severity.ERROR },
      signs = {
        active = signs,
      },
      underline = true,
      update_in_insert = true,
      severity_sort = true,
      float = {
        focusable = true,
        style = "minimal",
        border = "single",
        source = "always",
        header = "",
        prefix = "",
      },
    },
  }

  vim.diagnostic.config(config.diagnostic)
  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, config.float)
  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, config.float)

  -- Show diagnostic popup on cursor hover
  local diag_float_grp = vim.api.nvim_create_augroup("DiagnosticFloat", { clear = true })
  vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
      vim.diagnostic.open_float(nil, { focusable = false })
    end,
    group = diag_float_grp,
  })
end

local function formatting(client, bufnr)
  if client.server_capabilities.documentFormattingProvider then
    local function format()
      local view = vim.fn.winsaveview()
      vim.lsp.buf.format({
        async = true,
        filter = function(attached_client)
          return attached_client.name ~= ""
        end,
      })
      vim.fn.winrestview(view)
    end

    local lsp_format_grp = api.nvim_create_augroup("LspFormat", { clear = true })
    api.nvim_create_autocmd("BufWritePre", {
      callback = function()
        vim.schedule(format)
      end,
      group = lsp_format_grp,
      buffer = bufnr,
    })
  end
end

local function on_attach(client, bufnr)
  -- api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
  -- api.nvim_buf_set_option(bufnr, "completefunc", "v:lua.vim.lsp.omnifunc")
  api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.MiniCompletion.completefunc_lsp")
  api.nvim_buf_set_option(bufnr, "completefunc", "v:lua.MiniCompletion.completefunc_lsp")

  api.nvim_buf_set_option(bufnr, "formatexpr", "v:lua.vim.lsp.formatexpr()")
  if client.server_capabilities.definitionProvider then
    api.nvim_buf_set_option(bufnr, "tagfunc", "v:lua.vim.lsp.tagfunc")
  end

  keymappings(client, bufnr)
  highlighting(client, bufnr)
  formatting(client, bufnr)
  -- signature_help(client, bufnr)
end

----------------------------- LSP Setup -------------------------
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

lsp_handlers()

local server_opts = {
  on_attach = on_attach,
  capabilities = capabilities,
  flags = {
    debounce_text_changes = 150,
  },
}

require("mason").setup({
  ui = { border = 'rounded' }
})

require("mason-lspconfig").setup({
  ensure_installed = vim.tbl_keys(servers),
  automatic_installation = false,
})

local lspconfig = require("lspconfig")

require("mason-lspconfig").setup_handlers({
  function(server_name)
    if server_name == "rust_analyzer" then
      local rt = require("rust-tools")
      local rust_opts = {
        tools = {
          runnables = {
            use_telescope = false,
          },
          inlay_hints = {
            auto = true,
            show_parameter_hints = false,
            parameter_hints_prefix = "",
            other_hints_prefix = "",
          },
        },
        server = {
          on_attach = function(client, bufnr)
            on_attach(client, bufnr)
            vim.keymap.set({ 'n', 'i' }, '<C-.>', '<Cmd>RustCodeAction<CR>')
            vim.keymap.set({ 'n', 'i' }, "<C-space>", rt.hover_actions.hover_actions, { buffer = bufnr })
            vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, { buffer = bufnr })
            --require 'illuminate'.on_attach(client)
          end,
          capabilities = capabilities,
          settings = {
            ['rust-analyzer'] = {
              check = {
                command = "clippy"
              }
            }
          }
        }
      }
      rt.setup(rust_opts)
    else
      local extended_opts = vim.tbl_deep_extend("force", server_opts, servers[server_name] or {})
      lspconfig[server_name].setup(extended_opts)
    end
  end,
  -- You can set up other server specific config
})
