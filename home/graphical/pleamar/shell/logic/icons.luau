-- Nerd Font glyphs, written as escapes so no file holds the raw characters.
return function()
    local glyphs = {
        close = 0xf467, cpu = 0xf4bc, memory = 0xefc5, network = 0xf06f3,
        disk = 0xf02ca, gpu = 0xe266, host = 0xf313, search = 0xf002,
        calc = 0xf1ec, terminal = 0xf489, clipboard = 0xf0ea, keyboard = 0xf11c,
        image = 0xf03e, text = 0xf036, app = 0xf1b2, trash = 0xf1f8,
        run = 0xf135, gear = 0xf013, battery = 0xf240, display = 0xf108,
        remote = 0xf08b9,
    }
    for name, code in pairs(glyphs) do
        text["ic." .. name] = utf8.char(code)
    end
end
