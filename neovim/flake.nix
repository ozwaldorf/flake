{
  description = "Ozwaldorf's nixvim configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixvim.url = "github:nix-community/nixvim";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = { nixvim, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { pkgs, system, ... }:
        let
          nixvimModule = {
            inherit pkgs;
            module.config = {
              clipboard.providers.wl-copy.enable = true;

              options = {
                tabstop = 2;
                shiftwidth = 2;
                expandtab = true;
                mouse = "a";
                number = true;
              };

              keymaps = [
                {
                  action = "<cmd>NvimTreeToggle<CR>";
                  key = "t";
                }
                {
                  action = "<Esc>:w!<CR>";
                  key = "<C-s>";
                  mode = [ "n" "v" "i" ];
                }
              ];

              extraPlugins = [ pkgs.vimPlugins.lsp-inlayhints-nvim ];

              extraConfigLua = ''
                local inlayhints = require("lsp-inlayhints")
                inlayhints.setup({
                  parameter_hints = { show = false },
                });

                vim.g.rustaceanvim = {
                  tools = {
                    hover_actions = {
                      auto_focus = true,
                    },
                  }, 
                  server = {
                    on_attach = function(client, bufnr)
                      require("lsp-format").on_attach(client, bufnr)
                      inlayhints.on_attach(client, bufnr)
                      inlayhints.show()
                    end,
                  }
                }
              '';

              plugins = {
                lsp = {
                  enable = true;
                  servers = {
                    nil_ls = {
                      enable = true;
                      settings.formatting.command =
                        [ "${pkgs.nixfmt}/bin/nixfmt" ];
                    };
                  };
                  # enable inline hints
                  onAttach = ''
                    if client.server_capabilities.inlayHintProvider then
                      local inlayhints = require("lsp-inlayhints")
                      inlayhints.on_attach(client, bufnr)
                      inlayhints.show()
                    end
                  '';
                };

                rustaceanvim = {
                  enable = true;
                  tools.hoverActions.replaceBuiltinHover = true;
                  server = {
                    # enable inline hints
                    onAttach = ''
                      function()
                        local inlayhints = require("lsp-inlayhints")
                        inlayhints.on_attach(client, bufnr)
                        inlayhints.show()
                      end
                    '';
                  };
                };

                lsp-format.enable = true;

                fidget = {
                  enable = true;
                  integration = { nvim-tree = { enable = true; }; };
                  progress = {
                    display = {
                      progressIcon = {
                        pattern = "flip";
                        period = 1;
                      };
                      overrides = {
                        rust_analyzer = { name = "rust analyzer"; };
                      };
                    };
                  };
                  notification = {
                    window = {
                      winblend = 0;
                      xPadding = 2;
                    };
                  };
                };

                cmp-nvim-lsp.enable = true;
                cmp-path.enable = true;
                cmp-buffer.enable = true;
                cmp_luasnip.enable = true;
                cmp-git.enable = true;
                crates-nvim.enable = true;
                cmp = {
                  enable = true;
                  autoEnableSources = false;
                  settings = {
                    sources = [
                      { name = "nvim_lsp"; }
                      { name = "path"; }
                      { name = "buffer"; }
                      { name = "luasnip"; }
                      { name = "cmp-git"; }
                      { name = "crates-nvim"; }
                    ];
                    mapping = {
                      "<C-Space>" = "cmp.mapping.complete()";
                      "<C-d>" = "cmp.mapping.scroll_docs(-4)";
                      "<C-e>" = "cmp.mapping.close()";
                      "<C-f>" = "cmp.mapping.scroll_docs(4)";
                      "<CR>" = "cmp.mapping.confirm({ select = true })";
                      "<S-Tab>" =
                        "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
                      "<Tab>" =
                        "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
                    };
                    snippet = { expand = "luasnip"; };
                  };
                };

                trouble.enable = true;
                treesitter.enable = true;
                gitsigns.enable = true;
                nvim-autopairs.enable = true;

                nvim-tree = {
                  enable = true;
                  renderer.addTrailing = true;
                  renderer.highlightOpenedFiles = "all";
                };

                bufferline = {
                  enable = true;
                  separatorStyle = "thin";
                  offsets = [{
                    filetype = "NvimTree";
                    text = "__ Tree __";
                    separator = "│";
                  }];
                };

                lualine = {
                  enable = true;
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
                    lualine_a = [{
                      name = "mode";
                      separator = { left = ""; };
                      padding = {
                        left = 1;
                        right = 2;
                      };
                    }];
                    lualine_b = [ "filename" "branch" ];
                    lualine_c = [ "fileformat" ];
                    lualine_x = [ ];
                    lualine_y = [ "filetype" "progress" ];
                    lualine_z = [{
                      name = "location";
                      separator = { right = ""; };
                      padding = {
                        left = 2;
                        right = 1;
                      };
                    }];
                  };
                };

                mini = {
                  enable = true;
                  modules = {
                    starter = {
                      evaluate_single = true;
                      header = {
                        __raw = ''
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

                          `7MM"""Mq.                     db          OO
                            MM   `MM.                                88
                            MM   ,M9 ,6"Yb. `7MMpMMMb. `7MM  ,p6"bo  ||
                            MMmmdM9 8)   MM   MM    MM   MM 6M'  OO  ||
                            MM       ,pm9MM   MM    MM   MM 8M       `'
                            MM      8M   MM   MM    MM   MM YM.    , ,,
                          .JMML.    `Moo9^Yo.JMML  JMML.JMML.YMbmd'  db

                          ~ Good %s, %s]]):format(day_part, username)
                          end
                        '';
                      };
                      items = {
                        __raw = ''
                          {
                            require("mini.starter").sections.recent_files(9, true),
                            { name = 'New',  action = 'enew',           section = 'Editor actions' },
                            { name = 'Tree', action = 'NvimTreeToggle', section = 'Editor actions' },
                            { name = 'Quit', action = 'qall',           section = 'Editor actions' },
                          }
                        '';
                      };
                      content_hooks = {
                        __raw = ''
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
              };

              colorschemes.catppuccin = {
                enable = true;
                transparentBackground = true;
                showBufferEnd = false;
                integrations = {
                  NormalNvim = true;
                  mini.enabled = true;
                  nvimtree = true;
                  lsp_trouble = true;
                  symbols_outline = true;
                  treesitter = true;
                  gitsigns = true;
                  fidget = true;
                  cmp = true;
                };
                colorOverrides.all = {
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
              };
            };
          };
        in {
          checks.default =
            nixvim.lib.${system}.check.mkTestDerivationFromNixvimModule
            nixvimModule;
          packages.default =
            nixvim.legacyPackages.${system}.makeNixvimWithModule nixvimModule;
        };
    };
}
