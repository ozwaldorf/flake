-- The clipboard history, from cliphist: listed when the page opens, images
-- decoded to a cache for their thumbnails, copied back with wl-copy.

return function(S)
    local entries = {}
    local shown = {}
    local cache = (sys.ask("env", "XDG_CACHE_HOME") or ((sys.ask("env", "HOME") or "/tmp") .. "/.cache")) .. "/pleamar/clipboard"
    local thumbs = {}

    local function human(n, unit)
        return n .. " " .. unit
    end

    local function paint()
        local q = (text["cb.q"] or ""):lower()
        shown = {}
        local rows = {}
        local y = 0
        for _, e in ipairs(entries) do
            if #rows >= 60 then break end
            if q == "" or e.search:find(q, 1, true) then
                table.insert(shown, e)
                local h = e.image and 64 or 36
                e.y, e.h = y, h
                y += h + 1
                if e.image then
                    table.insert(rows, { kind = 1, title = "Image", detail = e.ext .. " " .. e.dims .. "  " .. human(e.size, e.unit), thumb = thumbs[e.id] or "" })
                else
                    table.insert(rows, { kind = 0, title = e.text, detail = "" })
                end
            end
        end
        model.cbrows = rows
        fact["cb.n"] = #rows
    end

    local function place()
        local e = shown[(fact["cb.sel"] or 0) + 1]
        if e then
            fact["cb.sh"] = e.h
            fact["cb.sy"] = e.y
        end
    end

    -- Images decoded once into the cache, then painted from there.
    local function thumbnail(e)
        if thumbs[e.id] then return end
        local file = cache .. "/" .. e.id .. "." .. e.ext
        run("sh", { "-c", 'mkdir -p "$1" && { [ -s "$2" ] || cliphist decode "$3" > "$2"; }', "sh", cache, file, e.id }, function(_, code)
            if code == 0 then
                thumbs[e.id] = file
                paint()
            end
        end)
    end

    local function load()
        run("cliphist", { "list" }, function(out)
            entries = {}
            local images = 0
            for line in out:gmatch("[^\n]+") do
                local id, content = line:match("^(%d+)\t(.*)$")
                if id then
                    local e = { id = id, line = line }
                    local size, unit, ext, dims = content:match("^%[%[ binary data (%S+) (%S+) (%w+) (%d+x%d+) %]%]$")
                    if size then
                        e.image, e.size, e.unit, e.ext, e.dims = true, size, unit, ext, dims
                        e.search = "image " .. ext
                        images += 1
                        if images <= 60 then thumbnail(e) end
                    else
                        e.text = S.trim(content:gsub("%s+", " "))
                        e.search = content:lower()
                    end
                    table.insert(entries, e)
                end
            end
            paint()
            place()
        end)
    end

    local function close()
        fact.page = 0
        fact.held = false
    end

    on("cb_go", function(i)
        local e = shown[i + 1]
        if not e then return end
        run("sh", { "-c", 'cliphist decode "$1" | wl-copy', "sh", e.id }, nil, { output = false })
        close()
    end)

    on("cb_remove", function(i)
        local e = shown[i + 1]
        if not e then return end
        run("cliphist", { "delete" }, function() load() end, { input = e.line .. "\n" })
    end)

    on("cb_wipe", function()
        run("cliphist", { "wipe" }, function() load() end)
    end)

    on("text:cb.q", function() paint(); place() end)
    on("fact:cb.sel", place)
    on("fact:page", function(p)
        if p == 4 then
            text["cb.q"] = ""
            load()
        end
    end)
end
