-- The input overlay: what libinput reads from the keyboards and mice, while
-- it is on, the latest only, in one pill. Plain typing gathers into it; a key
-- with Ctrl, Alt or Super ("Ctrl + C"), a click or a turn of the wheel takes
-- its place. It fades a moment after the last press. Reading
-- needs the input group, and shows what is typed anywhere, passwords too, so
-- it runs only while the tile is on.

return function(S)
    local MAX, LIFE, GAP = 1, 1800, 1000
    local CHAR, PAD = 9, 28

    local MODS = {
        LEFTCTRL = "Ctrl", RIGHTCTRL = "Ctrl", LEFTALT = "Alt", RIGHTALT = "AltGr",
        LEFTMETA = "Super", RIGHTMETA = "Super", LEFTSHIFT = "Shift", RIGHTSHIFT = "Shift",
    }
    local ORDER = { "Ctrl", "Alt", "AltGr", "Super", "Shift" }
    -- What the US layout types, unshifted and shifted.
    local CHARS = {
        SPACE = { " ", " " }, MINUS = { "-", "_" }, EQUAL = { "=", "+" },
        LEFTBRACE = { "[", "{" }, RIGHTBRACE = { "]", "}" }, SEMICOLON = { ";", ":" },
        APOSTROPHE = { "'", "\"" }, GRAVE = { "`", "~" }, BACKSLASH = { "\\", "|" },
        COMMA = { ",", "<" }, DOT = { ".", ">" }, SLASH = { "/", "?" },
    }
    local SHIFTED = { ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%", ["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(", ["0"] = ")" }
    local NAMES = {
        ENTER = "Enter", KPENTER = "Enter", ESC = "Esc", TAB = "Tab", BACKSPACE = "Backspace",
        DELETE = "Del", INSERT = "Ins", HOME = "Home", END = "End", PAGEUP = "PgUp", PAGEDOWN = "PgDn",
        UP = "Up", DOWN = "Down", LEFT = "Left", RIGHT = "Right", CAPSLOCK = "Caps", SYSRQ = "Print",
        SPACE = "Space", VOLUMEUP = "Vol+", VOLUMEDOWN = "Vol-", MUTE = "Mute",
        BRIGHTNESSUP = "Bright+", BRIGHTNESSDOWN = "Bright-",
    }
    -- the return mark, put after typed text when Enter ends it
    local RET = utf8.char(0x23ce)
    local BUTTONS = { LEFT = "Left click", RIGHT = "Right click", MIDDLE = "Middle click", SIDE = "Back", EXTRA = "Forward" }

    local id = nil
    local held = {}
    local pills = {}

    local function paint()
        local rows = {}
        for i, p in ipairs(pills) do
            local label = p.label
            if p.n > 1 then label = label .. " x" .. p.n end
            -- typed spaces shown, not lost at the pill's ends
            label = label:gsub("^ ", "_"):gsub(" $", "_")
            rows[i] = { label = label, w = (utf8.len(label) or #label) * CHAR + PAD, mouse = p.mouse == true, gone = p.gone }
        end
        model["ks.keys"] = rows
    end

    local function remove(p)
        for i, q in ipairs(pills) do
            if q == p then table.remove(pills, i) break end
        end
        paint()
    end

    -- Joined by what follows within GAP of its last press; faded LIFE
    -- after it, then taken out.
    local function keep(p)
        p.stamp = (p.stamp or 0) + 1
        p.fresh = true
        local s = p.stamp
        after(GAP, function()
            if p.stamp == s then p.fresh = false end
        end)
        after(LIFE, function()
            if p.stamp ~= s or p.gone then return end
            p.gone = true
            paint()
            after(150, function() remove(p) end)
        end)
    end

    local function last()
        local p = pills[#pills]
        if p and not p.gone and p.fresh then return p end
        return nil
    end

    local function push(label, mouse)
        local p = last()
        if p and p.label == label and not p.text then
            p.n += 1
        else
            p = { label = label, n = 1, mouse = mouse, gone = false }
            table.insert(pills, p)
            while #pills > MAX do table.remove(pills, 1) end
        end
        keep(p)
        paint()
    end

    local function typed(ch)
        local p = last()
        if p and p.text and (utf8.len(p.label) or #p.label) < 24 then
            p.label ..= ch
        else
            p = { label = ch, n = 1, text = true, gone = false }
            table.insert(pills, p)
            while #pills > MAX do table.remove(pills, 1) end
        end
        keep(p)
        paint()
    end

    local function combo(name)
        local parts = {}
        for _, m in ipairs(ORDER) do
            if held[m] then table.insert(parts, m) end
        end
        table.insert(parts, name)
        return table.concat(parts, " + ")
    end

    -- A modifier pressed and let go on its own shows by itself.
    local alone = nil

    local function key(code, down)
        local mod = MODS[code]
        if mod then
            held[mod] = down or nil
            if down then
                alone = mod
            elseif alone == mod then
                alone = nil
                if mod ~= "Shift" then push(mod) end
            end
            return
        end
        if not down then return end
        alone = nil
        local chord = held.Ctrl or held.Alt or held.AltGr or held.Super
        local shift = held.Shift
        local ch = nil
        if code:match("^%u$") then
            ch = shift and code or code:lower()
        elseif code:match("^%d$") then
            ch = shift and SHIFTED[code] or code
        elseif CHARS[code] then
            ch = CHARS[code][shift and 2 or 1]
        end
        if ch and not chord then
            typed(ch)
            return
        end
        if (code == "ENTER" or code == "KPENTER") and not chord and not shift then
            local p = last()
            if p and p.text then
                typed(RET)
                return
            end
        end
        local name = NAMES[code] or (code:match("^%u$") and code) or (code:match("^%d$") and code) or (CHARS[code] and CHARS[code][1]) or code:sub(1, 1) .. code:sub(2):lower()
        push(combo(name))
    end

    local function line(l)
        -- " event4   KEYBOARD_KEY   +3.512s   KEY_A (30) pressed"
        local code, state = l:match("KEYBOARD_KEY%s+%S+%s+KEY_(%S+) %(%d+%) (%a+)")
        if code then
            key(code, state == "pressed")
            return
        end
        local btn, bstate = l:match("POINTER_BUTTON%s+%S+%s+BTN_(%S+) %(%d+%) (%a+)")
        if btn then
            if bstate == "pressed" then
                alone = nil
                push(combo(BUTTONS[btn] or btn:sub(1, 1) .. btn:sub(2):lower()), true)
            end
            return
        end
        if l:match("POINTER_SCROLL_WHEEL") then
            local v = tonumber(l:match("vert (%-?[%d%.]+)")) or 0
            local h = tonumber(l:match("horiz (%-?[%d%.]+)")) or 0
            if v ~= 0 or h ~= 0 then
                alone = nil
                local dir = if v > 0 then "down" elseif v < 0 then "up" elseif h > 0 then "right" else "left"
                push(combo("Scroll " .. dir), true)
            end
        end
    end

    local function stop()
        if id then kill(id) end
        id = nil
        held, alone = {}, nil
        pills = {}
        paint()
    end

    local function start()
        if id then return end
        id = spawn("libinput", { "debug-events", "--show-keycodes" }, line, function(_, code)
            if code ~= 0 then log("keyshow: libinput exited " .. tostring(code)) end
            id = nil
            fact["ks.on"] = false
        end)
    end

    on("ks_toggle", function()
        fact["ks.on"] = not fact["ks.on"]
        if not fact["ks.on"] then
            stop()
        elseif not fact["ks.fed"] then
            start()
        end
    end)

    -- Told rather than read (ks.fed): "N type C", "N space", "N key LABEL" or
    -- "N click LABEL", N counting up so the same press twice is still a change.
    on("text:ks.feed", function()
        if not fact["ks.on"] or not fact["ks.fed"] then return end
        local kind, rest = (text["ks.feed"] or ""):match("^%d+ (%a+) ?(.*)$")
        if kind == "type" then
            typed(rest)
        elseif kind == "space" then
            typed(" ")
        elseif kind == "key" then
            local p = last()
            if rest == "Enter" and p and p.text then typed(RET) else push(rest) end
        elseif kind == "click" then
            push(rest, true)
        end
    end)
end
