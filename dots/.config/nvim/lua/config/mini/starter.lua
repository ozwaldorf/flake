--https://manytools.org/hacker-tools/ascii-banner

local function header()
  local hour = tonumber(vim.fn.strftime('%H'))
  local part_id = math.floor((hour + 4) / 8) + 1
  local day_part = ({ 'evening', 'morning', 'afternoon', 'evening' })[part_id]
  local username = vim.loop.os_get_passwd()['username'] or 'USERNAME'
  return ([[
`7MM"""Yb.                     db  mm
  MM    `Yb.                   '/  MM
  MM     `Mb  ,pW"Wq.`7MMpMMMb.  mmMMmm
  MM      MM 6W'   `Wb MM    MM    MM
  MM     ,MP 8M     M8 MM    MM    MM
  MM    ,dP' YA.   ,A9 MM    MM    MM
.JMMmmmdP'    `Ybmd9'.JMML  JMML.  `Mbmo

`7MM"""Mq.                     db          OO
  MM   `MM.                                88
  MM   ,M9 ,6"Yb. `7MMpMMMb. `7MM  ,p6"bo  ||
  MMmmdM9 8)   MM   MM    MM   MM 6M'  OO  ||
  MM       ,pm9MM   MM    MM   MM 8M       `'
  MM      8M   MM   MM    MM   MM YM.    , ,,
.JMML.    `Moo9^Yo.JMML  JMML.JMML.YMbmd'  db

~ Good %s, %s]]):format(day_part, username)
end

require("mini.sessions").setup({})

local starter = require("mini.starter")
starter.setup({
  evaluate_single = true,
  header = header,
  items = {
    starter.sections.recent_files(9, true),
    { name = 'New',    action = 'enew',                      section = 'Editor actions' },
    { name = 'Git',    action = 'Neogit',                    section = 'Editor actions' },
    { name = 'Tree',   action = 'NvimTreeToggle',            section = 'Editor actions' },
    { name = 'Mason',  action = 'Mason',                     section = 'Editor actions' },
    { name = 'Update', action = 'PackerUpdate',              section = 'Editor actions' },
    { name = 'Config', action = 'e ~/.config/nvim/init.lua', section = 'Editor actions' },
    { name = 'Quit',   action = 'qall',                      section = 'Editor actions' },
    --starter.sections.recent_files(3, false),
    --starter.sections.sessions(3, true),
  },
  content_hooks = {
    starter.gen_hook.adding_bullet(),
    starter.gen_hook.indexing("all", { "Editor actions" }),
    starter.gen_hook.padding(2, 1),
  },
})
