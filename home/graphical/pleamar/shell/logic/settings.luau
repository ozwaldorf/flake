-- The control centre: what its tiles say, and what their presses do. The
-- scene fills its lists from the services itself; this keeps a copy of each
-- so a press on a row (which arrives as its index) can be acted on.

return function(S)
    local glyphs = {
        wifi = 0xf05a9, bt = 0xf00af, power = 0xf0425, sun = 0xf05a8,
        vol = 0xf057e, mic = 0xf036c, chev = 0xf054, lock = 0xf033e,
        prev = 0xf04ae, next = 0xf04ad, bell = 0xf009a,
    }
    for name, code in pairs(glyphs) do
        text["cc.ic." .. name] = utf8.char(code)
    end
    local PLAY, PAUSE, VOL, MUTED, MIC, MICOFF = 0xf040a, 0xf03e4, 0xf057e, 0xf0581, 0xf036c, 0xf036d
    text["cc.ic.play"] = utf8.char(PLAY)

    text["cc.user"] = sys.ask("env", "USER") or ""

    -- Wi-Fi
    local net = {}
    local joining = nil
    local asking = nil
    local FAILED = {
        password = "Incorrect password",
        timeout = "Authentication timed out",
        unsupported = "Could not connect",
        busy = "Could not connect",
        failed = "Could not connect",
    }
    local function wifiStatus()
        if not net.wifi then return "Off" end
        if joining then
            for _, n in ipairs(net.networks or {}) do
                if n.ssid == joining and n.active then joining = nil end
            end
            if joining then return "Connecting..." end
        end
        if net.error and FAILED[net.error] then return FAILED[net.error] end
        if net.kind == "wifi" and net.name and net.name ~= "" then
            return net.online and net.name or net.name .. " (no internet)"
        end
        return "Not connected"
    end
    sys.watch("network", function(n)
        net = n
        text["cc.wifi.status"] = wifiStatus()
    end)
    on("cc.wifi_toggle", function() sys.call("network.wifi", not net.wifi) end)
    on("cc.wifi_pick", function(i)
        local n = (net.networks or {})[i + 1]
        if not n then return end
        if n.active then
            sys.call("network.disconnect")
        elseif n.secure and not n.known then
            asking = n.ssid
            fact["cc.askpw"] = true
            focus("cc.pw")
        else
            joining = n.ssid
            sys.call("network.connect", n.ssid)
        end
        text["cc.wifi.status"] = wifiStatus()
    end)
    on("submit:cc.pw", function(pw)
        if asking then
            joining = asking
            sys.call("network.connect", asking, pw)
        end
        asking = nil
        text["cc.pw"] = ""
        fact["cc.askpw"] = false
        text["cc.wifi.status"] = wifiStatus()
    end)

    -- Bluetooth
    local bt = {}
    local function btStatus()
        if not bt.present then return "Unavailable" end
        if not bt.powered then return "Off" end
        local on, name = 0, nil
        for _, d in ipairs(bt.devices or {}) do
            if d.connected then on, name = on + 1, d.name end
        end
        if on == 1 then return name end
        if on > 1 then return on .. " devices connected" end
        return "Not connected"
    end
    sys.watch("bluetooth", function(b)
        bt = b
        text["cc.btstatus"] = btStatus()
    end)
    on("cc.bt_toggle", function() sys.call("bluetooth.power", not bt.powered) end)
    on("cc.bt_pick", function(i)
        local d = (bt.devices or {})[i + 1]
        if not d then return end
        if d.connected then
            sys.call("bluetooth.disconnect", d.address)
        else
            sys.call("bluetooth.connect", d.address)
        end
    end)
    on("cc.bt_forget", function(i)
        local d = (bt.devices or {})[i + 1]
        if d then sys.call("bluetooth.forget", d.address) end
    end)

    -- Scanning only while a list is open.
    local scanning = false
    on("fact:list", function(l)
        if l == 1 then sys.call("network.scan") end
        local want = l == 2
        if want ~= scanning then
            scanning = want
            sys.call("bluetooth.scan", want)
        end
    end)

    -- audio
    local au = {}
    local function nameOf(list)
        for _, d in ipairs(list or {}) do
            if d.default then return d.name end
        end
        return ""
    end
    sys.watch("audio", function(a)
        au = a
        text["cc.out.name"] = nameOf(a.outputs)
        text["cc.in.name"] = nameOf(a.inputs)
        text["cc.ic.vol"] = utf8.char(a.muted and MUTED or VOL)
        text["cc.ic.mic"] = utf8.char(a.input_muted and MICOFF or MIC)
    end)
    on("cc.vol_set", function(v) sys.call("audio.volume", v) end)
    on("cc.vol_step", function(n) sys.call("audio.step", 0.05 * n) end)
    on("cc.mic_set", function(v) sys.call("audio.input", v) end)
    on("cc.mic_step", function(n) sys.call("audio.input", math.clamp((au.input or 0) + 0.05 * n, 0, 1)) end)
    on("cc.mute", function() sys.call("audio.mute", not au.muted) end)
    on("cc.mic_mute", function() sys.call("audio.input_mute") end)
    on("cc.out_pick", function(i)
        local d = (au.outputs or {})[i + 1]
        if d then sys.call("audio.default", d.id) end
    end)
    on("cc.in_pick", function(i)
        local d = (au.inputs or {})[i + 1]
        if d then sys.call("audio.default", d.id) end
    end)

    -- brightness
    -- Set through logind, as the quickshell bar does: the service's own
    -- setter needs brightnessctl, which is not installed. On the seat's active
    -- session rather than the caller's, which logind refuses when it is not
    -- in the foreground. Every backlight the kernel exposes, scaled to its
    -- own maximum.
    local bri = 0
    sys.watch("brightness", function(b) bri = b.level or 0 end)
    local function setBrightness(v)
        bri = math.clamp(v, 0.01, 1)
        run("sh", { "-c", [[
            id=$(loginctl show-seat seat0 -p ActiveSession --value)
            s=$(busctl --system call org.freedesktop.login1 /org/freedesktop/login1 \
                org.freedesktop.login1.Manager GetSession s "$id" | awk '{ gsub(/"/, "", $2); print $2 }')
            for d in /sys/class/backlight/*; do
                [ -e "$d/max_brightness" ] || continue
                level=$(awk -v m="$(cat "$d/max_brightness")" -v v="$1" 'BEGIN { printf "%d", m * v + 0.5 }')
                busctl --system call org.freedesktop.login1 "$s" \
                    org.freedesktop.login1.Session SetBrightness ssu backlight "${d##*/}" "$level"
            done </dev/null
        ]], "sh", tostring(bri) }, nil, { output = false })
    end
    on("cc.bri_set", setBrightness)
    on("cc.bri_step", function(n) setBrightness(bri + 0.05 * n) end)

    -- power
    on("cc.power", function(which)
        fact["cc.pending"] = which
        text["cc.power.status"] = which == 0 and "Restarting" or "Shutting down"
        local ok, err = pcall(sys.call, which == 0 and "session.reboot" or "session.poweroff")
        if not ok then
            fact["cc.pending"] = -1
            text["cc.power.status"] = tostring(err):match("[^\n]*$")
        end
    end)

    -- media
    sys.watch("media", function(m)
        fact["cc.hasmedia"] = (m.player or "") ~= ""
        text["cc.ic.play"] = utf8.char(m.playing and PAUSE or PLAY)
    end)
    on("cc.media", function(b)
        sys.call(b == 0 and "media.previous" or b == 1 and "media.toggle" or "media.next")
    end)

    -- the tray, and an icon's menu shown in place
    local tray = {}
    local menuKey, menuItems = nil, {}
    sys.watch("tray", function(list) tray = list or {} end)
    on("cc.tray_act", function(i)
        local t = tray[i + 1]
        if t then sys.call("tray.activate", t.key) end
    end)
    on("cc.tray_menu", function(i)
        local t = tray[i + 1]
        if not t then return end
        if menuKey == t.key and fact["cc.menuopen"] then
            fact["cc.menuopen"] = false
            return
        end
        menuKey = t.key
        menuItems = {}
        -- Submenus are flattened one level, indented.
        for _, item in ipairs(sys.ask("tray.menu", t.key) or {}) do
            table.insert(menuItems, item)
            if type(item.children) == "table" then
                for _, child in ipairs(item.children) do
                    table.insert(menuItems, {
                        id = child.id, label = "  " .. (child.label or ""), enabled = child.enabled,
                        separator = child.separator, checked = child.checked,
                    })
                end
            end
        end
        local rows = {}
        for _, item in ipairs(menuItems) do
            local checked = -1
            if item.checked == true then checked = 1 elseif item.checked == false then checked = 0 end
            table.insert(rows, {
                label = (item.label or ""):gsub("_", ""),
                enabled = item.enabled ~= false,
                separator = item.separator == true,
                checked = checked,
            })
        end
        model.ccmenu = rows
        fact["cc.menuopen"] = #rows > 0
    end)
    on("cc.menu_pick", function(i)
        local item = menuItems[i + 1]
        if item and menuKey then sys.call("tray.menu_click", menuKey, item.id) end
        fact["cc.menuopen"] = false
    end)

    -- notifications
    local notes = {}
    S.onNotifications(function(list) notes = list or {} end)
    on("cc.dismiss", function(i)
        local n = notes[i + 1]
        if n then sys.call("notifications.dismiss", n.id) end
    end)
    on("cc.clear", function() sys.call("notifications.clear") end)

    -- A quote for the empty history, new each time the page opens.
    local function fortune()
        -- The attribution, a last line starting with "--" or one trailing the
        -- text, goes on a line of its own.
        run("fortune", { "-a", "-s" }, function(out)
            local lines = {}
            for l in (S.trim(out:gsub("\t", "    ")) .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = l end
            local split = #lines + 1
            for i = #lines, 2, -1 do
                if lines[i]:match("^%s*%-%-") then
                    split = i
                    break
                end
            end
            local tail = ""
            if split > #lines then
                local body, src = (lines[#lines] or ""):match("^(.*%S)%s+%-%-%s*(%S.*)$")
                if body then
                    lines[#lines] = body
                    tail = src
                end
            else
                local src = {}
                for i = split, #lines do src[#src + 1] = S.trim(lines[i]) end
                tail = table.concat(src, " "):gsub("^%-%-%s*", "")
            end
            local body = {}
            for i = 1, math.min(split - 1, #lines) do body[#body + 1] = (lines[i]:gsub("%s+$", "")) end
            text["cc.fortune"] = S.trim(table.concat(body, "\n"))
            text["cc.fortune.src"] = tail
        end)
    end
    on("fact:page", function(p)
        if p == 1 then fortune() else fact["cc.menuopen"] = false end
    end)
    fortune()
end
