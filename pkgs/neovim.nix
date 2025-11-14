{ inputs, pkgs }:

# Standalone neovim package
inputs.nixvim.legacyPackages.${pkgs.system}.makeNixvimWithModule {
  inherit pkgs;
  module = {
    config = {
      clipboard.providers.wl-copy.enable = true;

      opts = {
        tabstop = 2;
        shiftwidth = 2;
        expandtab = true;
        mouse = "a";
        number = true;
        undofile = true;
        foldenable = false;
      };

      keymaps = [
        {
          # Toggle nvim tree
          key = "t";
          action = "<cmd>NvimTreeToggle<CR>";
          mode = [ "n" ];
        }
        {
          # Toggle trouble window with all current lsp errors
          key = "T";
          action = "<cmd>Trouble diagnostics toggle<CR>";
          mode = [ "n" ];
        }
        {
          # Show hover actions
          key = "K";
          action.__raw = "vim.lsp.buf.hover";
          mode = [ "n" ];
        }
        {
          # Next buffer (tab)
          key = "gt";
          action = "<cmd>bn<CR>";
          mode = [ "n" ];
        }
        {
          # Previous buffer (tab)
          key = "gT";
          action = "<cmd>bp<CR>";
          mode = [ "n" ];
        }
        {
          # Toggle git diff overlay0
          key = "go";
          action.__raw = "MiniDiff.toggle_overlay";
          mode = [ "n" ];
        }
        {
          # Jump definition
          key = "gd";
          action.__raw = "vim.lsp.buf.definition";
          mode = [ "n" ];
        }
        {
          # Jump declaration
          key = "gD";
          action.__raw = "vim.lsp.buf.declaration";
          mode = [ "n" ];
        }
        {
          # Jump implementation
          key = "gi";
          action.__raw = "vim.lsp.buf.implementation";
          mode = [ "n" ];
        }
        {
          # References
          key = "gr";
          action.__raw = "vim.lsp.buf.references";
          mode = [ "n" ];
        }
        {
          # Rename
          key = "gR";
          action.__raw = "vim.lsp.buf.rename";
          mode = [ "n" ];
        }
        {
          # Format
          key = "gf";
          action.__raw = "vim.lsp.buf.format";
          mode = [ "n" ];
        }
        {
          # Next diagnostic
          key = "gn";
          action.__raw = "vim.diagnostic.goto_next";
          mode = [ "n" ];
        }
        {
          # Previous diagnostic
          key = "gN";
          action.__raw = "vim.diagnostic.goto_prev";
          mode = [ "n" ];
        }
        {
          # Show code actions
          key = "<C-.>";
          action.__raw = ''require("actions-preview").code_actions'';
          mode = [
            "n"
            "v"
            "i"
          ];
        }
        {
          # Ctrl-S save and escape
          key = "<C-s>";
          action = "<Esc>:w!<CR>";
          mode = [
            "n"
            "v"
            "i"
          ];
        }
        {
          # Jump forward if completing a snippet (ie, function parameter placeholders)
          key = "<Tab>";
          action.__raw = ''
            function()
              if vim.snippet.active(1) then
                return '<cmd>lua vim.snippet.jump(1)<cr>'
              else
                return '<Tab>'
              end
            end
          '';
          mode = [
            "s"
            "i"
          ];
          options.expr = true;
        }
        {
          # Jump backwards if completing a snippet
          key = "<S-Tab>";
          action.__raw = ''
            function()
              if vim.snippet.jumpable("-1") then
                return '<cmd>lua vim.snippet.jump(-1)<cr>'
              else
                return '<Tab>'
              end
            end
          '';
          mode = [
            "s"
            "i"
          ];
          options.expr = true;
        }
      ];

      autoCmd = [
        {
          event = "TermOpen";
          command = "setlocal nonumber norelativenumber";
        }
      ];

      extraConfigLuaPre = ''
        require("flatten").setup()

        local symbols = { Error = "󰅙", Info = "󰋼", Hint = "󰌵", Warn = "" }
        for name, icon in pairs(symbols) do
        	local hl = "DiagnosticSign" .. name
        	vim.fn.sign_define(hl, { text = icon, numhl = hl, texthl = hl })
        end

        vim.diagnostic.config {
          float = { border = "rounded" },
        }
      '';

      extraConfigLua = ''
        require("scrollbar").setup({
          handlers = {
            cursor = true,
            handle = false,
            diagnostic = true,
            gitsigns = true,
          },
          excluded_filetypes = {
            "NvimTree",
            "starter",
          },
          marks = {
            Cursor = { text = "█" },
            Error = { text = { symbols.Error } },
            Warn = { text = { symbols.Warn } },
            Info = { text = { symbols.Info } },
            Hint = { text = { symbols.Hint } },
          },
        })

        require("actions-preview").setup()
        require("cord").setup()
      '';

      # Use experimental lua loader with jit cache
      luaLoader.enable = true;
      performance.combinePlugins = {
        enable = false;
        standalonePlugins = [ pkgs.vimPlugins.cord-nvim ];
      };

      extraPlugins = with pkgs.vimPlugins; [
        flatten-nvim
        nvim-scrollbar
        actions-preview-nvim
        cord-nvim
      ];

      plugins = {
        lsp = {
          enable = true;
          inlayHints = true;
          servers = {
            nil_ls = {
              enable = true;
              settings.formatting.command = [ "${pkgs.nixfmt-rfc-style}/bin/nixfmt" ];
            };
            lua_ls.enable = true;
            ts_ls.enable = true;
            denols.enable = true;
            clangd.enable = true;
            solc.enable = false;
            svelte.enable = true;
          };
        };

        claude-code.enable = true;

        web-devicons.enable = true;

        rustaceanvim = {
          enable = true;
          settings = {
            tools.hover_actions.replace_builtin_hover = true;
            server = {
              # on_attach = "__lspOnAttach";
              standalone = true;
              default_settings.rust_analyzer.check.command = "clippy --all-targets";

            };
          };
        };

        fidget = {
          enable = true;
          settings = {
            integration = {
              nvim-tree = {
                enable = true;
              };
            };
            progress = {
              display = {
                progress_icon = {
                  pattern = "flip";
                  period = 1;
                };
                overrides = {
                  rust_analyzer = {
                    name = "rust analyzer";
                  };
                };
              };
            };
            notification = {
              window = {
                winblend = 0;
                x_padding = 2;
              };
            };
          };
        };

        lsp-format.enable = true;
        treesitter.enable = true;
        trouble = {
          enable = true;
          settings.auto_close = true;
        };
        lsp-lines.enable = true;
        gitsigns = {
          # for some reason broken on xps
          enable = false;
          settings = {
            signcolumn = false;
            current_line_blame = true;
            current_line_blame_opts.delay = 0;
          };
        };
        colorizer.enable = true;
        nvim-autopairs.enable = true;
        commentary.enable = true;

        cmp-nvim-lsp.enable = true;
        cmp-path.enable = true;
        cmp-buffer.enable = true;
        cmp-git.enable = true;
        crates.enable = true;
        cmp = {
          enable = true;
          autoEnableSources = false;
          settings = {
            sources = [
              { name = "nvim_lsp"; }
              { name = "path"; }
              { name = "buffer"; }
              { name = "git"; }
              { name = "crates"; }
            ];
            view = {
              entries = {
                name = "custom";
                selection_order = "near_cursor";
              };
            };
            formatting.__raw = ''
              {
                fields = { "kind", "abbr", "menu" },
                format = function(_, vim_item)
                  local icons = {
                    Text = '  ',
                    Method = '  ',
                    Function = '  ',
                    Constructor = '  ',
                    Field = '  ',
                    Variable = '  ',
                    Class = '  ',
                    Interface = '  ',
                    Module = '  ',
                    Property = '  ',
                    Unit = '  ',
                    Value = '  ',
                    Enum = '  ',
                    Keyword = '  ',
                    Snippet = '  ',
                    Color = '  ',
                    File = '  ',
                    Reference = '  ',
                    Folder = '  ',
                    EnumMember = '  ',
                    Constant = '  ',
                    Struct = '  ',
                    Event = '  ',
                    Operator = '  ',
                    TypeParameter = '  ',
                  }
                  local kind = vim_item.kind
                  vim_item.kind = (icons[kind] or "")
                  vim_item.menu = "   " .. (kind or "")
                  return vim_item
                end,
              }
            '';
            mapping = {
              "<C-Space>" = "cmp.mapping.complete()";
              "<C-d>" = "cmp.mapping.scroll_docs(-4)";
              "<C-e>" = "cmp.mapping.close()";
              "<C-f>" = "cmp.mapping.scroll_docs(4)";
              "<CR>" = "cmp.mapping.confirm({ select = true })";
              "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
              "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
            };
            snippet = {
              expand = ''
                function(args)
                  vim.snippet.expand(args.body)
                end
              '';
            };
            window.__raw = ''
              {
                completion = cmp.config.window.bordered(),
                documentation = cmp.config.window.bordered(),
              }
            '';
          };
        };

        telescope.enable = true;

        nvim-tree = {
          enable = true;
          renderer.addTrailing = true;
          renderer.highlightOpenedFiles = "all";
          updateFocusedFile = {
            enable = true;
            updateRoot = true;
          };
          diagnostics = {
            enable = true;
            showOnDirs = true;
            icons = {
              hint = {
                __raw = "symbols.Hint";
              };
              info = {
                __raw = "symbols.Info";
              };
              warning = {
                __raw = "symbols.Warn";
              };
              error = {
                __raw = "symbols.Error";
              };
            };
          };
        };

        # bufferline = {
        #   enable = true;
        #   settings.options = {
        #     separatorStyle = "thin";
        #     offsets = [
        #       {
        #         filetype = "NvimTree";
        #         text = "__ Tree __";
        #         separator = "│";
        #       }
        #     ];
        #   };
        # };

        lualine = {
          enable = true;
          settings = {
            globalstatus = true;
            componentSeparators = {
              left = "|";
              right = "|";
            };
            sectionSeparators = {
              left = "";
              right = "";
            };
            sections = {
              lualine_a = [
                {
                  name = "mode";
                  separator = {
                    left = "";
                  };
                  padding = {
                    left = 1;
                    right = 2;
                  };
                }
              ];
              lualine_b = [ "branch" ];
              lualine_c = [ "filename" ];
              lualine_x = [ "progress" ];
              lualine_y = [ "filetype" ];
              lualine_z = [
                {
                  name = "location";
                  separator = {
                    right = "";
                  };
                  padding = {
                    left = 2;
                    right = 1;
                  };
                }
              ];
            };
          };
        };

        mini = {
          enable = true;
          modules = {
            tabline = { };
            jump2d = { };
            diff = { };
            starter = {
              evaluate_single = true;
              header.__raw = ''
                function()
                  local hour = tonumber(vim.fn.strftime('%H'))
                  local part_id = math.floor((hour + 4) / 8) + 1
                  local day_part = ({ 'evening', 'morning', 'afternoon', 'evening' })[part_id]
                  local username = vim.loop.os_get_passwd()['username'] or 'USERNAME'
                  return ([[
                `7MM"""Yb.                    db  mm
                  MM    `Yb.                  '/  MM
                  MM     `Mb  ,pW"Wq.`7MMpMMMb. mmMMmm
                  MM      MM 6W'   `Wb MM    MM   MM
                  MM     ,MP 8M     M8 MM    MM   MM
                  MM    ,dP' YA.   ,A9 MM    MM   MM
                .JMMmmmdP'    `Ybmd9'.JMML  JMML. `Mbmo

                `7MM"""Mq.                   db          OO
                  MM   `MM.                              88
                  MM   ,M9 ,6"Yb.`7MMpMMMb.`7MM  ,p6"bo  ||
                  MMmmdM9 19   MM  MM    MM  MM 6M'  19  ||
                  MM       ,pm9MM  MM    MM  MM 8M       `'
                  MM      8M   MM  MM    MM  MM YM.    , ,,
                .JMML.    `Moo9^YoJMML  JMMLJMML.YMbmd'  db

                ~ Good %s, %s]]):format(day_part, username)
                end
              '';
              items.__raw = ''
                {
                  require("mini.starter").sections.recent_files(9, true),
                  { name = 'New',  action = 'enew',           section = 'Editor actions' },
                  { name = 'Tree', action = 'NvimTreeToggle', section = 'Editor actions' },
                  { name = 'Quit', action = 'qall',           section = 'Editor actions' },
                }
              '';

              content_hooks.__raw = ''
                (function()
                  local starter = require('mini.starter')
                  return {
                    starter.gen_hook.adding_bullet(),
                    starter.gen_hook.indexing("all", { "Editor actions" }),
                    starter.gen_hook.padding(2, 1),
                  }
                end)()
              '';
            };
          };
        };
      };

      highlight = {
        # Highlight and remove extra white spaces
        ExtraWhitespace.bg = "#fa4d56";

        # Mini.diff color fixes
        MiniDiffSignAdd.fg = "#42be65";
        MiniDiffSignChange.fg = "#fddc69";
        MiniDiffSignDelete.fg = "#fa4d56";
        MiniDiffOverAdd.bg = "#044317";
        MiniDiffOverChange.bg = "#8e6a00";
        MiniDiffOverDelete.bg = "#750e13";
        MiniDiffOverContext.bg = "#262626";
      };
      match.ExtraWhitespace = "\\s\\+$";

      colorschemes.catppuccin = {
        enable = true;
        settings = {
          transparent_background = true;
          color_overrides = {
            # Carburetor Regular
            mocha = {
              rosewater = "#ffd7d9";
              flamingo = "#ffb3b8";
              pink = "#ff7eb6";
              mauve = "#d4bbff";
              red = "#fa4d56";
              maroon = "#ff8389";
              peach = "#ff832b";
              yellow = "#fddc69";
              green = "#42be65";
              teal = "#3ddbd9";
              sky = "#82cfff";
              sapphire = "#78a9ff";
              blue = "#4589ff";
              lavender = "#be95ff";
              text = "#f4f4f4";
              subtext1 = "#e0e0e0";
              subtext0 = "#c6c6c6";
              overlay2 = "#a8a8a8";
              overlay1 = "#8d8d8d";
              overlay0 = "#6f6f6f";
              surface2 = "#525252";
              surface1 = "#393939";
              surface0 = "#262626";
              base = "#161616";
              mantle = "#0b0b0b";
              crust = "#000000";
            };
            # Carburetor Cool
            macchiato = {
              rosewater = "#ffd7d9";
              flamingo = "#ffb3b8";
              pink = "#ff7eb6";
              red = "#fa4d56";
              maroon = "#ff8389";
              peach = "#ff832b";
              yellow = "#fddc69";
              green = "#42be65";
              teal = "#3ddbd9";
              sky = "#82cfff";
              sapphire = "#78a9ff";
              blue = "#4589ff";
              lavender = "#be95ff";
              mauve = "#d4bbff";
              text = "#f2f4f8";
              subtext1 = "#dde1E6";
              subtext0 = "#c1c7cd";
              overlay2 = "#a2a9b0";
              overlay1 = "#878d96";
              overlay0 = "#697077";
              surface2 = "#4d5358";
              surface1 = "#343a3f";
              surface0 = "#21272a";
              base = "#121619";
              mantle = "#090b0c";
              crust = "#000000";
            };
            # Carburetor Warm
            frappe = {
              rosewater = "#ffd7d9";
              flamingo = "#ffb3b8";
              pink = "#ff7eb6";
              mauve = "#d4bbff";
              red = "#fa4d56";
              maroon = "#ff8389";
              peach = "#ff832b";
              yellow = "#fddc69";
              green = "#42be65";
              teal = "#3ddbd9";
              sky = "#82cfff";
              sapphire = "#78a9ff";
              blue = "#4589ff";
              lavender = "#be95ff";
              text = "#f7f3f2";
              subtext1 = "#e5e0df";
              subtext0 = "#cac5c4";
              overlay2 = "#ada8a8";
              overlay1 = "#8f8b8b";
              overlay0 = "#726e6e";
              surface2 = "#565151";
              surface1 = "#3c3838";
              surface0 = "#272525";
              base = "#171414";
              mantle = "#0b0a0a";
              crust = "#000000";
            };
          };
          show_end_of_buffer = false;
          integrations = {
            # NormalNvim = true;
            mini.enabled = true;
            nvimtree = true;
            lsp_trouble = true;
            symbols_outline = true;
            treesitter = true;
            gitsigns = true;
            fidget = true;
            cmp = true;
          };
        };
      };
    };
  };
}
