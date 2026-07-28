--@password 5267
--[[
local function d()
]]
    local assert, defer, error, getfenv, setfenv, getmetatable, setmetatable, ipairs,
    pairs, next, pcall, rawequal, rawset, rawlen, readfile, require, select,
    tonumber, tostring, type, unpack, xpcall =
        assert, defer, error, getfenv, setfenv, getmetatable, setmetatable, ipairs,
        pairs, next, pcall, rawequal, rawset, rawlen, readfile, require, select,
        tonumber, tostring, type, unpack, xpcall


    local function mcopy(o)
        if type(o) ~= "table" then return o end
        local res = {}
        for k, v in pairs(o) do res[mcopy(k)] = mcopy(v) end
        return res
    end

    local table, math, string = mcopy(table), mcopy(math), mcopy(string)
    local ui, client = mcopy(ui), mcopy(client)

    --#endregion

    --#region: globals

    table.find = function(t, j)
        for k, v in pairs(t) do if v == j then return k end end
        return false
    end
    table.ifind = function(t, j) for i = 1, table.maxn(t) do if t[i] == j then return i end end end
    table.qfind = function(t, j) for i = 1, #t do if t[i] == j then return i end end end
    table.ihas = function(t, ...)
        local arg = { ... }
        for i = 1, table.maxn(t) do for j = 1, #arg do if t[i] == arg[j] then return true end end end
        return false
    end

    table.minn = function(t)
        local s = 0
        for i = 1, #t do
            if t[i] == nil then break end
            s = s + 1
        end
        return s
    end
    table.filter = function(t)
        local res = {}
        for i = 1, table.maxn(t) do if t[i] ~= nil then res[#res + 1] = t[i] end end
        return res
    end
    table.append = function(t, ...) for i, v in ipairs { ... } do table.insert(t, v) end end
    table.copy = mcopy

    local ternary = function(c, a, b) if c then return a else return b end end
    local contend = function(func, callback, ...)
        local t = { pcall(func, ...) }
        if not t[1] then return type(callback) == "function" and callback(t[2]) or error(t[2], callback or 2) end
        return unpack(t, 2)
    end

    --#endregion

    --#region: directory tools

    local dirs = {
        execute = function(t, path, func)
            local p, k
            for _, s in ipairs(path) do
                k, p, t = s, t, t[s]
                if t == nil then return end
            end
            if p[k] then func(p[k]) end
        end,
        replace = function(t, path, value)
            local p, k
            for _, s in ipairs(path) do
                k, p, t = s, t, t[s]
                if t == nil then return end
            end
            p[k] = value
        end,
        find = function(t, path)
            local p, k
            for _, s in ipairs(path) do
                k, p, t = s, t, t[s]
                if t == nil then return end
            end
            return p[k]
        end,
    }

    dirs.pave = function(t, place, path)
        local p = t
        for i, v in ipairs(path) do
            if type(p[v]) == "table" then
                p = p[v]
            else
                p[v] = (i < #path) and {} or place
                p = p[v]
            end
        end
        return t
    end

    dirs.extract = function(t, path)
        if not path or #path == 0 then return t end
        local j = dirs.find(t, path)
        return dirs.pave({}, j, path)
    end

    --#endregion

    local pui, pui_mt, methods_mt = {}, {}, {
        element = {}, group = {}
    }

    -- #endregion
    --

    --
    -- #region : Elements

    --#region: arguments

    local elements = {
        button       = { type = "function", arg = 2, unsavable = true },
        checkbox     = { type = "boolean", arg = 1, init = false },
        color_picker = { type = "table", arg = 5 },
        combobox     = { type = "string", arg = 2, variable = true },
        hotkey       = { type = "table", arg = 3, enum = { [0] = "Always on", "On hotkey", "Toggle", "Off hotkey" } },
        label        = { type = "string", arg = 1, unsavable = true },
        listbox      = { type = "number", arg = 2, init = 0, variable = true },
        multiselect  = { type = "table", arg = 2, init = {}, variable = true },
        slider       = { type = "number", arg = 8 },
        textbox      = { type = "string", arg = 1, init = "" },
        string       = { type = "string", arg = 2, init = "" },
        unknown      = { type = "string", arg = 2, init = "" } -- new_string type
    }

    local weapons = { "Global", "G3SG1 / SCAR-20", "SSG 08", "AWP", "R8 Revolver", "Desert Eagle", "Pistol", "Zeus", "Rifle",
        "Shotgun", "SMG", "Machine gun" }

    --#endregion

    --#region: registry

    local registry, ragebot, players = {}, {}, {}
    do
        client.set_event_callback("shutdown", function()
            for k, v in next, registry do
                if v.__ref and not v.__rage then
                    if v.overridden then ui.set(k, v.original) end
                    ui.set_enabled(k, true)
                    ui.set_visible(k, not v.__hidden)
                end
            end
            ragebot.cycle(function(active)
                for k, v in pairs(ragebot.context[active]) do
                    if v ~= nil and registry[k].overridden then
                        ui.set(k, v)
                    end
                end
            end, true)
        end)
        client.set_event_callback("pre_config_save", function()
            for k, v in next, registry do
                if v.__ref and not v.__rage and v.overridden then
                    v.ovr_restore = { ui.get(k) }; ui.set(k, v.original)
                end
            end
            ragebot.cycle(function(active)
                for k, v in pairs(ragebot.context[active]) do if registry[k].overridden then
                        ragebot.cache[active][k] = ui.get(k); ui.set(k, v)
                    end end
            end, true)
        end)
        client.set_event_callback("post_config_save", function()
            for k, v in next, registry do
                if v.__ref and not v.__rage and v.overridden then
                    ui.set(k, unpack(v.ovr_restore)); v.ovr_restore = nil
                end
            end
            ragebot.cycle(function(active)
                for k, v in pairs(ragebot.context[active]) do
                    if k ~= nil and ragebot.cache[active] ~= nil and ragebot.cache[active][k] ~= nil then
                        if registry[k].overridden then
                            ui.set(k, ragebot.cache[active][k]); ragebot.cache[active][k] = nil
                        end
                    end
                end
            end, true)
        end)
    end

    --#endregion

    --#region: elemence

    local elemence = {}
    do
        local callbacks = function(this, isref)
            if this.name == "Weapon type" and string.lower(registry[this.ref].tab) == "rage" then return ui.get(this.ref) end

            ui.set_callback(this.ref, function(self)
                if registry[self].__rage and ragebot.silent then return end
                for i = 0, #registry[self].callbacks, 1 do
                    if type(registry[self].callbacks[i]) == "function" then registry[self].callbacks[i](this) end
                end
            end)

            if this.type == "button" then
                return
            elseif this.type == "color_picker" or this.type == "hotkey" then
                registry[this.ref].callbacks[0] = function(self) this.value = { ui.get(self.ref) } end
                return { ui.get(this.ref) }
            else
                registry[this.ref].callbacks[0] = function(self) this.value = ui.get(self.ref) end
                if this.type == "multiselect" then
                    this.value = ui.get(this.ref)
                    registry[this.ref].callbacks[1] = function(self)
                        registry[this.ref].options = {}
                        for i = 1, #self.value do registry[this.ref].options[self.value[i]] = true end
                    end
                    registry[this.ref].callbacks[1](this)
                end
                return ui.get(this.ref)
            end
        end

        elemence.new = function(ref, add)
            local self = {}; add = add or {}

            self.ref = ref
            self.name, self.type = ui.name(ref), ui.type(ref)

            --
            registry[ref] = registry[ref] or {
                type = self.type,
                ref = ref,
                tab = add.__tab,
                container = add.__container,
                __ref = add.__ref,
                __hidden = add.__hidden,
                __init = add.__init,
                __list = add.__list,
                __rage = add.__rage,
                __plist = add.__plist and not (self.type == "label" or self.type == "button" or self.type == "hotkey"),

                overridden = false,
                original = self.value,
                donotsave = add.__plist or false,
                callbacks = { [0] = add.__callback },
                events = {},
                depend = { [0] = { ref }, {}, {} },
            }

            registry[ref].self = setmetatable(self, methods_mt.element)
            self.value = callbacks(self, add.__ref)

            if add.__rage then
                methods_mt.element.set_callback(self, ragebot.memorize)
            end
            if registry[ref].__plist then
                players.elements[#players.elements + 1] = self
                methods_mt.element.set_callback(self, players.slot_update, true)
            end

            return self
        end

        elemence.group = function(...)
            return setmetatable({ ... }, methods_mt.group)
        end

        elemence.string = function(name, default)
            local this = {}

            this.ref = ui.new_string(name, default or "")
            this.type = "string"
            this[0] = { savable = true }

            return setmetatable(this, methods_mt.element)
        end

        elemence.features = function(self, args)
            do
                local addition
                local v, kind = args[1], type(args[1])

                if not addition and (kind == "table" or kind == "cdata") and not v.r then
                    addition = "color"
                    local r, g, b, a = v[1] or 255, v[2] or 255, v[3] or 255, v[4] or 255
                    self.color = elemence.new(
                    ui.new_color_picker(registry[self.ref].tab, registry[self.ref].container, self.name, r, g, b, a), {
                        __init = { r, g, b, a },
                        __plist = registry[self.ref].__plist
                    })
                elseif not addition and (kind == "table" or kind == "cdata") and v.r then
                    addition = "color"
                    self.color = elemence.new(
                    ui.new_color_picker(registry[self.ref].tab, registry[self.ref].container, self.name, v.r, v.g, v.b, v.a),
                        {
                            __init = { v.r, v.g, v.b, v.a },
                            __plist = registry[self.ref].__plist
                        })
                elseif not addition and kind == "number" then
                    addition = "hotkey"
                    self.hotkey = elemence.new(ui.new_hotkey(registry[self.ref].tab, registry[self.ref].container, self.name,
                        true, v, {
                        __init = v
                    }))
                end
                registry[self.ref].depend[0][2] = addition and self[addition].ref
                registry[self.ref].__addon = addition
            end
            do
                registry[self.ref].donotsave = args[2] == false
            end
        end

        elemence.memorize = function(self, path, origin)
            if registry[self.ref].donotsave then return end

            if not elements[self.type].unsavable then
                dirs.pave(origin, self.ref, path)
            end

            if self.color then
                path[#path] = path[#path] .. "_c"
                dirs.pave(origin, self.color.ref, path)
            end
            if self.hotkey then
                path[#path] = path[#path] .. "_h"
                dirs.pave(origin, self.hotkey.ref, path)
            end
        end

        elemence.hidden_refs = {
            "Unlock hidden cvars", "Allow custom game events", "Faster grenade toss",
            "sv_maxunlag", "sv_maxusrcmdprocessticks", "sv_clockcorrection_msecs", -- m4kb12jk
        }

        --#region: depend

        local cases = {
            combobox = function(v)
                if v[3] == true then
                    return v[1].value ~= v[2]
                else
                    for i = 2, #v do
                        if v[1].value == v[i] then return true end
                    end
                end
                return false
            end,
            listbox = function(v)
                if v[3] == true then
                    return v[1].value ~= v[2]
                else
                    for i = 2, #v do
                        if v[1].value == v[i] then return true end
                    end
                end
                return false
            end,
            multiselect = function(v)
                return table.ihas(v[1].value, unpack(v, 2))
            end,
            slider = function(v)
                return v[2] <= v[1].value and v[1].value <= (v[3] or v[2])
            end,
        }

        local depend = function(v)
            local condition = false

            if type(v[2]) == "function" then
                condition = v[2](v[1])
            else
                local f = cases[v[1].type]
                if f then
                    condition = f(v)
                else
                    condition = v[1].value == v[2]
                end
            end

            return condition and true or false
        end

        elemence.dependant = function(owner, dependant, dis)
            local count = 0

            for i = 1, #owner do
                if depend(owner[i]) then count = count + 1 else break end
            end

            local allow, action = count >= #owner, dis and "set_enabled" or "set_visible"

            for i, v in ipairs(dependant) do ui[action](v, allow) end
        end

        --#endregion
    end

    --#endregion

    --#region: utils

    local utils = {}

    do
        utils.rgb_to_hex = function(color)
            return string.format("%02X%02X%02X%02X", color[1], color[2], color[3], color[4] or 255)
        end

        utils.hex_to_rgb = function(hex)
            hex = hex:gsub("^#", "")
            return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16),
                tonumber(hex:sub(7, 8), 16) or 255
        end

        utils.gradient_text = function(text, colors, precision)
            local symbols, length = {}, #string.gsub(text, ".[\128-\191]*", "a")
            local s = 1 / (#colors - 1)
            precision = precision or 1

            local i = 0
            for letter in string.gmatch(text, ".[\128-\191]*") do
                i = i + 1

                local weight = i / length
                local cw = weight / s
                local j = math.ceil(cw)
                local w = (cw / j)
                local L, R = colors[j], colors[j + 1]

                local r = L[1] + (R[1] - L[1]) * w
                local g = L[2] + (R[2] - L[2]) * w
                local b = L[3] + (R[3] - L[3]) * w
                local a = L[4] + (R[4] - L[4]) * w

                symbols[#symbols + 1] = ((i - 1) % precision == 0) and ("\a%02x%02x%02x%02x%s"):format(r, g, b, a, letter) or
                letter
            end

            symbols[#symbols + 1] = "\aCDCDCDFF"

            return table.concat(symbols)
        end

        local gradients = function(col, text)
            local colors = {}; for w in string.gmatch(col, "\b%x+") do
                colors[#colors + 1] = { utils.hex_to_rgb(string.sub(w, 2)) }
            end
            if #colors > 0 then return utils.gradient_text(text, colors, #text > 8 and 2 or 1) end
        end

        utils.format = function(s)
            if type(s) == "string" then
                s = string.gsub(s, "\f<(.-)>", pui.macros)
                s = string.gsub(s, "[\v\r\t]", { ["\v"] = "\a" .. pui.accent, ["\r"] = "\aCDCDCDFF", ["\t"] = "    " })
                s = string.gsub(s, "([\b%x]-)%[(.-)%]", gradients)
            end
            return s
        end

        utils.unpack_color = function(...)
            local arg = { ... }
            local kind = type(arg[1])

            if kind == "table" or kind == "cdata" or kind == "userdata" then
                if arg[1].r then
                    return { arg[1].r, arg[1].g, arg[1].b, arg[1].a }
                elseif arg[1][1] then
                    return { arg[1][1], arg[1][2], arg[1][3], arg[1][4] }
                end
            end

            return arg
        end

        --#region: dispense

        local dispensers = {
            color_picker = function(args)
                args[1] = string.sub(utils.format(args[1]), 1, 117)

                if type(args[2]) ~= "number" then
                    local col = args[2]
                    args.n, args.req, args[2] = args.n + 3, args.req + 3, col.r
                    table.insert(args, 3, col.g)
                    table.insert(args, 4, col.b)
                    table.insert(args, 5, col.a)
                end

                for i = args.req + 1, args.n do
                    args.misc[i - args.req] = args[i]
                end

                args.data.__init = { args[2] or 255, args[3] or 255, args[4] or 255, args[5] or 255 }
            end,
            listbox = function(args, variable)
                args[1] = string.sub(utils.format(args[1]), 1, 117)
                for i = args.req + 1, args.n do
                    args.misc[i - args.req] = args[i]
                end

                args.data.__init, args.data.__list = 0, not variable and args[2] or { unpack(args, 2, args.n) }
            end,
            combobox = function(args, variable)
                args[1] = string.sub(utils.format(args[1]), 1, 117)
                for i = args.req + 1, args.n do
                    args.misc[i - args.req] = args[i]
                end

                args.data.__init, args.data.__list = not variable and args[2][1] or args[2],
                    not variable and args[2] or { unpack(args, 2, args.n) }
            end,
            multiselect = function(args, variable)
                args[1] = string.sub(utils.format(args[1]), 1, 117)
                for i = args.req + 1, args.n do
                    args.misc[i - args.req] = args[i]
                end

                args.data.__init, args.data.__list = {}, not variable and args[2] or { unpack(args, 2, args.n) }
            end,
            slider = function(args)
                args[1] = string.sub(utils.format(args[1]), 1, 117)

                for i = args.req + 1, args.n do
                    args.misc[i - args.req] = args[i]
                end

                args.data.__init = args[4] or args[2]
            end,
            button = function(args)
                args[2] = args[2] or function() end
                args[1] = string.sub(utils.format(args[1]), 1, 117)
                args.n, args.data.__callback = 2, args[2]
            end
        }

        utils.dispense = function(key, raw, ...)
            local args, group, ctx = { ... }, {}, elements[key]

            if type(raw) == "table" then
                group[1], group[2] = raw[1], raw[2]
                group.__plist = raw.__plist
            else
                group[1], group[2] = raw, args[1]
                table.remove(args, 1)
            end

            args.n, args.data = table.maxn(args), {
                __tab = group[1],
                __container = group[2],
                __plist = group.__plist and true or nil
            }

            local variable = (ctx and ctx.variable) and type(args[2]) == "string"
            args.req, args.misc = not variable and ctx.arg or args.n, {}

            if dispensers[key] then
                dispensers[key](args, variable)
            else
                for i = 1, args.n do
                    if type(args[i]) == "string" then
                        args[i] = string.sub(utils.format(args[i]), 1, 117)
                    end

                    if i > args.req then args.misc[i - args.req] = args[i] end
                end
                args.data.__init = ctx.init
            end

            return args, group
        end

        --#endregion
    end

    --#endregion

    -- #endregion
    --


    -- #endregion -----------------------------------------------------------
    --


    -------------------------------------------------------------------------
    -- #region :: pui


    --
    -- #region : pui

    --#region: variables

    pui.macros = setmetatable({}, {
        __newindex = function(self, key, value) rawset(self, tostring(key), value) end,
        __index = function(self, key) return rawget(self, tostring(key)) end
    })

    pui.accent, pui.menu_open = nil, ui.is_menu_open()

    do
        local reference = ui.reference("MISC", "Settings", "Menu color")
        pui.accent = utils.rgb_to_hex { ui.get(reference) }
        local previous = pui.accent

        ui.set_callback(reference, function()
            local color = { ui.get(reference) }
            pui.accent = utils.rgb_to_hex(color)

            for idx, ref in next, registry do
                if ref.type == "label" and not ref.__ref then
                    local new, count = string.gsub(ref.self.value, previous, pui.accent)
                    if count > 0 then
                        ui.set(idx, new)
                        ref.self.value = new
                    end
                end
            end
            previous = pui.accent
            client.fire_event("pui::accent_color", color)
        end)
    end

    client.set_event_callback("paint_ui", function()
        local state = ui.is_menu_open()
        if state ~= pui.menu_open then
            client.fire_event("pui::menu_state", state)
            pui.menu_open = state
        end
    end)

    --#endregion

    --#region: features

    pui.group = function(tab, container) return elemence.group(tab, container) end

    pui.format = utils.format

    pui.reference = function(tab, container, name)
        local found = { contend(ui.reference, 3, tab, container, name) }
        local total, hidden = #found, false

        -- done on purpose, don't blame me
        if string.lower(tab) == "misc" and string.lower(container) == "settings" then
            for i, v in ipairs(elemence.hidden_refs) do
                if string.find(name, "^" .. v) then
                    hidden = true
                    break
                end
            end
        end

        for i, v in ipairs(found) do
            found[i] = elemence.new(v, {
                __ref = true,
                __hidden = hidden or nil,
                __tab = tab,
                __container = container,
                __rage = container == "Aimbot" or nil,
            })
        end

        if total > 1 then
            local shift = 0
            for i = 1, total > 4 and total or 4, 2 do
                local m, j = i - shift, i + 1 - shift
                if found[j] and (found[j].type == "hotkey" or found[j].type == "color_picker") then
                    local addition = found[j].type == "color_picker" and "color" or "hotkey"
                    registry[found[m].ref].__addon, found[m][addition] = addition, found[j]

                    table.remove(found, j)
                    shift = shift + 1
                end
            end
            return unpack(found)
        else
            return found[1]
        end
    end

    pui.traverse = function(t, f, p)
        p = p or {}

        if type(t) == "table" and t.__name ~= "pui::element" and t[#t] ~= "~" then
            for k, v in next, t do
                local np = table.copy(p); np[#np + 1] = k
                pui.traverse(v, f, np)
            end
        else
            f(t, p)
        end
    end

    --#endregion

    --#region: config system

    do
        local save = function(config, ...)
            local packed = {}

            pui.traverse(dirs.extract(config, { ... }), function(ref, path)
                local value
                local etype = registry[ref].type

                if etype == "color_picker" then
                    value = "#" .. utils.rgb_to_hex { ui.get(ref) }
                elseif etype == "hotkey" then
                    local _, mode, key = ui.get(ref)
                    value = { mode, key or 0 }
                else
                    value = ui.get(ref)
                end

                if type(value) == "table" then value[#value + 1] = "~" end
                dirs.pave(packed, value, path)
            end)

            return packed
        end

        local load = function(config, package, ...)
            if not package then return end

            local packed = dirs.extract(package, { ... })
            pui.traverse(dirs.extract(config, { ... }), function(ref, path)
                local value, proxy = dirs.find(packed, path), registry[ref]
                local vtype, etype = type(value), proxy.type
                local object = elements[etype]

                if vtype == "string" and value:sub(1, 1) == "#" then
                    value, vtype = { utils.hex_to_rgb(value) }, "table"
                elseif vtype == "table" and value[#value] == "~" then
                    value[#value] = nil
                end

                if etype == "hotkey" and value and type(value[1]) == "number" then
                    value[1] = elements.hotkey.enum[value[1]]
                end

                local s, r = pcall(function()
                    if object and object.type == vtype then
                        if vtype == "table" and etype ~= "multiselect" then
                            ui.set(ref, unpack(value))
                            if etype == "color_picker" then methods_mt.element.invoke(proxy.self) end
                        else
                            ui.set(ref, value)
                        end
                    else
                        if proxy.__init then ui.set(ref, proxy.__init) end
                    end
                end)

                -- if not s then printf("failed to set %s to %s  [%s]", value, proxy.self, r) end
            end)
        end

        --
        local package_mt = {
            __type = "pui::package",
            __metatable = false,
            __call = function(self, raw, ...)
                return (type(raw) == "table" and load or save)(self[0], raw, ...)
            end,
            save = function(self, ...) return save(self[0], ...) end,
            load = function(self, ...) load(self[0], ...) end,
        }
        package_mt.__index = package_mt

        pui.setup = function(t)
            local package = { [0] = {} }
            pui.traverse(t, function(r, p) elemence.memorize(r, p, package[0]) end)
            return setmetatable(package, package_mt)
        end
    end

    --#endregion

    -- #endregion
    --

    --
    -- #region : methods

    methods_mt.element = {
        __type = "pui::element",
        __name = "pui::element",
        __metatable = false,
        __eq = function(this, that) return this.ref == that.ref end,
        __tostring = function(self) return string.format('pui.%s[%d] "%s"', self.type, self.ref, self.name) end,
        __call = function(self, ...) if #{ ... } > 0 then ui.set(self.ref, ...) else return ui.get(self.ref) end end,

        --

        depend = function(self, ...)
            local arg = { ... }
            local disabler = arg[1] == true

            local depend = registry[self.ref].depend[disabler and 2 or 1]
            local this = registry[self.ref].depend[0]

            for i = (disabler and 2 or 1), table.maxn(arg) do
                local v = arg[i]
                if v then
                    if v.__name == "pui::element" then v = { v, true } end
                    depend[#depend + 1] = v

                    local check = function() elemence.dependant(depend, this, disabler) end
                    check()

                    registry[v[1].ref].callbacks[#registry[v[1].ref].callbacks + 1] = check
                end
            end

            return self
        end,

        override = function(self, value)
            local is_hk = self.type == "hotkey"
            local ctx, wctx = registry[self.ref], ragebot.context[ragebot.ref.value]

            if value ~= nil then
                if not ctx.overridden then
                    if is_hk then self.value = { ui.get(self.ref) } end
                    if ctx.__rage then wctx[self.ref] = self.value else ctx.original = self.value end
                end
                ctx.overridden = true
                if is_hk then ui.set(self.ref, value[1], value[2]) else ui.set(self.ref, value) end
                if ctx.__rage then ctx.__ovr_v = value end
            else
                if ctx.overridden then
                    local original = ctx.original
                    if ctx.__rage then original, ctx.__ovr_v = wctx[self.ref], nil end
                    if is_hk then
                        ui.set(self.ref, elements.hotkey.enum[original[2]], original[3] or 0)
                    else
                        ui.set(self.ref, original)
                    end
                    ctx.overridden = false
                end
            end
        end,
        get_original = function(self)
            if registry[self.ref].__rage then
                if registry[self.ref].overridden then return ragebot.context[ragebot.ref.value][self.ref] else return self
                    .value end
            else
                if registry[self.ref].overridden then return registry[self.ref].original else return self.value end
            end
        end,

        --

        set = function(self, ...)
            if self.type == "color_picker" then
                ui.set(self.ref, unpack(utils.unpack_color(...)))
                methods_mt.element.invoke(self)
            elseif self.type == "label" then
                local t = utils.format(...)
                ui.set(self.ref, t)
                self.value = t
            else
                ui.set(self.ref, ...)
            end
        end,
        get = function(self, value)
            if value and self.type == "multiselect" then
                return registry[self.ref].options[value] or false
            end
            return ui.get(self.ref)
        end,

        reset = function(self) if registry[self.ref].__init then ui.set(self.ref, registry[self.ref].__init) end end,

        update = function(self, t)
            ui.update(self.ref, t)
            registry[self.ref].__list = t

            local cap = #t - 1
            if ui.get(self.ref) > cap then ui.set(self.ref, cap) end
        end,
        get_list = function(self) return registry[self.ref].__list end,

        get_color = function(self)
            if registry[self.ref].__addon then return ui.get(self.color.ref) end
        end,
        set_color = function(self, ...)
            if registry[self.ref].__addon then methods_mt.element.set(self.color, ...) end
        end,
        get_hotkey = function(self)
            if registry[self.ref].__addon then return ui.get(self.hotkey.ref) end
        end,
        set_hotkey = function(self, ...)
            if registry[self.ref].__addon then methods_mt.element.set(self.hotkey, ...) end
        end,

        is_reference = function(self) return registry[self.ref].__ref or false end,
        get_type = function(self) return self.type end,
        get_name = function(self) return self.name end,

        set_visible = function(self, visible)
            ui.set_visible(self.ref, visible)
            if registry[self.ref].__addon then ui.set_visible(self[registry[self.ref].__addon].ref, visible) end
        end,
        set_enabled = function(self, enabled)
            ui.set_enabled(self.ref, enabled)
            if registry[self.ref].__addon then ui.set_enabled(self[registry[self.ref].__addon].ref, enabled) end
        end,

        set_callback = function(self, func, once)
            if once == true then func(self) end
            registry[self.ref].callbacks[#registry[self.ref].callbacks + 1] = func
        end,
        unset_callback = function(self, func)
            table.remove(registry[self.ref].callbacks, table.qfind(registry[self.ref].callbacks, func) or 0)
        end,
        invoke = function(self, ...)
            for i = 0, #registry[self.ref].callbacks do registry[self.ref].callbacks[i](self, ...) end
        end,

        set_event = function(self, event, func, condition)
            local slot = registry[self.ref]
            if condition == nil then condition = true end
            local is_cond_fn, latest = type(condition) == "function", nil
            slot.events[func] = function(this)
                local permission
                if is_cond_fn then permission = condition(this) else permission = this.value == condition end

                local action = permission and client.set_event_callback or client.unset_event_callback
                if latest ~= permission then
                    action(event, func)
                    latest = permission
                end
            end
            slot.events[func](self)
            slot.callbacks[#slot.callbacks + 1] = slot.events[func]
        end,
        unset_event = function(self, event, func)
            client.unset_event_callback(event, func)
            methods_mt.element.unset_callback(self, registry[self.ref].events[func])
            registry[self.ref].events[func] = nil
        end,

        get_location = function(self) return registry[self.ref].tab, registry[self.ref].container end,
    }
    methods_mt.element.__index = methods_mt.element

    methods_mt.group = {
        __name = "pui::group",
        __metatable = false,
        __index = function(self, key) return rawget(methods_mt.group, key) or pui_mt.__index(self, key) end,
        get_location = function(self) return self[1], self[2] end
    }

    -- #endregion
    --

    --
    -- #region : pui_mt, ragebot and plist handler

    do
        for k, v in next, elements do
            v.fn = function(origin, ...)
                local args, group = utils.dispense(k, origin, ...)
                local this = elemence.new(
                contend(ui["new_" .. k], 3, group[1], group[2], unpack(args, 1, args.n < args.req and args.n or args.req)),
                    args.data)

                elemence.features(this, args.misc)
                return this
            end
        end

        pui_mt.__name, pui_mt.__metatable = "pui::basement", false
        pui_mt.__index = function(self, key)
            if not elements[key] then return ui[key] end
            if key == "string" then return elemence.string end

            return elements[key].fn
        end
    end


    --#region: ragebot handler

    ragebot = {
        ref = pui.reference("RAGE", "Weapon type", "Weapon type"),
        context = {},
        cache = {},
        silent = false,
    }
    do
        local previous, cycle_action = ragebot.ref.value, nil
        for i, v in ipairs(weapons) do ragebot.context[v], ragebot.cache[v] = {}, {} end

        local neutral = ui.reference("RAGE", "Aimbot", "Enabled")
        ui.set_callback(neutral, function()
            if not ragebot.silent then client.delay_call(0, client.fire_event, "pui::adaptive_weapon", ragebot.ref.value,
                    previous) end
            if cycle_action then cycle_action(ragebot.ref.value) end
        end)

        ragebot.cycle = function(fn, mute)
            cycle_action = mute and fn or nil
            ragebot.silent = mute and true or false

            for i, v in ipairs(weapons) do
                ragebot.ref:override(v)
            end

            ragebot.ref:override()
            cycle_action, ragebot.silent = nil, false
        end

        ui.set_callback(ragebot.ref.ref, function(self)
            ragebot.ref.value = ui.get(self)

            if not ragebot.silent and previous ~= ragebot.ref.value then
                for i = 1, #registry[self].callbacks, 1 do registry[self].callbacks[i](ragebot.ref) end
            end

            previous = ragebot.ref.value
        end)

        ragebot.memorize = function(self)
            local ctx = ragebot.context[ragebot.ref.value]

            if registry[self.ref].overridden then
                if ctx[self.ref] == nil then
                    ctx[self.ref] = self.value
                    -- methods_mt.element.override(self, registry[self.ref].__ovr_v)
                end
            else
                if ctx[self.ref] then
                    methods_mt.element.set(self, ctx[self.ref])
                    ctx[self.ref] = nil
                end
            end
        end
    end

    --#endregion

    --#region: plist handler

    players = {
        elements = {}, list = {},
    }
    do
        --#region: stuff

        pui.plist = elemence.group("PLAYERS", "Adjustments")
        pui.plist.__plist = true

        local selected = 0
        local refs, slot = {
            list = pui.reference("PLAYERS", "Players", "Player list"),
            reset = pui.reference("PLAYERS", "Players", "Reset all"),
            apply = pui.reference("PLAYERS", "Adjustments", "Apply to all"),
        }, {}

        --#endregion

        --#region: slot metatable

        local slot_mt = {
            __type = "pui::player_slot",
            __metatable = false,
            __tostring = function(self)
                return string.format("pui::player_slot[%d] of %s", self.idx,
                    methods_mt.element.__tostring(registry[self.ref].self))
            end,
            set = function(self, ...) -- don't mind
                local ctx, value = registry[self.ref], { ... }

                local is_colorpicker = ctx.type == "color_picker"
                if is_colorpicker then
                    value = utils.unpack_color(...)
                end

                if self.idx == selected then
                    ui.set(self.ref, unpack(value))
                    if is_colorpicker then
                        methods_mt.element.invoke(ctx.self)
                    end
                else
                    self.value = is_colorpicker and value or unpack(value)
                end
            end,
            get = function(self, find)
                if find and registry[self.ref].type == "multiselect" then
                    return table.qfind(self.value, find) ~= nil
                end

                if registry[self.ref].type ~= "color_picker" then
                    return self.value
                else
                    return unpack(self.value)
                end
            end,
        }
        slot_mt.__index = slot_mt

        --#endregion

        --#region: slots handling stuff

        players.traverse = function(fn) for i, v in ipairs(players.elements) do fn(v) end end

        slot = {
            select = function(idx)
                if not idx then return end
                for i, v in ipairs(players.elements) do
                    methods_mt.element.set(v, v[idx].value)
                end
            end,
            add = function(idx)
                if not idx then return end
                for i, v in ipairs(players.elements) do
                    local default = ternary(registry[v.ref].__init ~= nil, registry[v.ref].__init, v.value)
                    v[idx], players.list[idx] = setmetatable({
                        ref = v.ref, idx = idx, value = default
                    }, slot_mt), true
                end
            end,
            remove = function(idx)
                if not idx then return end
                for i, v in ipairs(players.elements) do
                    v[idx], players.list[idx] = nil, nil
                end
            end,
        }

        players.slot_update = function(self)
            if self[selected] then
                self[selected].value = self.value
            else
                slot.add(selected)
            end
        end

        --#endregion

        --#region: callbacks

        local is_updating = false
        local silent = false
        local update = function(e)
            if is_updating then return end
            is_updating = true
            selected = ui.get(refs.list.ref)

            local new, old = entity.get_players(), players.list
            local me = entity.get_local_player()

            for idx, v in next, old do
                if entity.get_classname(idx) ~= "CCSPlayer" then
                    slot.remove(idx)
                end
            end

            for i, idx in ipairs(new) do
                if idx ~= me and not players.list[idx] and entity.get_classname(idx) == "CCSPlayer" then
                    slot.add(idx)
                end
            end

            if not silent and not e.value then
                for i = #new, 1, -1 do
                    if new[i] ~= me then
                        ui.set(refs.list.ref, new[i])
                        break
                    end
                end
                client.update_player_list()
                silent = true
            else
                silent = false
            end

            slot.select(selected)
            client.fire_event("pui::plist_update", selected)
            is_updating = false
        end

        do
            local function once()
                update {}
                client.unset_event_callback("pre_render", once)
            end
            client.set_event_callback("pre_render", once)
        end
        methods_mt.element.set_callback(refs.list, update, true)
        client.set_event_callback("player_connect_full", update)
        client.set_event_callback("player_disconnect", update)
        client.set_event_callback("player_spawned", update)
        client.set_event_callback("player_spawn", update)
        client.set_event_callback("player_death", update)
        client.set_event_callback("player_team", update)

        --

        methods_mt.element.set_callback(refs.apply, function()
            players.traverse(function(v)
                for idx, _ in next, players.list do
                    v[idx].value = v[selected].value
                end
            end)
        end)
        methods_mt.element.set_callback(refs.reset, function()
            players.traverse(function(v)
                for idx, _ in next, players.list do
                    if idx == selected then
                        slot_mt.set(v[idx], registry[v.ref].__init)
                    else
                        v[idx].value = registry[v.ref].__init
                    end
                end
            end)
        end)

        --#endregion
    end

local pui = setmetatable(pui, pui_mt)

local vector = require('vector')
local ffi = require("ffi")
local clipboard = require("gamesense/clipboard")
local base64 = require("gamesense/base64")
local adata = require("gamesense/antiaim_funcs")
local c_entity = require("gamesense/entity")
local csgo_weapons = require("gamesense/csgo_weapons")
local hitgroup_names = {"generic", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck", "?", "gear"}

local menu
local for_rendering
local ram
local active_state_id = 1
local brute_container = {}
local antibrute = {} do

    local function get_state_data(state_id)
        if not brute_container[state_id] then
            brute_container[state_id] = {
                add_yaw = 0,
                delay_mod = 0,
                pending_yaw = nil,
                pending_delay = nil,
                exec_tick = 0,
                reset_time = 0,
                last_miss_time = 0,
                meta_counter = 0,
            }
        end
        return brute_container[state_id]
    end

    local latest = 0

    function antibrute.closest_ray_point (p, s, e)
        local t, d = p - s, e - s
        local l = d:length()
        d = d / l
        local r = d:dot(t)
        if r < 0 then return s elseif r > l then return e end
        return s + d * r
    end

    local last_hit_tick = 0
    function antibrute.trigger (event)
        local lp = entity.get_local_player()
        if lp == nil or not entity.is_alive(lp) or latest == globals.tickcount() then return end

        local attacker = client.userid_to_entindex(event.userid)
        if not attacker or not entity.is_enemy(attacker) or entity.is_dormant(attacker) then return end

        local impact = vector(event.x, event.y, event.z)
        local enemy_view = vector(entity.get_origin(attacker))
        enemy_view.z = enemy_view.z + 64

        local players = entity.get_players()

        local dists = {}
        for i = 1, #players do
            local v = players[i]

            if not entity.is_enemy(v) then
                local head = vector(entity.hitbox_position(v, 0))
                local point = antibrute.closest_ray_point(head, enemy_view, impact)
                dists[#dists+1] = head:dist(point)
                if v == lp then dists.mine = dists[#dists] end
            end
        end

        local closest = math.min( unpack(dists) )

        if (dists.mine and closest) and dists.mine < 40 or (closest == dists.mine and dists.mine < 128) then
            local shot_tick = globals.tickcount()
            client.delay_call(0.01, function()
                if last_hit_tick == shot_tick then
                    return 
                end
                client.fire_event("pizdec:kitty:enemy_shot", {
                    damaged = false,
                    dist = dists.mine,
                    attacker = attacker,
                    userid = event.userid
                })
            end)

            latest = shot_tick
        end
    end

    function antibrute.schedule_brute(state_id)
        local data = get_state_data(state_id)
        local tab = menu.builder[state_id]
        if not tab then return end
        local mode = tab.brute_mode:get()
        if mode == 'Disabled' then return end

        local new_angle = 0

        if mode == 'Adaptive' or mode == 'Meta' then new_angle = math.random(-15, 15)
        elseif mode == 'Decrease' then new_angle = math.random(-15, -5)
        elseif mode == 'Increase' then new_angle = math.random(5, 15) end

        data.pending_yaw = new_angle
        if mode == 'Meta' then
            data.meta_counter = 0
        end
        if tab.delay_force:get() then
            data.pending_delay = math.random(2, 14)
        else
            data.pending_delay = 0
        end
        data.exec_tick = globals.tickcount() + math.random(2, 4)
    end

    function antibrute.handle_brute(state_id)
        local data = get_state_data(state_id)
        local cur_time = globals.realtime()

        if data.pending_yaw ~= nil and globals.tickcount() >= data.exec_tick then
            local yaw_val = data.pending_yaw
            local delay_val = data.pending_delay

            data.add_yaw = data.pending_yaw
            data.delay_mod = data.pending_delay
            data.pending_yaw = nil 
  
            local tab = menu.builder[state_id]
            local slider_val = tab and tab.duration_brute:get() or 0
            
            if slider_val > 0 then
                data.reset_time = cur_time + (slider_val / 10)
            else
                data.reset_time = 0
            end

            -- Console logs
            if not menu or not menu.visuals or not menu.visuals.logs or menu.visuals.logs:get() then
                local ar, ag, ab = 100, 100, 115
                local hr, hg, hb = 150, 150, 215
                if menu and menu.visuals then
                    if menu.visuals.logs_color1 then ar, ag, ab = menu.visuals.logs_color1:get() end
                    if menu.visuals.logs_color2 then hr, hg, hb = menu.visuals.logs_color2:get() end
                end
                local mode_val = tab and tab.brute_mode:get() or "Unknown"
                client.color_log(ar, ag, ab, "[project john] \0")
                client.color_log(hr, hg, hb, "Anti-bruteforce (" .. mode_val .. ") \0")
                client.color_log(ar, ag, ab, "[Yaw: \0")
                client.color_log(hr, hg, hb, tostring(yaw_val) .. "°\0")
                client.color_log(ar, ag, ab, " | Delay: \0")
                client.color_log(hr, hg, hb, tostring(delay_val) .. "\0")
                client.color_log(ar, ag, ab, "]\n")
            end

            -- Screen feed logs
            if menu and menu.visuals and menu.visuals.screen_logs and menu.visuals.screen_logs:get() and for_rendering then
                local mode_val = tab and tab.brute_mode:get() or "Unknown"
                local text = string.format("[project john] Anti-bruteforce (%s) [Yaw: %d° | Delay: %d]", mode_val, yaw_val, delay_val)
                table.insert(for_rendering, 1, {text = text, alpha = 0, add_y = 0, tick = globals.curtime() * 64, randomize = math.random(0, 100)})
            end
        end

        if data.reset_time > 0 then
            if cur_time >= data.reset_time then
                data.add_yaw = 0
                data.delay_mod = 0
                data.reset_time = 0
                data.pending_yaw = nil
            else
                local tab = menu.builder[state_id]
                local mode = tab and tab.brute_mode:get() or "Disabled"
                if mode == 'Meta' then
                    data.add_yaw = math.random(-15, 15)
                    if math.random(0, 1) == 1 then
                        data.meta_counter = (data.meta_counter or 0) + 1
                    end
                    if (data.meta_counter or 0) > 2 then
                        ram.jitter = not ram.jitter
                        data.meta_counter = 0
                    end
                end
            end
        end

        return data.add_yaw, data.delay_mod
    end

    client.set_event_callback("player_hurt", function(e)
        if client.userid_to_entindex(e.target_index) == entity.get_local_player() then
            if active_state_id then
                antibrute.schedule_brute(active_state_id)
            end
            last_hit_tick = globals.tickcount()
        end
    end)

    client.set_event_callback("bullet_impact", antibrute.trigger)

    client.set_event_callback("pizdec:kitty:enemy_shot", function(e)
        if active_state_id then
            antibrute.schedule_brute(active_state_id)
        end
    end)

    client.set_event_callback('round_start', function()
        brute_container = {}
    end)
end

local gratio = 1.6180339887
math.clamp = function (x, a, b) if a > x then return a elseif b < x then return b else return x end end
math.lerp = function (a, b, w)  return a + (b - a) * w  end
local function vec_3( _x, _y, _z ) return { x = _x or 0, y = _y or 0, z = _z or 0 } end
local function ticks_to_time2() return globals.tickinterval( ) * 16 end 

if(database.read("ZOV6667771337.base") == nil) then
    local base = {
        name = {"empty config"},
        cfg = {""}
    }
    database.write("ZOV6667771337.base", base)
end

local base = database.read("ZOV6667771337.base")

local ref = {
    aimbot = pui.reference('RAGE', 'Aimbot', 'Enabled'),
	enabled = pui.reference("AA", "Anti-aimbot angles", "Enabled"),
	pitch = {pui.reference("AA", "Anti-aimbot angles", "pitch")},
	yawbase = pui.reference("AA", "Anti-aimbot angles", "Yaw base"),
	yaw = {pui.reference("AA", "Anti-aimbot angles", "Yaw") },
    fakeyawlimit = {pui.reference("AA", "Anti-aimbot angles", "Body yaw")},
    fsbodyyaw = pui.reference("AA", "Anti-aimbot angles", "Freestanding body yaw"),
    edgeyaw = pui.reference("AA", "Anti-aimbot angles", "Edge yaw"),
    fakeduck = pui.reference("RAGE", "Other", "Duck peek assist"),
    safepoint = pui.reference("RAGE", "Aimbot", "Force safe point"),
	forcebaim = pui.reference("RAGE", "Aimbot", "Force body aim"),
	player_list = pui.reference("PLAYERS", "Players", "Player list"),
	reset_all = pui.reference("PLAYERS", "Players", "Reset all"),
	apply_all = pui.reference("PLAYERS", "Adjustments", "Apply to all"),
	load_cfg = pui.reference("Config", "Presets", "Load"),

    fl_enable = pui.reference("AA", "Fake lag", "Enabled"),
	fl_limit = pui.reference("AA", "Fake lag", "Limit"),
    fl_amount = pui.reference("AA", "Fake lag", "Amount"),
    fl_var = pui.reference("AA", "Fake lag", "Variance"),

	dt_limit = pui.reference("RAGE", "Aimbot", "Double tap fake lag limit"),

	quickpeek = pui.reference("RAGE", "Other", "Quick peek assist"),
	yawjitter = {pui.reference("AA", "Anti-aimbot angles", "Yaw jitter") },
	bodyyaw = {pui.reference("AA", "Anti-aimbot angles", "Body yaw") },
	freestand = {pui.reference("AA", "Anti-aimbot angles", "Freestanding") },
    roll = {pui.reference("AA", "Anti-aimbot angles", "Roll") },
	os = {pui.reference("AA", "Other", "On shot anti-aim") },
	slow = {pui.reference("AA", "Other", "Slow motion") },
	dt = {pui.reference("RAGE", "Aimbot", "Double tap")},
    dt = pui.reference("RAGE", "Aimbot", "Double tap"),
	hs = pui.reference("AA", "Other", "On shot anti-aim"),
	fakelag = pui.reference("AA", "Fake lag", "Enabled"),
    slow_motion = pui.reference("AA", "Other", "Slow motion"),
    menucol = pui.reference("MISC", "Settings", "Menu color"),
    mindmg = pui.reference("RAGE", "Aimbot", "Minimum damage override"),
    lmovement = pui.reference("AA", "Other", "Leg movement"),
    rage_cb = pui.reference("RAGE", "Aimbot", "Enabled"),
    fake_duck = pui.reference("RAGE","Other","Duck peek assist"),
}

local function normalize_yaw(val)
    if(val > 180) then
        val = val - 360
    elseif(val < -180) then
        val = val + 360
    end
    return val
end

local function time_to_ticks(t)
    return math.floor(0.5 + (t / globals.tickinterval()))
end

local defensive_check = {
    lc_left = 0,
    defensive = false,
    tickbase_max = 0,
    last_cmd = 0
}

function reset_def()
    defensive_check = {
        lc_left = 0,
        defensive = false,
        tickbase_max = 0,
        last_cmd = 0
    }
end

local function check_charge()
    local lp = entity.get_local_player()
    local m_nTickBase = entity.get_prop(lp, 'm_nTickBase')
    local client_latency = client.latency()
    local shift = math.floor(m_nTickBase - globals.tickcount() - 3 - time_to_ticks(client_latency) * .5 + .5 * (client_latency * 10))
    local wanted = -14 + (ref.dt_limit:get() - 1) + 3
    return shift <= wanted
end

function is_defensive_active(lp)
    if not check_charge() then return false end
    return defensive_check.defensive
end

local function calculate_angle(lpos, epos)
    local pos_diff = epos - lpos
    local angle = math.atan(pos_diff.y / pos_diff.x)
    angle = normalize_yaw(angle * 180 / math.pi)
    if pos_diff.x >= 0 then
        angle = normalize_yaw(angle + 180)
    end
    return angle
end

local lua = {
    conds = {"Global", "Standing", "Moving", "Slow-walking", "Jumping", "Jump-crouching", "Crouching", "Legit", "Manual", "Freestand", "Hidden"},
    conds_no_g = {"Standing", "Moving", "Slow-walking", "Jumping", "Jump-crouching", "Crouching", "Legit", "Manual", "Freestand"},
    short_conds = {"[G]", "[S]", "[M]", "[SW]", "[J]", "[JC]", "[C]", "[L]", "[MA]", "[FR]", "[H]"},
    hitgroup_mass = {'generic','head', 'chest', 'stomach','left arm', 'right arm','left leg', 'right leg','neck', 'generic', 'gear'},
}

local a_add = "\a3d4355FFa\r "
local m_add = "\a3d4355FFm\r "
local v_add = "\a3d4355FFv\r "
local aspect_table = {}

local function gcd(m, n)
	while m ~= 0 do
		m, n = math.fmod(n, m), m
	end

	return n
end

function aspect_ratio_table()
    local screen_width, screen_height = client.screen_size()
    for i = 1, 200 do
        local i2 = (200-i) * 0.01
		local divisor = gcd(screen_width * i2, screen_height)
		if screen_width * i2 / divisor < 100 or i2 == 1 then
			aspect_table[i] = screen_width * i2 / divisor .. ":" .. screen_height / divisor
		end
    end
end

aspect_ratio_table()

local cvar_opt_table = {
    "fog_enable",
    "r_dynamic",
    "r_drawtracers",
    "r_drawtracers_firstperson",
    "cl_foot_contact_shadows",
    "r_drawdecals",
    "func_break_max_pieces",
    "r_3dsky",
    "mat_bloomamount_rate",
    "r_updaterefracttexture",
    "r_lightinterp",
    "muzzleflash_light",
    "net_allow_multicast",
    "r_avglightmap",
    "rope_smooth",
    "rope_subdiv",
    "rope_wind_dist",
    "r_updaterefracttexture",
    "mat_yuv",
    "mat_bumpbasis",
    "mat_autoexposure_max",
}

local fps_cvar_values = {}

for i = 1, #cvar_opt_table do
    table.insert(fps_cvar_values, {cvar[cvar_opt_table[i]]:get_int(), cvar_opt_table[i]})
end

local fps_menu = {}

for i = 1, #fps_cvar_values do
    table.insert(fps_menu, fps_cvar_values[i][2])
end

local default_viewmodel_sets = {
    x = cvar.viewmodel_offset_x:get_float(),
    y = cvar.viewmodel_offset_y:get_float(),
    z = cvar.viewmodel_offset_z:get_float(),
    fov = cvar.viewmodel_fov:get_float(),
    active = false,
}

pui.accent = "9d4eddFF"

menu = {
    lbl1 = pui.label("AA", "Anti-aimbot angles", "Project John \b8d9bbc\b313847FF[dev edition]"),
    lbl2 = pui.label("AA", "Anti-aimbot angles", "Release \v[dev]"),
    enable = pui.checkbox("AA", "Anti-aimbot angles", "Enable script"),
    tab = pui.combobox("AA", "Anti-aimbot angles", "sections", {"\affc0cbFFMAIN", "-- Anti-aim", "-- visuals & miscellaneous", "-- configs"}),
    tab_fl = pui.combobox("AA", "Fake lag", "sections", {"\affc0cbFFOTHER","-- fake lag", "-- binds"}),

    
    

    -- nav_selector = pui.listbox("AA", "Anti-aimbot angles", "Navigation", {"global", "Anti-aim", "visuals & miscellaneous", "configs"}),
    fl_nav_selector = pui.listbox("AA", "Other", "Navigation", {"\affc0cbFFMAIN", "-- Anti-aim", "-- visuals & miscellaneous", "-- configs", "\affc0cbFFOTHER", "-- fake lag", "-- binds"}),

    fake_lag_amount = pui.combobox("AA", "Fake lag", "Amount ", {"Dynamic", "Maximum", "Fluctuate"}),
    fake_lag_variance = pui.slider("AA", "Fake lag", "Variance ", 0, 100, 1, true, "%"),
    fake_lag_limit = pui.slider("AA", "Fake lag", "Limit ", 1, 15, 15),

    mode = pui.combobox("AA", "Anti-aimbot angles", "Mode", {"Builder"}),
    state = pui.combobox("AA", "Anti-aimbot angles", "State", lua.conds),
    builder = {},
    aa_options = {
        yaw_base = pui.checkbox("AA", "Fake lag", "At target"),
        hide_yaw_override = pui.checkbox("AA", "Fake lag", "Hide yaw-overrides"),
        manual_base = pui.combobox("AA", "Fake lag", "Manual base", {"None", "Left", "Backward", "Right", "Forward"}),
        left = pui.hotkey("AA", "Fake lag", "Left manual"),
        backward = pui.hotkey("AA", "Fake lag", "Backward manual"),
        right = pui.hotkey("AA", "Fake lag", "Right manual"),
        forward = pui.hotkey("AA", "Fake lag", "Forward manual"),
        -- on_peek_or_always_on_manual = pui.combobox("AA", "Fake lag", "Defensive trigger", {"On peek", "Always on"}),
        funny_warmup = pui.checkbox("AA", "Fake lag", "Funny warmup"),
        freestand = pui.hotkey("AA", "Fake lag", "Freestand"),
        freestand_cond = pui.multiselect("AA", "Fake lag", "Freestand-work", lua.conds_no_g),

        defensive = pui.checkbox("AA", "Fake lag", "Defensive anti-aim enable"),
        static_on_def = pui.checkbox("AA", "Fake lag", "Static on Defensive anti-aim"),
        secret_exploit = pui.checkbox("AA", "Fake lag", "\aFFA500FFSecret exploit"),
        safe_head = pui.checkbox("AA", "Fake lag", "Safe head"),
    },
    visuals = {
        indicators = pui.checkbox("AA", "Anti-aimbot angles", "HUD center widgets"),
        indicator_y = pui.slider("AA", "Anti-aimbot angles", "HUD Y offset", 0, 200, 35),
        ind_color = pui.color_picker("AA", "Anti-aimbot angles", "HUD accent", 157,78,221,255),
        logs = pui.checkbox("AA", "Anti-aimbot angles", "Console logs"),
        logs_color1 = pui.color_picker("AA", "Anti-aimbot angles", "Accent color", 100,100,115,255),
        screen_logs = pui.checkbox("AA", "Anti-aimbot angles", "Screen feed"),
        screen_log_color = pui.color_picker("AA", "Anti-aimbot angles", "Feed accent", 157,78,221,255),
        lbl3 = pui.label("AA", "Anti-aimbot angles", "Hit color (feed)"),
        logs_color2 = pui.color_picker("AA", "Anti-aimbot angles", "Hit color", 150,150,215,255),
        lbl4 = pui.label("AA", "Anti-aimbot angles", "Miss color (feed)"),
        logs_color3 = pui.color_picker("AA", "Anti-aimbot angles", "Miss color", 200,120,120,255),
        aspect_ratio_type = pui.combobox("AA", "Anti-aimbot angles", "Aspect ratio mode", {"Disabled", "Normal", "Newcomer"}),
        normal_aspect_ratio = pui.slider("AA", "Anti-aimbot angles", "aspect ratio", 0, 200, 100, true, "%", 1, aspect_table),
        newcomer_aspect_ratio = pui.slider("AA", "Anti-aimbot angles", "aspect ratio ", 0, 200, 177, true, "", 0.01),
    },
    misc = {
        resolver = pui.checkbox("AA", "Anti-aimbot angles", "Resolver"),
        predict = pui.hotkey("AA", "Anti-aimbot angles", "Predict"),
        predict_mode = pui.combobox("AA", "Anti-aimbot angles", "Predict Mode", {"Default", "Experimental"}),
        -- btexp = pui.checkbox("AA", "Anti-aimbot angles", "Force Backtrack", function()            
        --     cmd.tickbase_shift = 16
        -- end),
        aimtools_enable = pui.checkbox("AA", "Anti-aimbot angles", "Aimtools"),
        aimtools = {
            weapon = pui.combobox("AA", "Anti-aimbot angles", "Weapons", {"Desert Eagle", "SSG 08", "AWP"}),
            deagle = {
                mode1 = pui.multiselect("AA", "Anti-aimbot angles", "Desert Eagle Mode", {"If HP lower than X", "If lethal"}),
                ifhp = pui.slider("AA", "Anti-aimbot angles", "Desert Eagle HP threshold", 1, 100, 50),
                mode2 = pui.multiselect("AA", "Anti-aimbot angles", "Desert Eagle Override", {"Force Safe Point", "Prefer Safe Point", "Force Body Aim", "Prefer Body Aim"}),
            },
            ssg08 = {
                mode1 = pui.multiselect("AA", "Anti-aimbot angles", "SSG-08 Mode", {"If HP lower than X", "If lethal"}),
                ifhp = pui.slider("AA", "Anti-aimbot angles", "SSG-08 HP threshold", 1, 100, 50),
                mode2 = pui.multiselect("AA", "Anti-aimbot angles", "SSG-08 Override", {"Force Safe Point", "Prefer Safe Point", "Force Body Aim", "Prefer Body Aim"}),
            },
            awp = {
                mode1 = pui.multiselect("AA", "Anti-aimbot angles", "AWP Mode", {"If HP lower than X", "If lethal"}),
                ifhp = pui.slider("AA", "Anti-aimbot angles", "AWP HP threshold", 1, 100, 50),
                mode2 = pui.multiselect("AA", "Anti-aimbot angles", "AWP Override", {"Force Safe Point", "Prefer Safe Point", "Force Body Aim", "Prefer Body Aim"}),
            },
        },
        -- dt_recharge = pui.checkbox("AA", "Anti-aimbot angles", "DT recharge"),
        nl_recharge = pui.checkbox("AA", "Anti-aimbot angles", "NL recharge"),
        fast_ladder = pui.checkbox("AA", "Anti-aimbot angles", "Fast ladder"),
        avoid_backstab = pui.checkbox("AA", "Anti-aimbot angles", "Avoid backstab"),
        teammate_whitelist = pui.checkbox("AA", "Anti-aimbot angles", "Allowing teammates shared-ESP"),
        cvar_optimizer = pui.multiselect("AA", "Anti-aimbot angles", "Cvar optimizer", fps_menu),
        filter_console = pui.checkbox("AA", "Anti-aimbot angles", "Filterconsole"),
        viewmodel_enable = pui.checkbox("AA", "Anti-aimbot angles", "View model"),
        viewmodel = {
            x = pui.slider("AA", "Anti-aimbot angles", "Viewmodel x", -100, 100, cvar.viewmodel_offset_x:get_int() * 10, true, "", 0.1, true),
            y = pui.slider("AA", "Anti-aimbot angles", "Viewmodel y", -100, 100, cvar.viewmodel_offset_y:get_int() * 10, true, "", 0.1, true),
            z = pui.slider("AA", "Anti-aimbot angles", "Viewmodel z", -100, 100, cvar.viewmodel_offset_z:get_int() * 10, true, "", 0.1, true),
            fov = pui.slider("AA", "Anti-aimbot angles", "Viewmodel fov", 0, 120, cvar.viewmodel_fov:get_int()),
        },
        animfix = pui.multiselect("AA", "Anti-aimbot angles", "Animbreakers!", {"Legs", "Jumping", "Dirty sprite", "Static in air", "Move lean"}),
        static_in_air_value = pui.slider("AA", "Anti-aimbot angles", "Static in air value", 0, 100, 50, true, "%"),
        move_lean_value = pui.slider("AA", "Anti-aimbot angles", "Move lean value", 0, 100, 50, true, "%"),
        debug = pui.checkbox("AA", "Anti-aimbot angles", "Developer mode"),
        duck_peek_assist_fix = pui.checkbox("AA", "Anti-aimbot angles", "Crouch with duck peek assist"),
        auto_exploit = pui.checkbox("AA", "Anti-aimbot angles", "Auto exploit switch"),
        auto_exploit_states = pui.multiselect("AA", "Anti-aimbot angles", "\nAuto exploit states", { "Standing", "Walking", "Crouching", "Sneaking" }),
        auto_exploit_avoid = pui.multiselect("AA", "Anti-aimbot angles", "Auto exploit avoid", { "Pistols", "Desert Eagle", "Auto snipers", "Desert Eagle + Crouch" }),
        extrap_enable = pui.checkbox("AA", "Anti-aimbot angles", "Enable Extrapolation"),
        extrap_preserve_valid = pui.checkbox("AA", "Anti-aimbot angles", "Preserve valid records"),
        extrap_record_window = pui.slider("AA", "Anti-aimbot angles", "Record window size", 1, 8, 4, true, "t"),
        extrap_disable_interp = pui.checkbox("AA", "Anti-aimbot angles", "Disable window interpolation"),
        extrap_ticks = pui.slider("AA", "Anti-aimbot angles", "Max extrapolation ticks", 1, 8, 4, true, "t"),
        extrap_tick_adjust = pui.combobox("AA", "Anti-aimbot angles", "Extrap tick adjust", {"No reduction", "Reduce by 1", "Reduce by 2"}),
        extrap_zero_z = pui.checkbox("AA", "Anti-aimbot angles", "Zero extrap velocity Z"),
    },
    cfg = {
        list = pui.listbox("AA", "Anti-aimbot angles", "Profiles", base.name),
        name = pui.textbox("AA", "Anti-aimbot angles", "Profile name"),
        load = pui.button("AA", "Anti-aimbot angles", "Load profile", function() load() end),
        saveing = pui.button("AA", "Anti-aimbot angles", "Save profile", function() save() end),
        create = pui.button("AA", "Anti-aimbot angles", "\v+\r New profile", function() create() end),
        delete = pui.button("AA", "Anti-aimbot angles", "\v-\r Remove profile", function() delete() end),
        import = pui.button("AA", "Anti-aimbot angles", "Import profile (clipboard)", function() import() end),
        export = pui.button("AA", "Anti-aimbot angles", "Export profile (clipboard)", function() export() end),
    },
}

menu.tab:set_visible(false)
menu.tab_fl:set_visible(false)

menu.fake_lag_amount:depend(menu.enable, {menu.tab_fl, "-- fake lag"})
menu.fake_lag_variance:depend(menu.enable, {menu.tab_fl, "-- fake lag"})
menu.fake_lag_limit:depend(menu.enable, {menu.tab_fl, "-- fake lag"})

 

-- New navigation logic
-- menu.nav_selector:depend(menu.enable, {menu.tab, "global"})
-- menu.nav_selector:set_callback(function()
--     local idx = menu.nav_selector:get()
--     local options = {"global", "Anti-aim", "visuals & miscellaneous", "configs"}
--     menu_seta(options[idx + 1])
-- end)

menu.fl_nav_selector:depend(menu.enable)
menu.fl_nav_selector:set_callback(function()
    local idx = menu.fl_nav_selector:get()
    if idx <= 3 then
        local main = {"MAIN", "-- Anti-aim", "-- visuals & miscellaneous", "-- configs"}
        if idx == 0 then -- MAIN
            menu.fl_nav_selector:set(1) -- Переключаем на Anti-aim
            menu_seta("-- Anti-aim")
        else
            menu_seta(main[idx + 1])
        end
    else
        local fl = {"OTHER", "-- fake lag", "-- binds"}
        if idx == 4 then -- OTHER
            menu.fl_nav_selector:set(5) -- Переключаем на fake lag
            menu_seta_fl("-- fake lag")
        else
            menu_seta_fl(fl[idx - 3])
        end
    end
end)

-- legacy buttons removed


function menu_seta_fl(val)
    menu.tab_fl:set(val)
end

function menu_seta(val)
    menu.tab:set(val)
end

function viewmodel_set()
    if menu.misc.viewmodel_enable:get() then
        if default_viewmodel_sets.active == false then
            default_viewmodel_sets.x = cvar.viewmodel_offset_x:get_float()
            default_viewmodel_sets.y = cvar.viewmodel_offset_y:get_float()
            default_viewmodel_sets.z = cvar.viewmodel_offset_z:get_float()
            default_viewmodel_sets.fov = cvar.viewmodel_fov:get_float()
            default_viewmodel_sets.active = true
        end
        client.set_cvar("viewmodel_offset_x", menu.misc.viewmodel.x:get() / 10)
        client.set_cvar("viewmodel_offset_y", menu.misc.viewmodel.y:get() / 10)
        client.set_cvar("viewmodel_offset_z", menu.misc.viewmodel.z:get() / 10)
        client.set_cvar("viewmodel_fov", menu.misc.viewmodel.fov:get())
    else
        default_viewmodel_sets.active = false
        client.set_cvar("viewmodel_offset_x", default_viewmodel_sets.x)
        client.set_cvar("viewmodel_offset_y", default_viewmodel_sets.y)
        client.set_cvar("viewmodel_offset_z", default_viewmodel_sets.z)
        client.set_cvar("viewmodel_fov", default_viewmodel_sets.fov)
    end
end

menu.misc.viewmodel_enable:set_callback(function() viewmodel_set() end)
menu.misc.viewmodel.x:set_callback(function() viewmodel_set() end)
menu.misc.viewmodel.y:set_callback(function() viewmodel_set() end)
menu.misc.viewmodel.z:set_callback(function() viewmodel_set() end)
menu.misc.viewmodel.fov:set_callback(function() viewmodel_set() end)

function fps_opt()
    for i = 1, #fps_cvar_values do
        if menu.misc.cvar_optimizer:get(fps_cvar_values[i][2]) then
            cvar[fps_cvar_values[i][2]]:set_int(0)
        else
            cvar[fps_cvar_values[i][2]]:set_int(fps_cvar_values[i][1])
        end
    end
end

function filter_console()
    if menu.misc.filter_console:get() then
        cvar.con_filter_enable:set_int(1)
        cvar.con_filter_text:set_string("IrWL5106TZZKNFPz4P4Gl3pSN?J370f5hi373ZjPg%VOVh6lN")
        client.exec("con_filter_enable 1")
    else
        cvar.con_filter_enable:set_int(0)
        cvar.con_filter_text:set_string("")
        client.exec("con_filter_enable 0")
    end
end

function set_menu_builder()
    if ui.is_menu_open() then
        if menu.enable:get() then
            if menu.misc.debug:get() then
                state = true
            else
                state = false
            end
        else
            state = true
        end
        ref.fl_enable:set_visible(state)
        ref.fl_limit:set_visible(state)
        ref.fl_amount:set_visible(state)
        ref.fl_var:set_visible(state)
        ref.enabled:set_visible(state)
        ref.pitch[1]:set_visible(state)
        ref.pitch[2]:set_visible(state)
        ref.yawbase:set_visible(state)
        ref.yaw[1]:set_visible(state)
        ref.yaw[2]:set_visible(state)
        ref.fakeyawlimit[1]:set_visible(state)
        ref.fakeyawlimit[2]:set_visible(state)
        ref.fsbodyyaw:set_visible(state)
        ref.edgeyaw:set_visible(state)
        ref.yawjitter[1]:set_visible(state)
        ref.yawjitter[2]:set_visible(state)
        ref.freestand[1]:set_visible(state)
        ref.roll[1]:set_visible(state)
    end
end

client.set_event_callback("shutdown", function()
    ref.enabled:set_visible(true)
    ref.pitch[1]:set_visible(true)
    ref.pitch[2]:set_visible(true)
    ref.yawbase:set_visible(true)
    ref.yaw[1]:set_visible(true)
    ref.yaw[2]:set_visible(true)
    ref.fakeyawlimit[1]:set_visible(true)
    ref.fakeyawlimit[2]:set_visible(true)
    ref.fsbodyyaw:set_visible(true)
    ref.edgeyaw:set_visible(true)
    ref.yawjitter[1]:set_visible(true)
    ref.yawjitter[2]:set_visible(true)
    ref.freestand[1]:set_visible(true)
    ref.roll[1]:set_visible(true)
end)

menu.cfg.list:depend(menu.enable, {menu.tab, "-- configs"})
menu.cfg.name:depend(menu.enable, {menu.tab, "-- configs"})
menu.cfg.load:depend(menu.enable, {menu.tab, "-- configs"})
menu.cfg.saveing:depend(menu.enable, {menu.tab, "-- configs"})
menu.cfg.create:depend(menu.enable, {menu.tab, "-- configs"})
menu.cfg.delete:depend(menu.enable, {menu.tab, "-- configs"})
menu.cfg.import:depend(menu.enable, {menu.tab, "-- configs"})
menu.cfg.export:depend(menu.enable, {menu.tab, "-- configs"})

local manu = {
    left = false,
    backward = false,
    right = false,
    forward = false,
    leftdump = 0,
    backwarddump = 0,
    rightdump = 0,
    forwarddump = 0,
}

function manualing()
    if(menu.aa_options.left:get()) then
        if manu.leftdump <= 2 then
            manu.leftdump = manu.leftdump + 1
        end
    else
        manu.leftdump = 0
    end
    if(menu.aa_options.backward:get()) then
        if manu.backwarddump <= 2 then
            manu.backwarddump = manu.backwarddump + 1
        end
    else
        manu.backwarddump = 0
    end
    if(menu.aa_options.right:get()) then
        if manu.rightdump <= 2 then
            manu.rightdump = manu.rightdump + 1
        end
    else
        manu.rightdump = 0
    end
    if(menu.aa_options.forward:get()) then
        if manu.forwarddump <= 2 then
            manu.forwarddump = manu.forwarddump + 1
        end
    else
        manu.forwarddump = 0
    end
    local poisk = math.huge
    local minsh = 0
    for i = 1, 4 do
        if(i == 1) then
            val = manu.leftdump
        elseif(i == 2) then
            val = manu.backwarddump
        elseif(i == 3) then
            val = manu.rightdump
        elseif(i == 4) then
            val = manu.forwarddump
        end
        if(val < poisk and val ~= 0) then
            poisk = val
            minsh = i
        end
    end
    if(minsh ~= 0) then
        if(poisk == 1) then
            if(minsh == 1) then
                if(menu.aa_options.manual_base:get() ~= "Left") then
                    menu.aa_options.manual_base:set("Left")
                elseif(menu.aa_options.manual_base:get() == "Left") then
                    menu.aa_options.manual_base:set("None")
                end
            elseif(minsh == 2) then
                if(menu.aa_options.manual_base:get() ~= "Backward") then
                    menu.aa_options.manual_base:set("Backward")
                elseif(menu.aa_options.manual_base:get() == "Backward") then
                    menu.aa_options.manual_base:set("None")
                end
            elseif(minsh == 3) then
                if(menu.aa_options.manual_base:get() ~= "Right") then
                    menu.aa_options.manual_base:set("Right")
                elseif(menu.aa_options.manual_base:get() == "Right") then
                    menu.aa_options.manual_base:set("None")
                end
            elseif(minsh == 4) then
                if(menu.aa_options.manual_base:get() ~= "Forward") then
                    menu.aa_options.manual_base:set("Forward")
                elseif(menu.aa_options.manual_base:get() == "Forward") then
                    menu.aa_options.manual_base:set("None")
                end
            end
        end
    end
end

function fast_ladder(cmd, lp)
    local pitch, yaw = client.camera_angles()
    if (entity.get_prop(lp, "m_MoveType") == 9) then
        cmd.yaw = math.floor(cmd.yaw + 0.5)
        cmd.roll = 0
        if cmd.forwardmove > 0 then
            if pitch < 45 then
                cmd.pitch = 89
                cmd.in_moveright = 1
                cmd.in_moveleft = 0
                cmd.in_forward = 0
                cmd.in_back = 1
                if cmd.sidemove == 0 then
                    cmd.yaw = cmd.yaw + 90
                end
                if cmd.sidemove < 0 then
                    cmd.yaw = cmd.yaw + 150
                end
                if cmd.sidemove > 0 then
                    cmd.yaw = cmd.yaw + 30
                end
            end 
        end
        if cmd.forwardmove < 0 then
            cmd.pitch = 89
            cmd.in_moveleft = 1
            cmd.in_moveright = 0
            cmd.in_forward = 1
            cmd.in_back = 0
            if cmd.sidemove == 0 then
                cmd.yaw = cmd.yaw + 90
            end
            if cmd.sidemove > 0 then
                cmd.yaw = cmd.yaw + 150
            end
            if cmd.sidemove < 0 then
                cmd.yaw = cmd.yaw + 30
            end
        end
    end
end


local en = {menu.enable, true}
local menutab = {menu.tab, "-- Anti-aim"}
local misctab = {menu.tab, "-- visuals & miscellaneous"}
local visuals = {menu.tab, "-- visuals & miscellaneous"}

menu.mode:depend(en, menutab, aa_options)
menu.state:depend(en, menutab, aa_options, {menu.mode, "Builder"})

menu.aa_options.yaw_base:depend(en, {menu.tab_fl, "-- binds"})
menu.aa_options.hide_yaw_override:depend(en, {menu.tab_fl, "-- binds"})
menu.aa_options.manual_base:depend(en, {menu.tab_fl, "-- binds"}, {menu.aa_options.hide_yaw_override, false})
menu.aa_options.left:depend(en, {menu.tab_fl, "-- binds"}, {menu.aa_options.hide_yaw_override, false})
menu.aa_options.backward:depend(en, {menu.tab_fl, "-- binds"}, {menu.aa_options.hide_yaw_override, false})
menu.aa_options.right:depend(en, {menu.tab_fl, "-- binds"}, {menu.aa_options.hide_yaw_override, false})
menu.aa_options.forward:depend(en, {menu.tab_fl, "-- binds"}, {menu.aa_options.hide_yaw_override, false})
-- menu.aa_options.on_peek_or_always_on_manual:depend(en, {menu.tab_fl, "-- binds"}, {menu.aa_options.hide_yaw_override, false})
menu.aa_options.funny_warmup:depend(en, {menu.tab_fl, "-- binds"}, {menu.aa_options.hide_yaw_override, false})
menu.aa_options.freestand:depend(en, {menu.tab_fl, "-- binds"}, {menu.aa_options.hide_yaw_override, false})
menu.aa_options.freestand_cond:depend(en, {menu.tab_fl, "-- binds"}, {menu.aa_options.hide_yaw_override, false})

menu.aa_options.defensive:depend(en, {menu.tab_fl, "-- binds"})
menu.aa_options.static_on_def:depend(en, {menu.tab_fl, "-- binds"})
menu.aa_options.secret_exploit:depend(en, {menu.tab_fl, "-- binds"})
menu.aa_options.safe_head:depend(en, {menu.tab_fl, "-- binds"})

menu.misc.resolver:depend(en, misctab)
menu.misc.predict:depend(en, misctab)
menu.misc.predict_mode:depend(en, misctab)
-- menu.misc.btexp:depend(en, misctab)
menu.misc.aimtools_enable:depend(en, misctab)
menu.misc.aimtools.weapon:depend(en, misctab, menu.misc.aimtools_enable)
menu.misc.aimtools.deagle.mode1:depend(en, misctab, menu.misc.aimtools_enable, {menu.misc.aimtools.weapon, "Desert Eagle"})
menu.misc.aimtools.deagle.ifhp:depend(en, misctab, menu.misc.aimtools_enable, {menu.misc.aimtools.deagle.mode1, "If HP lower than X"}, {menu.misc.aimtools.weapon, "Desert Eagle"})
menu.misc.aimtools.deagle.mode2:depend(en, misctab, menu.misc.aimtools_enable, {menu.misc.aimtools.weapon, "Desert Eagle"})
menu.misc.aimtools.ssg08.mode1:depend(en, misctab, menu.misc.aimtools_enable, {menu.misc.aimtools.weapon, "SSG 08"})
menu.misc.aimtools.ssg08.ifhp:depend(en, misctab, menu.misc.aimtools_enable, {menu.misc.aimtools.ssg08.mode1, "If HP lower than X"}, {menu.misc.aimtools.weapon, "SSG 08"})
menu.misc.aimtools.ssg08.mode2:depend(en, misctab, menu.misc.aimtools_enable, {menu.misc.aimtools.weapon, "SSG 08"})
menu.misc.aimtools.awp.mode1:depend(en, misctab, menu.misc.aimtools_enable, {menu.misc.aimtools.weapon, "AWP"})
menu.misc.aimtools.awp.ifhp:depend(en, misctab, menu.misc.aimtools_enable, {menu.misc.aimtools.awp.mode1, "If HP lower than X"}, {menu.misc.aimtools.weapon, "AWP"})
menu.misc.aimtools.awp.mode2:depend(en, misctab, menu.misc.aimtools_enable, {menu.misc.aimtools.weapon, "AWP"})
-- menu.misc.dt_recharge:depend(en, misctab)
menu.misc.nl_recharge:depend(en, misctab)
menu.misc.fast_ladder:depend(en, misctab)
menu.misc.avoid_backstab:depend(en, misctab)
menu.misc.teammate_whitelist:depend(en, misctab)
menu.misc.debug:depend(en, misctab)
menu.misc.animfix:depend(en, misctab)
menu.misc.cvar_optimizer:depend(en, misctab)
menu.misc.filter_console:depend(en, misctab)
menu.misc.viewmodel_enable:depend(en, misctab)
menu.misc.viewmodel.x:depend(en, misctab, menu.misc.viewmodel_enable)
menu.misc.viewmodel.y:depend(en, misctab, menu.misc.viewmodel_enable)
menu.misc.viewmodel.z:depend(en, misctab, menu.misc.viewmodel_enable)
menu.misc.viewmodel.fov:depend(en, misctab, menu.misc.viewmodel_enable)
menu.misc.duck_peek_assist_fix:depend(en, misctab)
menu.misc.auto_exploit:depend(en, misctab)
menu.misc.auto_exploit_states:depend(en, misctab, menu.misc.auto_exploit)
menu.misc.auto_exploit_avoid:depend(en, misctab, menu.misc.auto_exploit)
menu.misc.extrap_enable:depend(en, misctab)
menu.misc.extrap_preserve_valid:depend(en, misctab, menu.misc.extrap_enable)
menu.misc.extrap_record_window:depend(en, misctab, menu.misc.extrap_enable, menu.misc.extrap_preserve_valid)
menu.misc.extrap_disable_interp:depend(en, misctab, menu.misc.extrap_enable)
menu.misc.extrap_ticks:depend(en, misctab, menu.misc.extrap_enable)
menu.misc.extrap_tick_adjust:depend(en, misctab, menu.misc.extrap_enable)
menu.misc.extrap_zero_z:depend(en, misctab, menu.misc.extrap_enable)
menu.misc.static_in_air_value:depend(en, misctab, {menu.misc.animfix, "Static in air"})
menu.misc.move_lean_value:depend(en, misctab, {menu.misc.animfix, "Move lean"})

menu.aa_options.defensive:set_visible(false)
menu.aa_options.static_on_def:set_visible(false)
menu.aa_options.secret_exploit:set_visible(false)
menu.visuals.indicators:depend(en, visuals)
menu.visuals.indicator_y:depend(en, visuals, menu.visuals.indicators)
menu.visuals.ind_color:depend(en, visuals, menu.visuals.indicators)
menu.visuals.logs:depend(en, visuals)
menu.visuals.logs_color1:depend(en, visuals, menu.visuals.logs)
menu.visuals.screen_logs:depend(en, visuals, menu.visuals.logs)
menu.visuals.screen_log_color:depend(en, visuals, menu.visuals.logs)
menu.visuals.lbl3:depend(en, visuals, menu.visuals.logs)
menu.visuals.logs_color2:depend(en, visuals, menu.visuals.logs)
menu.visuals.lbl4:depend(en, visuals, menu.visuals.logs)
menu.visuals.logs_color3:depend(en, visuals, menu.visuals.logs)
menu.visuals.aspect_ratio_type:depend(en, visuals)
menu.visuals.normal_aspect_ratio:depend(en, visuals, {menu.visuals.aspect_ratio_type, "Normal"})
menu.visuals.newcomer_aspect_ratio:depend(en, visuals, {menu.visuals.aspect_ratio_type, "Newcomer"})

function aspect_ratio()
    if menu.visuals.aspect_ratio_type:get() ~= "Disabled" and menu.enable:get() then
        if menu.visuals.aspect_ratio_type:get() == "Normal" then
            local mult = menu.visuals.normal_aspect_ratio:get() * 0.01
            mult = 2 - mult
            local screen_width, screen_height = client.screen_size()
            local aspectratio_value = (screen_width * mult) / screen_height
        
            if mult == 1 then
                aspectratio_value = 0
            end
            client.set_cvar("r_aspectratio", tonumber(aspectratio_value))
        else
            local mult = menu.visuals.newcomer_aspect_ratio:get() * 0.01
            client.set_cvar("r_aspectratio", mult)
        end
    else
        client.set_cvar("r_aspectratio", 0)
    end
end

for i = 1, (#lua.conds - 1) do
    local dobavok = "\a3d4355FF" .. lua.short_conds[i] .. "\r "
    local dobavok_d = "\a3d4355FF" .. lua.short_conds[i] .. " [D]\r "
    menu.builder[i] = {
        enable = pui.checkbox("AA", "Anti-aimbot angles", "\a3d4355FF" .. lua.conds[i] .. "\r State enable"),
        pitch = pui.combobox("AA", "Anti-aimbot angles", dobavok .. "Pitch", {"Off", "Down", "Up"}),
        yaw_default = pui.slider("AA", "Anti-aimbot angles", dobavok .. "Yaw-offset", -180, 180, 0),
        yaw_add = pui.combobox("AA", "Anti-aimbot angles", dobavok .. "Yaw-add", {"Off", "Left & right"}),
        yaw_left = pui.slider("AA", "Anti-aimbot angles", dobavok .. "Yaw-add left", -180, 180, 0),
        yaw_right = pui.slider("AA", "Anti-aimbot angles", dobavok .. "Yaw-add right", -180, 180, 0),
        yaw = pui.combobox("AA", "Anti-aimbot angles", dobavok .. "Yaw", {"Center", --[["Slow",]] "Advanced skitter"}),
        yaw_center = pui.slider("AA", "Anti-aimbot angles", "\n" .. "\a00000000" .. lua.conds[i] .. "Yaw", -180, 180, 0),
        xway_ways = pui.slider("AA", "Anti-aimbot angles", dobavok .. "X-Way ways", 3, 10, 3),
        xway_jitter = pui.slider("AA", "Anti-aimbot angles", dobavok .. "X-Way jitter", -90, 90, 0, 1, "°"),
        yaw_randomize = pui.slider("AA", "Anti-aimbot angles", dobavok .. "Randomize", 0, 100, 0, 1, "%"),
        double_tick_update = pui.checkbox("AA", "Anti-aimbot angles", dobavok .. "Double tick-update"),
        tick_update = pui.slider("AA", "Anti-aimbot angles", dobavok .. "Tick-update", 0, 14, 2),
        tick_update_second = pui.slider("AA", "Anti-aimbot angles", dobavok .. "Tick-update second", 0, 14, 2),
        body_yaw = pui.combobox("AA", "Anti-aimbot angles", dobavok .. "Body yaw", {"Off", "Jitter", "Jitter v2", "Smart", "Opposite", "Static"}),
        body_yaw_degree = pui.slider("AA", "Anti-aimbot angles", dobavok .. "Fake yaw", -180, 180, 0),
        body_yaw_degree1 = pui.slider("AA", "Anti-aimbot angles", dobavok .. "Left", -180, 180, 0),
        body_yaw_degree2 = pui.slider("AA", "Anti-aimbot angles", dobavok .. "Right", -180, 180, 0),
        lb_brute = pui.label("AA", "Anti-aimbot angles", dobavok .. "Antibrute Settings"),
        brute_mode = pui.combobox("AA", "Anti-aimbot angles", dobavok .. "Antibrute Mode", {"Disabled", "Adaptive", "Decrease", "Increase", "Meta"}),
        delay_force = pui.checkbox("AA", "Anti-aimbot angles", dobavok .. "Force Delay"),
        duration_brute = pui.slider("AA", "Anti-aimbot angles", dobavok .. "Duration", 0, 100, 0, true, "s", 0.1, {[0] = "inf"}),
        force_defensive = pui.checkbox("AA", "Anti-aimbot angles", dobavok .. "Force Defensive"),
        defensive = pui.checkbox("AA", "Anti-aimbot angles", dobavok .. "Defensive aa"),
        d_pitch = pui.combobox("AA", "Anti-aimbot angles", dobavok_d .. "Pitch", {"Static", "Lerp", "Random", "Jitter", "Sway"}),
        d_pitch_degree = pui.slider("AA", "Anti-aimbot angles", "\n" .. "\a00000000" .. lua.conds[i] .. dobavok_d .. "pitch degree", -89, 89, 50),
        d_pitch_range = pui.slider("AA", "Anti-aimbot angles", dobavok_d .. "Pitch range", 0, 180, 50),
        d_pitch_speed = pui.slider("AA", "Anti-aimbot angles", dobavok_d .. "Pitch change speed", 0, 90, 0),
        d_pitch_skip = pui.slider("AA", "Anti-aimbot angles", dobavok_d .. "Skip ticks", 0, 24, 0),
        d_pitch_random_skip = pui.checkbox("AA", "Anti-aimbot angles", dobavok_d .. "Random skip"),
        d_pitch_skip_min = pui.slider("AA", "Anti-aimbot angles", dobavok_d .. "Skip min", 0, 24, 0),
        d_pitch_skip_max = pui.slider("AA", "Anti-aimbot angles", dobavok_d .. "Skip max", 0, 24, 12),
        d_pitch_random_min = pui.slider("AA", "Anti-aimbot angles", dobavok_d .. "Random min", -89, 89, -89),
        d_pitch_random_max = pui.slider("AA", "Anti-aimbot angles", dobavok_d .. "Random max", -89, 89, 89),
        d_pitch_random_delay = pui.slider("AA", "Anti-aimbot angles", dobavok_d .. "Random delay", 0, 24, 0),
        d_pitch_random_delay_enable = pui.checkbox("AA", "Anti-aimbot angles", dobavok_d .. "Random delay enable"),
        d_pitch_random_delay_min = pui.slider("AA", "Anti-aimbot angles", dobavok_d .. "Random delay min", 0, 24, 0),
        d_pitch_random_delay_max = pui.slider("AA", "Anti-aimbot angles", dobavok_d .. "Random delay max", 0, 24, 12),
        d_yaw = pui.combobox("AA", "Anti-aimbot angles", dobavok_d .. "Yaw", {"Off", "Freestand", "Forward", "Spin", "180 z", "Slow spin", "Sideways", "Random", "Sin", "Flick"}),
        d_tick_update = pui.slider("AA", "Anti-aimbot angles", dobavok_d .. "Tick-update", 0, 14, 2),
        d_offset = pui.slider("AA", "Anti-aimbot angles", dobavok_d .. "Defensive yaw-offset", -180, 180, 0),
    }
    if i ~= 1 and lua.conds[i] ~= "Hidden" then
        menu.builder[i].enable:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]})
    else
        menu.builder[i].enable:set_visible(menu.misc.debug:get())
    end
    menu.builder[i].pitch:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable)
    menu.builder[i].yaw_default:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable)
    menu.builder[i].yaw:depend(en,menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable)
    menu.builder[i].double_tick_update:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable--[[, {menu.builder[i].yaw, "Slow"}]])
    menu.builder[i].tick_update:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable--[[, {menu.builder[i].yaw, "Slow"}]])
    menu.builder[i].tick_update_second:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable--[[, {menu.builder[i].yaw, "Slow"}]], menu.builder[i].double_tick_update)
    menu.builder[i].yaw_center:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, {menu.builder[i].yaw, "Off", true}, {menu.builder[i].yaw, "Advanced skitter", true})
    menu.builder[i].xway_ways:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, {menu.builder[i].yaw, "Advanced skitter"})
    menu.builder[i].xway_jitter:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, {menu.builder[i].yaw, "Advanced skitter"})
    menu.builder[i].yaw_randomize:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, {menu.builder[i].yaw, "Off", true})
    menu.builder[i].yaw_add:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable)
    menu.builder[i].yaw_left:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, {menu.builder[i].yaw_add, "Left & right"})
    menu.builder[i].yaw_right:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, {menu.builder[i].yaw_add, "Left & right"})
    menu.builder[i].body_yaw:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable)
    menu.builder[i].body_yaw_degree:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, {menu.builder[i].body_yaw, function() return menu.builder[i].body_yaw:get() == "Jitter" or menu.builder[i].body_yaw:get() == "Static" end})
    menu.builder[i].body_yaw_degree1:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, {menu.builder[i].body_yaw, "Jitter v2"})
    menu.builder[i].body_yaw_degree2:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, {menu.builder[i].body_yaw, "Jitter v2"})
    menu.builder[i].force_defensive:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable)
    menu.builder[i].defensive:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive)
    menu.builder[i].d_pitch:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive)
    menu.builder[i].d_pitch_degree:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_pitch, function() return menu.builder[i].d_pitch:get() == "Static" or menu.builder[i].d_pitch:get() == "Sway" end})
    menu.builder[i].d_pitch_range:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_pitch, "Sway"})
    menu.builder[i].d_pitch_speed:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_pitch, "Sway"})
    menu.builder[i].d_pitch_skip:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_pitch, "Sway"}, {menu.builder[i].d_pitch_random_skip, false})
    menu.builder[i].d_pitch_random_skip:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_pitch, "Sway"})
    menu.builder[i].d_pitch_skip_min:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_pitch, "Sway"}, menu.builder[i].d_pitch_random_skip)
    menu.builder[i].d_pitch_skip_max:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_pitch, "Sway"}, menu.builder[i].d_pitch_random_skip)
    menu.builder[i].d_pitch_random_min:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_pitch, "Random"})
    menu.builder[i].d_pitch_random_max:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_pitch, "Random"})
    menu.builder[i].d_pitch_random_delay:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_pitch, "Random"}, {menu.builder[i].d_pitch_random_delay_enable, false})
    menu.builder[i].d_pitch_random_delay_enable:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_pitch, "Random"})
    menu.builder[i].d_pitch_random_delay_min:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_pitch, "Random"}, menu.builder[i].d_pitch_random_delay_enable)
    menu.builder[i].d_pitch_random_delay_max:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_pitch, "Random"}, menu.builder[i].d_pitch_random_delay_enable)
    menu.builder[i].d_yaw:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive)
    menu.builder[i].d_tick_update:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_yaw, "Sideways"})
    menu.builder[i].d_offset:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, menu.aa_options.defensive, menu.builder[i].defensive, {menu.builder[i].d_yaw, "Off", true})
    menu.builder[i].lb_brute:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable)
    menu.builder[i].brute_mode:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable)
    menu.builder[i].delay_force:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, {menu.builder[i].brute_mode, "Disabled", true})
    menu.builder[i].duration_brute:depend(en, menutab, aa_options, {menu.mode, "Builder"}, {menu.state, lua.conds[i]}, menu.builder[i].enable, {menu.builder[i].brute_mode, "Disabled", true})
end

local indacfg = pui.setup({menu.builder, menu.aa_options, menu.misc, menu.visuals})

function load()
    local val = menu.cfg.list:get() + 1
    indacfg:load(base.cfg[val])
    print("[preset] profile loaded")
end

function save()
    local val = menu.cfg.list:get() + 1
    local nameindabox = menu.cfg.name:get()
    if nameindabox ~= "" then
        base.name[val] = nameindabox
    end
    base.cfg[val] = indacfg:save()
    database.write("ZOV6667771337.base", base)
    menu.cfg.list:update(base.name)
    print("[preset] profile saved")
end

function create()
    local nameindabox = menu.cfg.name:get()
    if(nameindabox == "") then
        name = "new config"
    else
        name = nameindabox
    end

    table.insert(base.name, name)
    table.insert(base.cfg, indacfg:save())
    database.write("ZOV6667771337.base", base)
    menu.cfg.list:update(base.name)
    print("[preset] profile created")
end

function delete()
    local val = menu.cfg.list:get() + 1
    if(val ~= 1 or #base.name > 1) then
        table.remove(base.name, val)
        table.remove(base.cfg, val)
    end

    database.write("ZOV6667771337.base", base)
    menu.cfg.list:update(base.name)
    print("[preset] profile deleted")
end

function import()
    local cfg = clipboard.get()
    indacfg:load(json.parse(base64.decode(cfg)))
    print("[preset] profile imported")
end

function export()
    clipboard.set(base64.encode(json.stringify(indacfg:save())))
    print("[preset] profile exported")
end

menu.builder[1].enable:set(true)

local player = {
    get_velocity = function(ent)
        return vector(entity.get_prop(ent, "m_vecVelocity")):length()
    end,

    get_vec_velocity = function(ent)
        return vector(entity.get_prop(ent, "m_vecVelocity"))
    end,

    in_air = function(_ent)
        local flags = entity.get_prop(_ent, "m_fFlags")

        if bit.band(flags, 1) == 0 then
            return true
        end
        
        return false
    end,

    in_duck = function(_ent)
        local flags = entity.get_prop(_ent, "m_fFlags")
        
        if bit.band(flags, 4) == 4 then
            return true
        end
        
        return false
    end,

    is_real = function(_ent)
        if(_ent ~= nil and entity.is_alive(_ent)) then
            return true
        else
            return false
        end
    end,

    dist_2d = function(_ent, other_player)
        if _ent ~= nil and other_player ~= nil then
            local x, y = entity.get_origin(_ent)
            local x2, y2 = entity.get_origin(other_player)
            if x ~= nil and y ~= nil and x2 ~= nil and y2 ~= nil then
                local dist = math.sqrt((x - x2)^2 + (y - y2)^2)
                return dist
            else
                return math.huge
            end
        else
            return math.huge
        end
    end,
}

local times_to_tick = function(val)
    return globals.tickinterval() * val
end

local lp_data = {
    jumping = false,
    ground = false,
    in_speed = false,
    weapon = 0,
    pos = vector(),
    left_desync_vec = vector(),
    right_desync_vec = vector(),
}

local target_data = {
    pos = vector(),
    speed = 0,
    weapon = 0,
    en_num = 0,
}

local ind = {
    alpha = 0,
    pulse = {
        alpha = 0,
        toggle = false,
    },
    dt_alpha = 0,
    dt_state = "",
    dt_charge_alpha = 0,
    dt_wait_alpha = 0,
    scoped = {
        name = 0,
        state = 0,
        state_name = "MENU",
        doubletap = 0,
        freestand = 0,
        hideshots = 0,
    },
    hide_state = "READY",
    zoomed = false,
    tickbase = 0,
    fr_alpha = 0,
    ideal_pick = 0,
    hide_alpha = 0,
    hide_charging_alpha = 0,
    hide_ready_alpha = 0,
}

function update_data(cmd, lp, target)
    lp_data.ground = bit.band(entity.get_prop(lp, "m_fFlags"), 1) == 1
    lp_data.jumping = cmd.in_jump == 1
    lp_data.in_speed = bit.band(cmd.buttons, 131072) > 0
    lp_data.weapon = entity.get_classname(entity.get_prop(lp, "m_hActiveWeapon"))
    lp_data.pos = vector(entity.get_prop(lp, "m_vecOrigin"))
    if target then
        target_data.pos = vector(entity.get_prop(target, "m_vecOrigin"))
        target_data.speed = vector(player.get_velocity(target))
        target_data.weapon = entity.get_classname(entity.get_prop(target, "m_hActiveWeapon"))
        target_data.en_num = target
    else
        target_data.en_num = nil
    end
end

function body_freestand(lp)
    if not player.is_real(lp) or not target_data.en_num then
        return
    end
    local l_velo = player.get_vec_velocity(lp)
    local e_velo = player.get_vec_velocity(target_data.en_num)
    local time_extra = times_to_tick(12)
    local l_pos = vector(lp_data.pos.x + l_velo.x * time_extra / 3, lp_data.pos.y + l_velo.y * time_extra / 3, lp_data.pos.z)
    local e_pos = vector(target_data.pos.x + e_velo.x * time_extra, target_data.pos.y + e_velo.y * time_extra, target_data.pos.z)
    local angle_to_enemy = calculate_angle(lp_data.pos, e_pos)
    lp_data.left_desync_vec = vector(l_pos.x + math.cos(math.rad(angle_to_enemy - 90)) * 35, l_pos.y + math.sin(math.rad(angle_to_enemy - 90)) * 35, l_pos.z + 45)
    lp_data.right_desync_vec = vector(l_pos.x + math.cos(math.rad(angle_to_enemy + 90)) * 35, l_pos.y + math.sin(math.rad(angle_to_enemy + 90)) * 35, l_pos.z + 45)
    local first_ent, damage_left = client.trace_bullet(target_data.en_num, e_pos.x, e_pos.y, e_pos.z, lp_data.left_desync_vec.x, lp_data.left_desync_vec.y, lp_data.left_desync_vec.z, true)
    local secon_ent, damage_right = client.trace_bullet(target_data.en_num, e_pos.x, e_pos.y, e_pos.z, lp_data.right_desync_vec.x, lp_data.right_desync_vec.y, lp_data.right_desync_vec.z, true)
    if damage_right > damage_left then
        return "right"
    elseif damage_right < damage_left then
        return "left"
    else
        return "none"
    end
end

player.get_state = function(cmd, ent)
    local states = {
        {
            index = 6,
            condition = "crouching",
            work = function()
                return (lp_data.jumping == false and lp_data.ground == true) and cmd.in_duck == 1 or ref.fakeduck:get()
            end,
        },
        {
            index = 5,
            name = "jump-crouching",
            work = function() 
                return (lp_data.jumping == true or lp_data.ground == false) and cmd.in_duck == 1
            end,
        },
        {
            index = 4,
            name = "jumping",
            work = function() 
                return (lp_data.jumping == true or lp_data.ground == false) and cmd.in_duck == 0
            end,
        },
        {
            index = 3,
            name = "slow-walking",
            work = function() 
                return lp_data.in_speed
            end,
        },
        {
            index = 2,
            name = "moving",
            work = function() 
                return vector(entity.get_prop(ent, 'm_vecVelocity')):length2d() > 3 and bit.band(entity.get_prop(ent, "m_fFlags"), 1) == 1
            end,
        },
        {
            index = 1,
            name = "standing",
            work = function() 
                return vector(entity.get_prop(ent, 'm_vecVelocity')):length2d() < 3 
            end,
        },
    }
    for i, condition in ipairs(states) do
        if condition.work() then
            return condition.index
        end
    end
    return 0
end

local avoid_backstab = function(lp, enemy)
    if not enemy or entity.is_dormant(enemy) then
        return
    end;
    local enemy_origin = { entity.get_origin(target_data.en_num) }
    local enemy_view = { entity.get_prop(target_data.en_num, "m_vecViewOffset") }
    local eye_pos = { client.eye_position() }
    local random_wraith_shit = { enemy_origin[1] + enemy_view[1], enemy_origin[2] + enemy_view[2], enemy_origin[3] + enemy_view[3] }
    local dist = { math.abs(random_wraith_shit[1] - eye_pos[1]), math.abs(random_wraith_shit[2] - eye_pos[2]), math.abs(random_wraith_shit[3] - eye_pos[3]) }
    local l2dist = math.abs(dist[1] + dist[2])
    if l2dist > 425 then
        return
    end;
    local lp_velo = { entity.get_prop(lp, 'm_vecVelocity') }
    local enemy_velo = { entity.get_prop(target_data.en_num, 'm_vecVelocity') }
    local extra_tick = times_to_tick(16)
    local extra_pos = { eye_pos[1] + lp_velo[1] * extra_tick, eye_pos[2] + lp_velo[2] * extra_tick, eye_pos[3] + lp_velo[3] * extra_tick }
    local extra_enemy_pos = { random_wraith_shit[1] + enemy_velo[1] * extra_tick, random_wraith_shit[2] + enemy_velo[2] * extra_tick, random_wraith_shit[3] + enemy_velo[3] * extra_tick }
    local L571, L572 = client.trace_line(lp, extra_pos[1], extra_pos[2], extra_pos[3], extra_enemy_pos[1], extra_enemy_pos[2], extra_enemy_pos[3])
    local L573, L574 = client.trace_line(lp, extra_enemy_pos[1], extra_enemy_pos[2], extra_enemy_pos[3], extra_pos[1], extra_pos[2], extra_pos[3])
    local L575, L576 = client.trace_line(lp, eye_pos[1], eye_pos[2], eye_pos[3], random_wraith_shit[1], random_wraith_shit[2], random_wraith_shit[3])
    local L577, L578 = client.trace_line(lp, eye_pos[1], eye_pos[2], eye_pos[3], enemy_origin[1], enemy_origin[2], enemy_origin[3])
    local L579 = L572 == enemy or L571 == 1;
    local L580 = L574 == lp or L573 == 1;
    local L581 = L576 == enemy or L575 == 1;
    local L582 = L578 == enemy or L577 == 1;
    local enemies_weapon = target_data.weapon
    if enemies_weapon == "CKnife" and (L579 or L580 or L581 or L582) then
        return true
    end
    return false
end

ram = {
    yaw = 0,
    manual_base = 0,
    aa_tickrate = 0,
    jitter = false,
    yaw_add = 0,
    inverted = false,
    random_add = 0,
    last_sim_time = 0,
    tick_def_off = 0,
    spin = 0,
    xway_current = 1,

    defensive_work = false,
    pitch_min = -45,
    pitch_max = 45,
    anti_aim = {
        pitch = 0,
        pitchmode = "Custom",
        yaw = 0,
        manual = 0,
        jitter = 0,
        add = 0,
        fake = 0,
        freestand = false,
        cheat_yaw = "Off",
        cheat_jitter = 0,
        cheat_body = "Off",
        random_add = 0,
        at_target = false,
        jitter_update = false,
        freestand_active = false,


        fl_limit = 14,
        jit_tick_left = 0,
        jit_tick_right = 0,
        fsbodyyaw = false,
        side = false,
    },
    def_jitter = false,
    manual_active = 0,
    tickbase = 0,
    defensive = {
        pitch_update = false,
        pitch_phase = 0,
        local_side = "left",
    },
}


local desync = 0
local max = 0
local modifier = 0

function is_freestand(lp)
    local enemy_player = client.current_threat()
    if not lp or not enemy_player then return false end
    local e_pos = vector(entity.get_prop(enemy_player, "m_vecOrigin"))
    if not lp_data.pos or not e_pos then return false end
    local angle_to_enemy = calculate_angle(lp_data.pos, e_pos)
    local local_yaw = entity.get_prop(lp, "m_flLowerBodyYawTarget")
    local angle = math.floor(normalize_yaw(local_yaw - angle_to_enemy))
    if angle <= -89 and angle >= -91 or angle >= 89 and angle <= 91 then
        return true
    else
        return false
    end
end

local function yaw_manager(side, left, right)
    return side and left or (side and 0 or right)
end

local function normalize_pitch(val)
    if(val > 89) then
        val = val - 89 * 2
    elseif(val < -89) then
        val = val + 89 * 2
    end
    return val
end

local function get_freestand_direction (player)
    local data = {
        side = 1,
        last_side = 0,
        last_hit = 0,
        hit_side = 0
    }

    if not player or entity.get_prop(player, 'm_lifeState') ~= 0 then
        return
    end

    if data.hit_side ~= 0 and globals.curtime() - data.last_hit > 5 then
        data.last_side = 0
        data.last_hit = 0
        data.hit_side = 0
    end

    local eye = vector(client.eye_position())
    local ang = vector(client.camera_angles())
    local trace_data = {left = 0, right = 0}

    for i = ang.y - 120, ang.y + 120, 30 do
        if i ~= ang.y then
            local rad = math.rad(i)
            local px, py, pz = eye.x + 256 * math.cos(rad), eye.y + 256 * math.sin(rad), eye.z
            local fraction = client.trace_line(player, eye.x, eye.y, eye.z, px, py, pz)
            local side = i < ang.y and 'left' or 'right'
            trace_data[side] = trace_data[side] + fraction
        end
    end

    data.side = trace_data.left < trace_data.right and -1 or 1

    if data.side == data.last_side then
        return
    end

    data.last_side = data.side

    if data.hit_side ~= 0 then
        data.side = data.hit_side
    end

    return data.side
end

--[[
local function player_will_peek( )
	local enemies = entity.get_players( true )
	if not enemies then
		return false
	end
	
	local eye_position = vec_3( client.eye_position( ) )
	local velocity_prop_local = vec_3( entity.get_prop( entity.get_local_player( ), "m_vecVelocity" ) )
	local predicted_eye_position = vec_3( eye_position.x + velocity_prop_local.x * ticks_to_time2( predicted ), eye_position.y + velocity_prop_local.y * ticks_to_time2( predicted ), eye_position.z + velocity_prop_local.z * ticks_to_time2( predicted ) )

	for i = 1, #enemies do
		local player = enemies[ i ]
		
		local velocity_prop = vec_3( entity.get_prop( player, "m_vecVelocity" ) )
		
		local origin = vec_3( entity.get_prop( player, "m_vecOrigin" ) )
		local predicted_origin = vec_3( origin.x + velocity_prop.x * ticks_to_time2(), origin.y + velocity_prop.y * ticks_to_time2(), origin.z + velocity_prop.z * ticks_to_time2() )
		
		entity.get_prop( player, "m_vecOrigin", predicted_origin )
		
		local head_origin = vec_3( entity.hitbox_position( player, 0 ) )
		local predicted_head_origin = vec_3( head_origin.x + velocity_prop.x * ticks_to_time2(), head_origin.y + velocity_prop.y * ticks_to_time2(), head_origin.z + velocity_prop.z * ticks_to_time2() )
		local trace_entity, damage = client.trace_bullet( entity.get_local_player( ), predicted_eye_position.x, predicted_eye_position.y, predicted_eye_position.z, predicted_head_origin.x, predicted_head_origin.y, predicted_head_origin.z )
		
		entity.get_prop( player, "m_vecOrigin", origin )
		
		if damage > 0 then
			return true
		end
	end
	
	return false
end
]]

-- НАЧАЛО УЛУЧШЕННОГО ПРЕДИКТА ЧЕРЕЗ ЭКСТРАПОЛЯЦИЮ С УЧЕТОМ СТЕЙТОВ (FL_ONGROUND, GRAVITY)
local function extrapolate_position(ent, start_pos, velocity, ticks)
	local flags = entity.get_prop(ent, "m_fFlags") or 0
	local tick_interval = globals.tickinterval()
	
	local predicted_pos = vec_3(start_pos.x, start_pos.y, start_pos.z)
	local current_velocity = vec_3(velocity.x, velocity.y, velocity.z)
	
	local on_ground = bit.band(flags, 1) ~= 0
	local gravity = 800
	local sv_gravity = cvar.sv_gravity
	if sv_gravity then
		gravity = sv_gravity:get_float()
	end
	
	for t = 1, ticks do
		if not on_ground then
			current_velocity.z = current_velocity.z - (gravity * tick_interval)
		else
			current_velocity.z = 0
		end
		
		predicted_pos.x = predicted_pos.x + current_velocity.x * tick_interval
		predicted_pos.y = predicted_pos.y + current_velocity.y * tick_interval
		predicted_pos.z = predicted_pos.z + current_velocity.z * tick_interval
	end
	
	return predicted_pos
end

local function player_will_peek()
	local local_player = entity.get_local_player()
	if not local_player or not entity.is_alive(local_player) then
		return false
	end

	local enemies = entity.get_players(true)
	if not enemies or #enemies == 0 then
		return false
	end
	
	local eye_position = vec_3(client.eye_position())
	local velocity_prop_local = vec_3(entity.get_prop(local_player, "m_vecVelocity"))
	
	-- Экстраполируем положение глаз локального игрока на 16 тиков вперед с учетом гравитации
	local predicted_eye_position = extrapolate_position(local_player, eye_position, velocity_prop_local, 16)

	for i = 1, #enemies do
		local player = enemies[i]
		
		local velocity_prop = vec_3(entity.get_prop(player, "m_vecVelocity"))
		local head_origin = vec_3(entity.hitbox_position(player, 0))
		
		-- Экстраполируем положение головы врага на 16 тиков вперед с учетом его стейта и гравитации
		local predicted_head_origin = extrapolate_position(player, head_origin, velocity_prop, 16)
		
		local trace_entity, damage = client.trace_bullet(
			local_player, 
			predicted_eye_position.x, predicted_eye_position.y, predicted_eye_position.z, 
			predicted_head_origin.x, predicted_head_origin.y, predicted_head_origin.z
		)
		
		if damage and damage > 0 then
			return true
		end
	end
	
	return false
end
-- КОНЕЦ УЛУЧШЕННОГО ПРЕДИКТА ЧЕРЕЗ ЭКСТРАПОЛЯЦИЮ

function builder(cmd, state, tab, avoid_backstabing, lp, safehead, side)
    local state_id = tab == menu.builder[state + 1] and (state + 1) or 1
    local b_yaw, b_delay = antibrute.handle_brute(state_id)
    local tickrate = globals.tickcount() - entity.get_prop(lp, "m_flSimulationTime") * 64
    local doubletap_ref = ref.dt:get() and ref.dt:get_hotkey()
    local charge_check = entity.get_prop(lp, "m_nTickBase") - globals.tickcount()
    if menu.enable:get() then
        local active_manual = ram.is_legit_active and "None" or menu.aa_options.manual_base:get()
        local overlap = adata.get_overlap(true)
        local fl = entity.get_prop(lp, "m_nTickBase") - globals.tickcount()
        local is_freestanding = is_freestand(lp) and menu.aa_options.freestand_cond:get(lua.conds_no_g[state]) and menu.aa_options.freestand:get() and active_manual == "None"
        ram.tickbase = fl < 0
        ram.spin = ram.spin + 20
        if ram.spin % 360 == 0 then
            ram.spin = 0
        end
        if menu.misc.fast_ladder:get() then
            fast_ladder(cmd, lp)
        end
        if not ram.is_legit_active and (menu.aa_options.left:get() or menu.aa_options.right:get() or menu.aa_options.backward:get() or menu.aa_options.forward:get()) then
            ram.manual_active = 1
        end
        if not ram.is_legit_active and ram.manual_active ~= 0 then
            manualing()
            ram.manual_active = ram.manual_active + 1
        end
        if ram.manual_active == 3 then
            ram.manual_active = 0
        end

        if tab.force_defensive:get() then
            cmd.force_defensive = true
        elseif not tab.force_defensive:get() then
            if ref.dt:get_hotkey() then

                if player_will_peek() then
                    cmd.force_defensive = true
                else
                    cmd.force_defensive = false
                end
            end
        end

        if is_defensive_active(lp) and menu.aa_options.defensive:get() and tab.defensive:get() then
            ram.defensive_work = true
        else
            ram.defensive_work = false
        end
        if globals.chokedcommands() == 0 then
            ram.aa_tickrate = ram.aa_tickrate + 1
            if --[[tab.yaw:get() == "Slow" and]] not ram.defensive_work then
                if tab.double_tick_update:get() then
                    if ram.jitter then 
                        if ram.anti_aim.jit_tick_right ~= 0 then
                            ram.anti_aim.jit_tick_right = 0
                        end
                        ram.anti_aim.jit_tick_left = ram.anti_aim.jit_tick_left + 1
                        if ram.anti_aim.jit_tick_left >= (tab.tick_update:get() + 1 + b_delay) then
                            ram.jitter = not ram.jitter
                        end
                    else
                        if ram.anti_aim.jit_tick_left ~= 0 then
                            ram.anti_aim.jit_tick_left = 0
                        end
                        ram.anti_aim.jit_tick_right = ram.anti_aim.jit_tick_right + 1
                        if ram.anti_aim.jit_tick_right >= (tab.tick_update_second:get() + 1 + b_delay) then
                            ram.jitter = not ram.jitter
                        end
                    end
                else
                    if ram.anti_aim.jit_tick_left ~= 0 then
                        ram.anti_aim.jit_tick_left = 0
                        ram.anti_aim.jit_tick_right = 0
                    end
                    if ram.aa_tickrate % (tab.tick_update:get() + 1 + b_delay) == 0 then
                        ram.jitter = not ram.jitter
                    end
                end
            else
                ram.jitter = not ram.jitter
            end
            if tab.yaw:get() == "Advanced skitter" then
                ram.xway_current = (ram.xway_current or 1) + 1
                local ways_limit = tab.xway_ways and tab.xway_ways:get() or 3
                if ram.xway_current > ways_limit then
                    ram.xway_current = 1
                end
            end
        end
        if ram.jitter ~= ram.anti_aim.jitter_update then
            ram.anti_aim.random_add = client.random_int(tab.yaw_randomize:get() * -0.5, tab.yaw_randomize:get() * 0.5)
            ram.anti_aim.jitter_update = ram.jitter
        end
        if not ram.defensive_work then
            if active_manual == "None" then
                ram.anti_aim.manual = 0
                ram.anti_aim.at_target = menu.aa_options.yaw_base:get()
            else
                ram.anti_aim.at_target = false
                if active_manual == "Backward" then
                    ram.anti_aim.manual = 0
                elseif active_manual == "Left" then
                    ram.anti_aim.manual = -90
                elseif active_manual == "Right" then
                    ram.anti_aim.manual = 90
                elseif active_manual == "Forward" then
                    ram.anti_aim.manual = 180
                end
            end
            
            if tab.pitch:get() == "Off" then
                ram.anti_aim.pitchmode = "Custom"
                ram.anti_aim.pitch = 0
            elseif tab.pitch:get() == "Down" then
                ram.anti_aim.pitchmode = "Custom"
                ram.anti_aim.pitch = 89
            elseif tab.pitch:get() == "Up" then
                ram.anti_aim.pitchmode = "Custom"
                ram.anti_aim.pitch = -89
            end
            if tab.yaw:get() == "Center" and tab.yaw_add:get() == "Off" and tab.body_yaw:get() ~= "Smart" then
                ram.anti_aim.cheat_yaw = "Center"
                ram.anti_aim.add = 0
                ram.anti_aim.yaw = tab.yaw_default:get()
                ram.anti_aim.jitter = tab.yaw_center:get() + ram.anti_aim.random_add
                if tab.body_yaw:get() == "Jitter" then
                    ram.anti_aim.cheat_body = "Jitter"
                    ram.anti_aim.fake = tab.body_yaw_degree:get()
                elseif tab.body_yaw:get() == "Static" then
                    ram.anti_aim.cheat_body = "Static"
                    ram.anti_aim.fake = tab.body_yaw_degree:get()
                elseif tab.body_yaw:get() == "Opposite" then
                    ram.anti_aim.cheat_body = "Opposite"
                    ram.anti_aim.fake = 0
                else
                    ram.anti_aim.cheat_body = "Off"
                    ram.anti_aim.fake = 0
                end
            elseif tab.yaw:get() ~= "Off" then
                ram.anti_aim.cheat_yaw = "Off"
                if tab.yaw_add:get() ~= "Off" then
                    ram.anti_aim.add = (not ram.jitter) and tab.yaw_left:get() or tab.yaw_right:get()
                else
                    ram.anti_aim.add = 0
                end
                if tab.yaw:get() == "Advanced skitter" then
                    -- ram.anti_aim.yaw = tab.yaw_default:get() + client.random_int(math.min(tab.yaw_center:get() - (tab.yaw_center:get() * 2)), tab.yaw_center:get()) + ram.anti_aim.random_add
                    local ways_count = tab.xway_ways:get()
                    local spread = tab.xway_jitter:get()
                    local xway_val = 0
                    if ways_count > 1 then
                        local way_index = ram.xway_current or 1
                        if way_index > ways_count then
                            way_index = 1
                        end
                        local total_range = spread * 2
                        local step_size = total_range / (ways_count - 1)
                        xway_val = -spread + (step_size * (way_index - 1))
                    end
                    local xway_sign = (not ram.jitter) and 1 or -1
                    ram.anti_aim.yaw = tab.yaw_default:get() + (xway_val * xway_sign) + ram.anti_aim.random_add
                else
                    ram.anti_aim.yaw = tab.yaw_default:get() + (ram.jitter and tab.yaw_center:get() / 2 or tab.yaw_center:get() / -2) + ram.anti_aim.random_add
                end
                ram.anti_aim.jitter = 0
                if tab.body_yaw:get() == "Jitter" then
                    ram.anti_aim.cheat_body = "Static"
                    ram.anti_aim.fake = ram.jitter and tab.body_yaw_degree:get() or tab.body_yaw_degree:get() * -1
                elseif tab.body_yaw:get() == "Smart" then
                    max = overlap * (fl < 2 and 30 or 60)
                    modifier = normalize_yaw(ram.anti_aim.add + ram.anti_aim.yaw)
                    desync = modifier * gratio - (max * (ram.jitter and 1 or -1))
                    ram.anti_aim.cheat_body = "Static"
                    if ram.jitter then 
                        desync = math.abs(desync)
                    else
                        desync = math.abs(desync) * -1
                    end
                    ram.anti_aim.fake = math.floor(math.clamp(desync, -180, 180))
                elseif tab.body_yaw:get() == "Jitter v2" then
                    ram.anti_aim.cheat_body = "Static"
                    ram.anti_aim.fake = ram.jitter and tab.body_yaw_degree2:get() or tab.body_yaw_degree1:get()
                elseif tab.body_yaw:get() == "Opposite" then
                    ram.anti_aim.cheat_body = "Opposite"
                    ram.anti_aim.fake = 0
                else
                    ram.anti_aim.cheat_body = "Static"
                    ram.anti_aim.fake = 0
                end
            else
                ram.anti_aim.cheat_yaw = "Off"
                ram.anti_aim.add = 0
                ram.anti_aim.yaw = tab.yaw_default:get()
                ram.anti_aim.jitter = 0
                ram.anti_aim.cheat_body = "Static"
                ram.anti_aim.fake = 0
            end
            ram.pitch_min = -89
            ram.anti_aim.fsbodyyaw = false
            ram.anti_aim.side = nil
            if ram.defensive.pitch_update == true then
                ram.defensive.pitch_phase = ram.defensive.pitch_phase + 1
                ram.defensive.pitch_update = false
            end
            if menu.aa_options.static_on_def:get() and menu.aa_options.defensive:get() and tab.defensive:get() and active_manual == "None" then
                ram.anti_aim.cheat_yaw = "Off"
                ram.anti_aim.add = 0
                ram.anti_aim.jitter = 0
                ram.anti_aim.cheat_body = "Static"
                ram.anti_aim.manual = 0
                ram.anti_aim.at_target = true
                ram.anti_aim.fsbodyyaw = false
            end
        else
            if active_manual == "None" and menu.aa_options.static_on_def:get() then
                ram.anti_aim.cheat_yaw = "Off"
                ram.anti_aim.add = 0
                ram.anti_aim.jitter = 0
                ram.anti_aim.cheat_body = "Static"
                ram.anti_aim.manual = 0
                ram.anti_aim.at_target = true
                ram.anti_aim.fsbodyyaw = false
            end
                if tab.force_defensive:get() then
                    if menu.aa_options.secret_exploit:get() then
                        cmd.force_defensive = cmd.command_number % 7 == 0
                    elseif not menu.aa_options.secret_exploit:get() then
                        cmd.force_defensive = cmd.command_number % 16 == 0
                    end
                else
                    if ref.dt:get_hotkey() then
                        return
                    end

                    if player_will_peek() then
                        cmd.force_defensive = true
                    else
                        cmd.force_defensive = false
                    end
                end
            if tab.d_pitch:get() ~= "Lerp" then
                ram.pitch_min = -89
            end
            if globals.chokedcommands() == 0 then
                if tab.d_pitch:get() == "Lerp" then
                    ram.pitch_min = math.lerp(ram.pitch_min, ram.pitch_max, globals.curtime() * 6 % 2 - 1)
                    ram.anti_aim.pitchmode = "Custom"
                    ram.anti_aim.pitch = math.clamp(ram.pitch_min, -89, 89)
                elseif tab.d_pitch:get() == "Static" then
                    ram.anti_aim.pitchmode = "Custom"
                    ram.anti_aim.pitch = tab.d_pitch_degree:get()
                elseif tab.d_pitch:get() == "Jitter" then
                    ram.anti_aim.pitchmode = "Custom"
                    ram.anti_aim.pitch = ram.aa_tickrate % 2 == 0 and -80 or -60
                elseif tab.d_pitch:get() == "Random" then
                    ram.defensive.pitch_update = true
                    local tickcount = (globals.tickcount() / 2)
                    local random_min = tab.d_pitch_random_min:get()
                    local random_max = tab.d_pitch_random_max:get()
                    local s1 = tab.d_pitch_random_delay_min:get()
                    local s2 = tab.d_pitch_random_delay_max:get()
                    local delay
                    
                    if tab.d_pitch_random_delay_enable:get() == true then
                        delay = math.random(s1, s2)
                    else
                        delay = tab.d_pitch_random_delay:get()
                    end
                    ram.anti_aim.pitchmode = "Custom"
                    
                    if delay and type(delay) == "number" and delay >= 0 then
                        if math.ceil(tickcount / (delay + 1)) ~= math.ceil((tickcount - 1) / (delay + 1)) then
                            ram.anti_aim.pitch = client.random_int(random_min, random_max)
                        end
                    end
                elseif tab.d_pitch:get() == "Sway" then
                    ram.defensive.pitch_update = true
                    local sway_time = 12
                    local tickcount = (globals.tickcount() / 2)
                    local range = tab.d_pitch_range:get()
                    local speed = tab.d_pitch_speed:get()
                    local s1 = tab.d_pitch_skip_min:get()
                    local s2 = tab.d_pitch_skip_max:get()
                    local delay
                    
                    if tab.d_pitch_random_skip:get() then
                        delay = math.random(s1, s2)
                    else
                        delay = tab.d_pitch_skip:get()
                    end
                    ram.anti_aim.pitchmode = "Custom"
                    ram.anti_aim.pitch = (math.abs((math.ceil(tickcount / (delay + 1)) * speed % ((range + 1))) - range / 2) - range / 4) * 2 + tab.d_pitch_degree:get()

                    if ram.anti_aim.pitch >= 89 then
                        ram.anti_aim.pitchmode = "Custom"
                        ram.anti_aim.pitch = 89
                    elseif ram.anti_aim.pitch <= -89 then
                        ram.anti_aim.pitchmode = "Custom"
                        ram.anti_aim.pitch = -89
                    end
                end
                if tab.d_yaw:get() == "Forward" then
                    ram.anti_aim.yaw = 180 + tab.d_offset:get()
                    ram.anti_aim.fake = 180
                elseif tab.d_yaw:get() == "Off" then

                elseif tab.d_yaw:get() == "Freestand" then
                    local freestand_dir = get_freestand_direction(entity.get_local_player())
                    if freestand_dir == -1 then
                        ram.anti_aim.yaw = -tab.d_offset:get()
                    else
                        ram.anti_aim.yaw = tab.d_offset:get()
                    end
                    ram.anti_aim.fake = 180
                elseif tab.d_yaw:get() == "Spin" then
                    ram.anti_aim.yaw = globals.tickcount() % 18 * 20 + tab.d_offset:get()
                    ram.anti_aim.fake = 180
                elseif tab.d_yaw:get() == "180 z" then
                    ram.anti_aim.fake = 180
                    if globals.tickcount() % 18 <= 9 then
                        ram.anti_aim.yaw = globals.tickcount() % 9 * 20 + tab.d_offset:get() - 90
                    else
                        ram.anti_aim.yaw = math.abs(9 - globals.tickcount() % 9) * 20 + tab.d_offset:get() - 90
                    end
                elseif tab.d_yaw:get() == "Slow spin" then
                    ram.anti_aim.yaw = globals.tickcount() % 60 * 6 + tab.d_offset:get()
                    ram.anti_aim.fake = 180
                elseif tab.d_yaw:get() == "Sideways" then
                    if ram.aa_tickrate % (tab.d_tick_update:get() + 1) == 0 then
                        ram.def_jitter = not ram.def_jitter
                    end
                    ram.anti_aim.yaw = (ram.def_jitter and 90 or -90) + tab.d_offset:get()
                    ram.anti_aim.fake = ram.def_jitter and 180 or -180
                elseif tab.d_yaw:get() == "Random" then    
                    ram.anti_aim.yaw = math.random(-180, 180)
                    ram.anti_aim.fake = 180
                elseif tab.d_yaw:get() == "Sin" then
                    ram.anti_aim.yaw = math.sin(globals.servertickcount() / 10 * 4) * 90 + tab.d_offset:get()
                    ram.anti_aim.fake = 180
                elseif tab.d_yaw:get() == "Flick" then
                    if side ~= "none" then
                        ram.defensive.local_side = side
                    end
                    if ram.defensive.local_side  == "right" then
                        ram.anti_aim.fake = 180
                        ram.anti_aim.yaw = 90 + tab.d_offset:get()
                    elseif ram.defensive.local_side  == "left" then
                        ram.anti_aim.fake = -180
                        ram.anti_aim.yaw = -90 + tab.d_offset:get()
                    else
                        ram.anti_aim.yaw = (cmd.sidemove > 0 and 90 or -90) + tab.d_offset:get()
                        ram.anti_aim.fake = cmd.sidemove > 0 and 180 or -180
                    end
                    if tab.force_defensive:get() then
                        if not tab.d_yaw:get() == "Flick" then 
                            cmd.force_defensive = cmd.command_number % 16 == 0
                            return 
                        else
                            cmd.force_defensive = cmd.command_number % 7 == 0
                        end
                    else
                        if ref.dt:get_hotkey() then
                            return
                        end

                        if player_will_peek() then
                            cmd.force_defensive = true
                        else
                            cmd.force_defensive = false
                        end
                    end

                end
            end
        end
        if menu.aa_options.freestand_cond:get(lua.conds_no_g[state]) and menu.aa_options.freestand:get() and active_manual == "None" then
            ram.anti_aim.freestand = true
        else
            ram.anti_aim.freestand = false
        end
        if state == 7 then
            ram.anti_aim.freestand = false
            ram.anti_aim.yaw = ram.anti_aim.yaw * -1 + 180
            ram.anti_aim.at_target = false
        end
        if safehead then
            ram.anti_aim.pitchmode = "Custom"
            ram.anti_aim.pitch = 89
            ram.anti_aim.cheat_yaw = "Off"
            ram.anti_aim.add = 0
            ram.anti_aim.yaw = 0
            ram.anti_aim.jitter = 0
            ram.anti_aim.cheat_body = "Static"
            ram.anti_aim.fake = 0
            ram.anti_aim.manual = 0
            ram.anti_aim.at_target = true
        end
        if avoid_backstabing then
            ram.anti_aim.pitchmode = "Custom"
            ram.anti_aim.pitch = 89
            ram.anti_aim.cheat_yaw = "Off"
            ram.anti_aim.add = 0
            ram.anti_aim.yaw = 180
            ram.anti_aim.jitter = 0
            ram.anti_aim.cheat_body = "Static"
            ram.anti_aim.fake = 180
            ram.anti_aim.manual = 0
            ram.anti_aim.at_target = true
        end
        if ref.hs:get_hotkey() and not (ref.fakeduck:get() or ref.dt:get_hotkey()) then
            ram.anti_aim.fl_limit = 1
        else
            ram.anti_aim.fl_limit = menu.fake_lag_limit:get()
        end
        if menu.aa_options.funny_warmup:get() then
            if (entity.get_prop(entity.get_game_rules(), "m_bWarmupPeriod") == 1) then
                ram.anti_aim.cheat_yaw = "Off"
                ram.anti_aim.add = 0
                ram.anti_aim.yaw = globals.tickcount() % 18 * 20 - 180
                ram.anti_aim.jitter = 0
                ram.anti_aim.cheat_body = "Static"
                ram.anti_aim.fake = 0
                ram.anti_aim.manual = 0
                ram.anti_aim.at_target = false
                ram.anti_aim.pitchmode = "Custom"
                ram.anti_aim.pitch = 0
            end
        end
        if not safehead and not avoid_backstabing and not (menu.aa_options.funny_warmup:get() and entity.get_prop(entity.get_game_rules(), "m_bWarmupPeriod") == 1) then
            ram.anti_aim.yaw = ram.anti_aim.yaw + b_yaw
        end
    else
        ref.enabled:set(true)
        ref.yawbase:set("At targets")
        ref.yaw[1]:set("180")
        ref.yaw[2]:set(180)
        ref.pitch[1]:set("Default")
        ref.bodyyaw[1]:set("Static")
        ref.bodyyaw[2]:set(0)
        ref.pitch[1]:set("Off")
        ref.yawjitter[1]:set("Off")
        ref.fsbodyyaw:set(false)
        ref.edgeyaw:set(false)
        ref.freestand[1]:set(false)
    end
    if(globals.chokedcommands() == 0 and lp ~= nil and entity.is_alive(lp)) then
        tickbase = entity.get_prop(lp, "m_nTickBase") - globals.tickcount()
    end
end

local was_disabled = true
local shot_tick = 0
local ticking = 0

function aa_setting(cmd)
    if not menu.enable:get() then return end
    local yaw = math.floor(normalize_yaw(ram.anti_aim.add + ram.anti_aim.yaw + ram.anti_aim.manual))
    if ref.fl_enable:get() ~= true then
        ref.fl_enable:set(true)
        ref.fl_enable:set_hotkey("Always on")
    end
    if ref.fl_amount:get() ~= menu.fake_lag_amount:get() then
        ref.fl_amount:set(menu.fake_lag_amount:get())
    end
    if ref.fl_var:get() ~= menu.fake_lag_variance:get() then
        ref.fl_var:set(menu.fake_lag_variance:get())
    end
    if ref.fsbodyyaw:get() ~= ram.anti_aim.fsbodyyaw then
        ref.fsbodyyaw:set(ram.anti_aim.fsbodyyaw)
    end
    if ref.yaw[1]:get() ~= "180" then
        ref.yaw[1]:set("180")
    end
    if ref.yaw[2]:get() ~= math.floor(yaw) then
        ref.yaw[2]:set(math.floor(yaw))
    end
    if ref.pitch[1]:get() ~= "Custom" then
        ref.pitch[1]:set("Custom")
    end
    if ref.pitch[2]:get() ~= math.floor(ram.anti_aim.pitch) then
        ref.pitch[2]:set(math.floor(ram.anti_aim.pitch))
    end
    if ref.bodyyaw[1]:get() ~= ram.anti_aim.cheat_body then
        ref.bodyyaw[1]:set(ram.anti_aim.cheat_body)
    end
    if ref.fl_limit:get() ~= ram.anti_aim.fl_limit then
        ref.fl_limit:set(ram.anti_aim.fl_limit)
    end
    local fake = math.clamp(ram.anti_aim.fake, -180, 180)
    if ref.bodyyaw[2]:get() ~= fake then
        ref.bodyyaw[2]:set(fake)
    end
    if ref.yawjitter[1]:get() ~= ram.anti_aim.cheat_yaw then
        ref.yawjitter[1]:set(ram.anti_aim.cheat_yaw)
    end
    if ref.yawjitter[2]:get() ~= math.floor(ram.anti_aim.jitter) then
        ref.yawjitter[2]:set(normalize_yaw(math.floor(ram.anti_aim.jitter)))
    end
    
    if (ref.yawbase:get() == "At targets") ~= ram.anti_aim.at_target then
        if ram.anti_aim.at_target then
            ref.yawbase:set("At targets")
        else
            ref.yawbase:set("Local view")
        end
    end
    if ram.anti_aim.freestand_active ~= ram.anti_aim.freestand then
        if ram.anti_aim.freestand then
            ref.freestand[1]:set(true)
            ref.freestand[1]:set_hotkey("Always On")
        else
            ref.freestand[1]:set(false)
            ref.freestand[1]:set_hotkey("On hotkey")
        end
        ram.anti_aim.freestand_active = ram.anti_aim.freestand
    end
    local doubletap_ref = ref.dt:get() and ref.dt:get_hotkey() and not ref.fake_duck:get()
    if doubletap_ref then
        if globals.chokedcommands() == 0 then
            if ref.quickpeek:get_hotkey() and ref.quickpeek:get() and ram.tickbase then 
                ind.dt_state = "IDEAL PICK"
            elseif ram.tickbase and not ref.fakeduck:get() then
                ind.dt_state = "READY"
            elseif globals.tickcount() % 16 > 4 or ref.fakeduck:get() then
                ind.dt_state = "WAIT"
            end
        end
    else
        ind.dt_state = "WAIT"
    end
    if ram.tickbase or not ref.hs:get_hotkey() then
        ind.hide_state = "READY"
    else
        ind.hide_state = "CHARGING"
    end
    

    
end

function charging(lp)
    --     if menu.misc.dt_recharge:get() then
    --         if(globals.chokedcommands() == 0 and lp ~= nil and entity.is_alive(lp)) then
    --             tickbase = entity.get_prop(lp, "m_nTickBase") - globals.tickcount()
    --         end
    --         local doubletap_ref = ref.dt:get() and ref.dt:get_hotkey() and not ref.fake_duck:get()
    --         if not doubletap_ref then
    --             was_disabled = true
    --         end
    --         if tickbase == nil then return end
    --         if (doubletap_ref or ref.hs:get_hotkey()) and tickbase > 0 and was_disabled then
    --             ref.aimbot:override(false)
    --             was_disabled = false
    --             ticking = 0
    --         else
    --             local lp_weapon = entity.get_player_weapon(lp)
    --             if lp_weapon ~= nil then
    --                 local weapon_id = bit.band(entity.get_prop(entity.get_player_weapon(lp), "m_iItemDefinitionIndex"), 0xFFFF)
    --                 if weapon_id == 64 then
    --                     ref.aimbot:override(true)
    --                     if ticking <= 2 then
    --                         ticking = ticking + 1
    --                     end
    --                     if ticking <= 1 then
    --                         ref.aimbot:override(false)
    --                     else
    --                         ref.aimbot:override(true)
    --                     end
    --                 else
    --                     ref.aimbot:override(true)
    --                 end
    --             end
    --         end
    --     end
end

local rechargenl = {} do
    local enable = menu.misc.nl_recharge
    local buffer = ffi.new('char[?]', 0x1D)
    local ogbytes = ffi.new('char[?]', 0x1D)
    local ptr = ffi.cast('char*', 0x433AC04B)
    ffi.copy(ogbytes, ptr, 0x1D)
    ffi.copy(buffer, ogbytes, 0x1D)
    ffi.fill(buffer, 0x18, 0x90)
    buffer[0x18] = 0xE9
    enable:set_callback(function (this)
        if this:get() then
            ffi.copy(ptr, buffer, 0x1D)
        else
            ffi.copy(ptr, ogbytes, 0x1D)
        end
    end, true)
end

--[=[
local main_massive_logs = {}
local for_rendering = {}

function aim_hit(e)
    if(menu.visuals.logs:get()) and main_massive_logs[e.id] ~= nil then
        local sht_info = main_massive_logs[e.id]
        local ar, ag, ab = menu.visuals.logs_color1:get()
        local r, g, b = menu.visuals.logs_color2:get()
        local hitgroup = sht_info.hitbox
        local tname = entity.get_player_name(sht_info.target)
        local dmg = sht_info.damage
        local bt = sht_info.backtrack
        local ht = math.floor(sht_info.hitchance)
        local test_frst = "Hit \0"
        local realdmg = e.dmg_health
        client.color_log(ar, ag, ab, "Damage given to \0")
        client.color_log(r, g, b, tname .. "\0")
        client.color_log(ar, ag, ab, "'s \0")
        client.color_log(r, g, b, hitgroup .. " \0")
        client.color_log(ar, ag, ab, "~ \0")
        client.color_log(r, g, b, realdmg .. " (" .. dmg .. ") \0")
        client.color_log(ar, ag, ab, "[HT: \0")
        client.color_log(r, g, b, ht .. "% \0")
        client.color_log(ar, ag, ab, "~ | ~ BT:\0 ")
        client.color_log(r, g, b, bt .. "\0")
        client.color_log(ar, ag, ab, " ~ | ~ RHP:\0 ")
        client.color_log(r, g, b, entity.get_prop(sht_info.target, "m_iHealth") .. "\0")
        client.color_log(ar, ag, ab, "]")
        if menu.visuals.screen_logs:get() then
            table.insert(for_rendering, 1, {text = "[project john] damage given to " .. tname .. " for " .. realdmg .. " (" .. dmg .. ")", alpha = 0, add_y = 0, tick = globals.curtime() * 64, randomize = math.random(0, 100)})
        end
        main_massive_logs = {}
    end
end

function aim_miss(e)
    if(menu.visuals.logs:get()) and main_massive_logs[e.id] ~= nil then
        local ar, ag, ab = menu.visuals.logs_color1:get()
        local r, g, b = menu.visuals.logs_color3:get()
        local sht_info = main_massive_logs[e.id]
        local reason = e.reason
        local tname = entity.get_player_name(sht_info.target)
        local hitbox = sht_info.hitbox
        local bt = sht_info.backtrack
        local dmg = sht_info.damage
        local ht = math.floor(sht_info.hitchance)
        client.color_log(ar, ag, ab, "Missed in \0")
        client.color_log(r, g, b, tname .. "'s \0")
        client.color_log(r, g, b, hitbox .. "\0")
        client.color_log(ar, ag, ab, " due to \0")
        client.color_log(r, g, b, reason .. " \0")
        client.color_log(ar, ag, ab, "[HT: \0")
        client.color_log(r, g, b, ht .. "% \0")
        client.color_log(ar, ag, ab, "~ | ~ DMG: \0")
        client.color_log(r, g, b, dmg .. " \0")
        client.color_log(ar, ag, ab, "~ | ~ BT: \0")
        client.color_log(r, g, b, bt .. "\0")
        client.color_log(ar, ag, ab, "]")
        if menu.visuals.screen_logs:get() then
            table.insert(for_rendering, 1, {text = "[project john] missed in " .. tname .. "'s " .. hitbox ..  " for " .. dmg, alpha = 0, add_y = 0, tick = globals.curtime() * 64, randomize = math.random(0, 100)})
        end
        main_massive_logs = {}
    end
end

function aim_fire(e)
    local tickrate = client.get_cvar("cl_cmdrate") or 64
    local ticks = globals.tickcount() - e.tick
    main_massive_logs[e.id] = {
        hitbox = hitgroup_names[e.hitgroup + 1],
        damage = e.damage,
        backtrack = ticks,
        target = e.target,
        hitchance = e.hit_chance,
        target_hp = entity.get_prop(e.target, "m_iHealth"),
    }
    reset_tick()
end
--]=]

for_rendering = {}

function reset_tick()
    ram.aa_tickrate = 1
    ram.tick_def_off = 0
    reset_def()
end

do
    local MISS_COLOR = { r = 255, g = 0, b = 50, a = 255 }
    local MISS_SPREAD_COLOR = { r = 255, g = 205, b = 0, a = 255 }
    
    local last_aim_data = { backtrack = 0, hitgroup = 0, damage = 0 }
    local last_hit_data = { hit_chance = 70 }
    
    local hitgroup_names = { 
        [0] = 'generic', 'head', 'chest', 'stomach', 
        'left arm', 'right arm', 'left leg', 'right leg', 
        'neck', '?', 'gear' 
    }
    
    local function log_miss_to_console(e, victim_name, wanted_hitgroup, wanted_damage, hit_chance, backtrack, color, accent)
        client.color_log(accent.r, accent.g, accent.b, "Missed in \0")
        client.color_log(color.r, color.g, color.b, victim_name .. "'s \0")
        client.color_log(color.r, color.g, color.b, wanted_hitgroup .. "\0")
        client.color_log(accent.r, accent.g, accent.b, " due to \0")
        client.color_log(color.r, color.g, color.b, e.reason .. " \0")
        client.color_log(accent.r, accent.g, accent.b, "[HT: \0")
        client.color_log(color.r, color.g, color.b, math.floor(hit_chance) .. "% \0")
        client.color_log(accent.r, accent.g, accent.b, "~ | ~ DMG: \0")
        client.color_log(color.r, color.g, color.b, wanted_damage .. " \0")
        client.color_log(accent.r, accent.g, accent.b, "~ | ~ BT: \0")
        client.color_log(color.r, color.g, color.b, backtrack .. "\0")
        client.color_log(accent.r, accent.g, accent.b, "]\n")
    end
    
    local function log_hit_to_console(e, victim_name, group, damage, health, hit_chance, backtrack, wanted_hitgroup, wanted_damage, color, accent)
        local weapon = e.weapon
        local hit_type = 'hit'
        if weapon == 'hegrenade' then 
            hit_type = 'naded'
        elseif weapon == 'inferno' then
            hit_type = 'burned'
        elseif weapon == 'knife' then 
            hit_type = 'knifed'
        end

        if hit_type == 'hit' then
            client.color_log(accent.r, accent.g, accent.b, "Damage given to \0")
            client.color_log(color.r, color.g, color.b, victim_name .. "\0")
            client.color_log(accent.r, accent.g, accent.b, "'s \0")
            client.color_log(color.r, color.g, color.b, group .. " \0")
            client.color_log(accent.r, accent.g, accent.b, "~ \0")
            client.color_log(color.r, color.g, color.b, damage .. " (" .. wanted_damage .. ") \0")
            client.color_log(accent.r, accent.g, accent.b, "[HT: \0")
            client.color_log(color.r, color.g, color.b, math.floor(hit_chance) .. "% \0")
            client.color_log(accent.r, accent.g, accent.b, "~ | ~ BT:\0 ")
            client.color_log(color.r, color.g, color.b, backtrack .. "\0")
            client.color_log(accent.r, accent.g, accent.b, " ~ | ~ RHP:\0 ")
            client.color_log(color.r, color.g, color.b, health .. "\0")
            client.color_log(accent.r, accent.g, accent.b, "]\n")
        else
            client.color_log(accent.r, accent.g, accent.b, hit_type:sub(1,1):upper() .. hit_type:sub(2) .. " \0")
            client.color_log(color.r, color.g, color.b, victim_name .. " \0")
            client.color_log(accent.r, accent.g, accent.b, "for \0")
            client.color_log(color.r, color.g, color.b, damage .. " \0")
            client.color_log(accent.r, accent.g, accent.b, "damage [RHP: \0")
            client.color_log(color.r, color.g, color.b, health .. "\0")
            client.color_log(accent.r, accent.g, accent.b, "]\n")
        end
    end
    
    local function on_aim_fire(e)
        if not menu.visuals.logs:get() then
            return
        end

        last_aim_data = { 
            backtrack = globals.tickcount() - e.tick or 0,
            hitgroup = e.hitgroup or 0, 
            damage = e.damage or 0 
        }
        reset_tick()
    end
    
    local function on_aim_hit(e)
        if not menu.visuals.logs:get() then
            return
        end

        last_hit_data = { 
            hit_chance = e.hit_chance or 70,
        }
    end
    
    local function on_aim_miss(e)
        if not menu.visuals.logs:get() then
            return
        end

        local victim_name = entity.get_player_name(e.target) or 'unknown'
        local wanted_hitgroup = hitgroup_names[last_aim_data.hitgroup] or 'unknown'
        local wanted_damage = last_aim_data.damage or 0
        local hit_chance = e.hit_chance or 0
        local backtrack = last_aim_data.backtrack or 0
        
        local color
        if e.reason == 'spread' or e.reason == 'prediction error' then
            color = MISS_SPREAD_COLOR
        else
            color = MISS_COLOR
        end

        local ar, ag, ab = menu.visuals.logs_color1:get()
        local accent = { r = ar, g = ag, b = ab, a = 255 }
        
        log_miss_to_console(
            e, 
            victim_name, 
            wanted_hitgroup, 
            wanted_damage, 
            hit_chance, 
            backtrack, 
            color,
            accent
        )

        if menu.visuals.screen_logs:get() then
            local text = string.format("[project john] missed in %s's %s for %d", victim_name, wanted_hitgroup, wanted_damage)
            table.insert(for_rendering, 1, {text = text, alpha = 0, add_y = 0, tick = globals.curtime() * 64, randomize = math.random(0, 100)})
        end
    end
    
    local function on_player_hurt(e)
        if not menu.visuals.logs:get() then
            return
        end

        local attacker = client.userid_to_entindex(e.attacker)
        local local_player = entity.get_local_player()
        
        if attacker ~= local_player then 
            return 
        end
        
        local victim = client.userid_to_entindex(e.userid)
        local victim_name = entity.get_player_name(victim) or 'unknown'
        local damage = e.dmg_health or 0
        local hitgroup = e.hitgroup or 0
        local group = hitgroup_names[hitgroup] or 'unknown'
        local wanted_hitgroup = hitgroup_names[last_aim_data.hitgroup] or 'unknown'
        local wanted_damage = last_aim_data.damage or 0
        local hit_chance = last_hit_data.hit_chance or 0
        local backtrack = last_aim_data.backtrack or 0
        local health = e.health or 0

        local ar, ag, ab = menu.visuals.logs_color1:get()
        local hr, hg, hb = menu.visuals.logs_color2:get()
        local accent = { r = ar, g = ag, b = ab, a = 255 }
        local color = { r = hr, g = hg, b = hb, a = 255 }
        
        log_hit_to_console(
            e,
            victim_name, 
            group, 
            damage, 
            health, 
            hit_chance, 
            backtrack, 
            wanted_hitgroup, 
            wanted_damage, 
            color,
            accent
        )

        if menu.visuals.screen_logs:get() then
            local text
            local weapon = e.weapon
            if weapon == 'hegrenade' then
                text = string.format("[project john] naded %s for %d damage (remaining HP: %d)", victim_name, damage, health)
            elseif weapon == 'inferno' then
                text = string.format("[project john] burned %s for %d damage (remaining HP: %d)", victim_name, damage, health)
            elseif weapon == 'knife' then
                text = string.format("[project john] knifed %s for %d damage (remaining HP: %d)", victim_name, damage, health)
            else
                text = string.format("[project john] damage given to %s for %d (%d)", victim_name, damage, wanted_damage)
            end
            table.insert(for_rendering, 1, {text = text, alpha = 0, add_y = 0, tick = globals.curtime() * 64, randomize = math.random(0, 100)})
        end
    end
    
    client.set_event_callback('aim_fire', on_aim_fire)
    client.set_event_callback('aim_hit', on_aim_hit)
    client.set_event_callback('aim_miss', on_aim_miss)
    client.set_event_callback('player_hurt', on_player_hurt)
end

function set_on()
    local players = entity.get_players(false)
    local lp = entity.get_local_player()
    if #players > 1 then
        for i, player in ipairs(players) do
            team_num_p = entity.get_prop(player, "m_iTeamNum")
            team_num_lp = entity.get_prop(lp, "m_iTeamNum")
            if team_num_lp == team_num_p and menu.misc.teammate_whitelist:get() then
                plist.set(player, "Allow shared ESP updates", true)
            else
                plist.set(player, "Allow shared ESP updates", false)
            end
        end
    end
end

local render = {
    text = function(x, w, r, g, b, a, flags, max_width, texting)
        renderer.text(x, w, r, g, b, a, flags, max_width, texting)
    end,
    measure_text = function(flags, texting)
        if(renderer.measure_text("-", "oh shit") == renderer.measure_text(flags, "oh shit")) then
            texting = string.upper(texting)
        end
        return renderer.measure_text(flags, texting)
    end,
    rounded_rectangle = function(x, y, w, h, r, g, b, a, radius)
        y = y + radius
        local data_circle = {
            {x + radius, y, 180},
            {x + w - radius, y, 90},
            {x + radius, y + h - radius * 2, 270},
            {x + w - radius, y + h - radius * 2, 0},
        }
    
        local data = {
            {x + radius, y, w - radius * 2, h - radius * 2},
            {x + radius, y - radius, w - radius * 2, radius},
            {x + radius, y + h - radius * 2, w - radius * 2, radius},
            {x, y, radius, h - radius * 2},
            {x + w - radius, y, radius, h - radius * 2},
        }
    
        for _, data in next, data_circle do
            renderer.circle(data[1], data[2], r, g, b, a, radius, data[3], 0.25)
        end
    
        for _, data in next, data do
            renderer.rectangle(data[1], data[2], data[3], data[4], r, g, b, a)
        end
    end,
    rounded_outline = function(x, y, w, h, r, g, b, a, thickness, radius)
        renderer.rectangle(x + radius, y, w - radius * 2, thickness, r, g, b, a)
        renderer.rectangle(x + w - thickness, y + radius, thickness, h - radius * 2, r, g, b, a)
        renderer.rectangle(x, y + radius, thickness, h - radius * 2, r, g, b, a)
        renderer.rectangle(x + radius, y + h - thickness, w - radius * 2, thickness, r, g, b, a)
        renderer.circle_outline(x + radius, y + radius, r, g, b, a, radius, 180, 0.25, thickness)
        renderer.circle_outline(x - radius + w, y + radius, r, g, b, a, radius, 270, 0.25, thickness)
        renderer.circle_outline(x + radius, y - radius + h, r, g, b, a, radius, 90, 0.25, thickness)
        renderer.circle_outline(x - radius + w, y - radius + h, r, g, b, a, radius, 0, 0.25, thickness)
    end,
}

function render_logs()
    if menu.visuals.screen_logs:get() then
        local add_y = 0
        local const_x, const_y = client.screen_size()
        local x, y = const_x / 2, const_y / 2 + const_y / 4
        local r, g, b = menu.visuals.screen_log_color:get()
        
        -- Используем цвет из настроек скрипта
        local menu_r, menu_g, menu_b = r, g, b
        
        if #for_rendering >= 1 then
            for i, log in ipairs(for_rendering) do
                log.alpha = math.lerp(log.alpha, ((globals.curtime() * 64 - log.tick < 64 * 6) or i > 5) and 255 or 0, 0.02)
                local y2 = 0
                local y3 = 0
                local y = const_y / 2 + 230
                y2 = y + add_y
                y3 = const_y - y2
                y = const_y - y3 * log.alpha / 255
                
                local sizex, sizey = render.measure_text("c", log.text)
                local log_alpha = log.alpha / 255
                
                -- СТАРЫЕ ЛОГИ (ЗАКОММЕНТИРОВАНЫ)
                --[[
                -- Основной фон - темно-серый с закругленными углами
                local bg_alpha = math.floor(140 * log_alpha)
                render.rounded_rectangle(x - sizex / 2 - 12, y + add_y - 8, sizex + 24, sizey + 16, 25, 25, 25, bg_alpha, 15)
                
                -- Тонкая граница (убрана)
                local border_alpha = math.floor(200 * log_alpha)
                render.rounded_outline(x - sizex / 2 - 12, y + add_y - 8, sizex + 24, sizey + 16, 60, 60, 60, border_alpha, 1, 15)
                
                -- Декоративные круги по бокам (закомментированы)
                local circle_alpha = math.floor(180 * log_alpha)
                local circle_y = y + add_y + sizey / 2
                
                -- Левый круг
                renderer.circle(x - sizex / 2 - 6, circle_y, 80, 80, 80, circle_alpha, 3, 0, 1)
                renderer.circle_outline(x - sizex / 2 - 6, circle_y, 100, 100, 100, circle_alpha, 4, 0, 1, 1)
                
                -- Правый круг
                renderer.circle(x + sizex / 2 + 6, circle_y, 80, 80, 80, circle_alpha, 3, 0, 1)
                renderer.circle_outline(x + sizex / 2 + 6, circle_y, 100, 100, 100, circle_alpha, 4, 0, 1, 1)
                
                -- Тень для текста
                local shadow_alpha = math.floor(40 * log_alpha)
                render.text(x + 1, y + add_y + 1, 0, 0, 0, shadow_alpha, "c", 0, log.text)
                
                -- Основной текст (точно по центру)
                local text_alpha = math.floor(255 * log_alpha)
                render.text(x, y + add_y + 5, 255, 255, 255, text_alpha, "c", 0, log.text)
                --]]
                
                -- ИСПРАВЛЕННЫЕ ЛОГИ
                local bg_alpha = math.floor(160 * log_alpha)
                local border_alpha = math.floor(220 * log_alpha)
                local accent_alpha = math.floor(255 * log_alpha)
                
                -- Основной фон
                renderer.rectangle(x - sizex / 2 - 15, y + add_y - 10, sizex + 30, sizey + 20, 18, 18, 22, bg_alpha)
                
                -- Акцентная полоса сверху (цвет из настроек)
                renderer.rectangle(x - sizex / 2 - 15, y + add_y - 10, sizex + 30, 2, menu_r, menu_g, menu_b, accent_alpha)
                
                -- Тонкая граница
                renderer.rectangle(x - sizex / 2 - 15, y + add_y - 10, 1, sizey + 20, 45, 45, 50, border_alpha) -- левая
                renderer.rectangle(x + sizex / 2 + 14, y + add_y - 10, 1, sizey + 20, 45, 45, 50, border_alpha) -- правая
                renderer.rectangle(x - sizex / 2 - 15, y + add_y - 10, sizex + 30, 1, 45, 45, 50, border_alpha) -- верхняя
                renderer.rectangle(x - sizex / 2 - 15, y + add_y + sizey + 9, sizex + 30, 1, 45, 45, 50, border_alpha) -- нижняя
                
                -- Декоративные элементы (цвет из настроек)
                local pulse = math.sin(globals.curtime() * 2 + i * 0.5) * 0.5 + 0.5
                local glow_alpha = math.floor(80 * pulse * log_alpha)
                
                -- Левый декоративный элемент
                renderer.circle(x - sizex / 2 - 8, y + add_y + sizey / 2, menu_r, menu_g, menu_b, glow_alpha, 2, 0, 1)
                renderer.circle_outline(x - sizex / 2 - 8, y + add_y + sizey / 2, menu_r, menu_g, menu_b, glow_alpha, 3, 0, 1, 1)
                
                -- Правый декоративный элемент
                renderer.circle(x + sizex / 2 + 8, y + add_y + sizey / 2, menu_r, menu_g, menu_b, glow_alpha, 2, 0, 1)
                renderer.circle_outline(x + sizex / 2 + 8, y + add_y + sizey / 2, menu_r, menu_g, menu_b, glow_alpha, 3, 0, 1, 1)
                
                -- Тень для текста
                local shadow_alpha = math.floor(50 * log_alpha)
                render.text(x + 1, y + add_y + 1, 0, 0, 0, shadow_alpha, "c", 0, log.text)
                
                -- Основной текст (простой, без разбивки на слова)
                local text_alpha = math.floor(255 * log_alpha)
                render.text(x, y + add_y, 255, 255, 255, text_alpha, "c", 0, log.text)
                
                -- Прогресс-бар внизу (цвет из настроек)
                local progress = (globals.curtime() * 64 - log.tick) / (64 * 6)
                local progress_width = (sizex + 30) * math.max(0, 1 - progress)
                if progress_width > 0 then
                    renderer.rectangle(x - sizex / 2 - 15, y + add_y + sizey + 8, progress_width, 1, menu_r, menu_g, menu_b, accent_alpha)
                end
                
                add_y = add_y + (24) * log_alpha
                
                if((globals.curtime() * 64 - log.tick > 64 * 8 and y + add_y > const_y - 25) or y + add_y > const_y + 25) then
                    table.remove(for_rendering, i)
                end
            end
        end
    end
end
function watermark()
    local x, y = client.screen_size()
    render.text(x / 2, y - 35, 255, 255, 250, 255, "c", 0, "P R O J E C T   J O N H")
end

local anim = {}

local math_hundred_floor = function(valu)
    return (math.floor(valu * 100) / 100)
end

anim.default = function(tog, val, towhat, speed, if_not_tog)
    local wanted_frametime = 80
    local current_frametime = 1 / globals.frametime()
    local percent = wanted_frametime / current_frametime
    if(tog) then
        if(towhat == 255) then
            if(val > 235) then
                val = 255
            else
                if(val < towhat) then
                    val = val + globals.frametime() * speed * 1.5 * 64
                end
                if(val > towhat) then
                    val = val - globals.frametime() * speed * 1.5 * 64
                end
            end
        else
            if(math.floor(val / 10) == math.floor(towhat / 10)) then
                val = towhat
            else
                if(val < towhat) then
                    val = val + globals.frametime() * speed * 2 * 64
                end
                if(val > towhat) then
                    val = val - globals.frametime() * speed * 2 * 64
                end
            end
        end
    else
        if(math_hundred_floor(val) <= math_hundred_floor(if_not_tog)) then
            val = if_not_tog
        end
        if(math_hundred_floor(val) > if_not_tog) then
            val = val - speed * percent
        end
    end
    return math.floor(val)
end

function indicators(lp)
    local x, y = client.screen_size()
    if not (lp and entity.is_alive(lp)) and not ui.is_menu_open() then return end
    local r, g, b = menu.visuals.ind_color:get()

    local doubletap_ref = ref.dt:get() and ref.dt:get_hotkey()

    if ind.pulse.toggle then
        if math.ceil(ind.pulse.alpha) < 255 then
            ind.pulse.alpha = ind.pulse.alpha + globals.frametime() * 255
        else
            ind.pulse.toggle = false
        end
    else
        if math.floor(ind.pulse.alpha) > 0 then
            ind.pulse.alpha = ind.pulse.alpha - globals.frametime() * 255
        else
            ind.pulse.toggle = true
        end
    end

    if(lp ~= nil and entity.is_alive(lp)) then
        if(entity.get_prop(lp, "m_bIsScoped") == 1) then
            ind.zoomed = true
        else
            ind.zoomed = false
        end
    else
        ind.zoomed = false
    end
    if not lp then
        ind.scoped.state_name = "MENU"
    end
    local x_project_john_lua = render.measure_text("-", "PROJECT JOHN DEV")
    local x_project_john = render.measure_text("-", "PROJECT JOHN")
    local x_state = render.measure_text("-", ind.scoped.state_name)
    if ind.dt_state ~= "" then
        ind.add_state = " " .. ind.dt_state
    else
        ind.add_state = ""
    end
    local x_dt = render.measure_text("-", "RAPID" .. ind.add_state)
    local x_rapid = render.measure_text("-", "RAPID ")
    local hideshots = render.measure_text("-", "AAOS " .. ind.hide_state)
    local x_hide = render.measure_text("-", "AAOS ")
    local x_freestand = render.measure_text("-", "DIRECTION")

    ind.scoped.name = math.ceil(math.lerp(ind.scoped.name, ind.zoomed and 0 or (x_project_john_lua + 10) * 100, 0.05))
    ind.scoped.state = math.ceil(math.lerp(ind.scoped.state, ind.zoomed and 0 or (x_state + 10) * 100, 0.05))
    ind.scoped.doubletap = math.ceil(math.lerp(ind.scoped.doubletap, ind.zoomed and 0 or (x_dt + 10) * 100, 0.05))
    ind.scoped.freestand = math.ceil(math.lerp(ind.scoped.freestand, ind.zoomed and 0 or (x_freestand + 10) * 100, 0.05))
    ind.scoped.hideshots = math.ceil(math.lerp(ind.scoped.hideshots, ind.zoomed and 0 or (hideshots + 10) * 100, 0.05))

    y_s = y / 2 + menu.visuals.indicator_y:get() - 35

    render.text(x / 2 - ind.scoped.name / 100 / 2 + 5, y_s + 35, 255, 255, 255, 225, "-", 0, "PROJECT JOHN")
    render.text(x / 2 - ind.scoped.name / 100 / 2 + 5 + x_project_john, y_s + 35, r, g, b, math.clamp(ind.pulse.alpha * 225 / 255, 0, 225), "-", 0, " DEV")
    render.text(x / 2 - ind.scoped.state / 100 / 2 + 5, y_s + 45, 255, 255, 255, 225, "-", 0, ind.scoped.state_name)

    ind.dt_alpha = math.ceil(math.lerp(ind.dt_alpha, (doubletap_ref and 255 or 0) * 100, 0.1))
    ind.hide_alpha = math.ceil(math.lerp(ind.hide_alpha, (ref.hs:get_hotkey() and not doubletap_ref and 255 or 0) * 100, 0.1))
    ind.fr_alpha = math.ceil(math.lerp(ind.fr_alpha, (menu.aa_options.freestand:get() and 255 or 0) * 100, 0.1))

    ind.ideal_pick = anim.default(ind.dt_state == "IDEAL PICK", ind.ideal_pick, 255, 15, 0)
    ind.dt_charge_alpha = anim.default(ind.dt_state == "READY" or ind.dt_state == "ACTIVE", ind.dt_charge_alpha, 255, 15, 0)
    ind.dt_wait_alpha = anim.default(ind.dt_state == "WAIT", ind.dt_wait_alpha, 255, 15, 0)

    ind.hide_charging_alpha = anim.default(ind.hide_state == "CHARGING", ind.hide_charging_alpha, 255, 15, 0)
    ind.hide_ready_alpha = anim.default(ind.hide_state ~= "CHARGING", ind.hide_ready_alpha, 255, 15, 0)

    local add_y = 0
    if math.ceil(ind.dt_alpha) > 0 then
        render.text(x / 2 - ind.scoped.doubletap / 100 / 2 + 5 + x_rapid, y_s + 55, 240, 200, 50, ind.dt_alpha / 100 * 225 / 255, "-", 0, string.sub("IDEAL PICK", 1, math.floor(string.len("IDEAL PICK") * ind.ideal_pick / 255) + 0.5))
        render.text(x / 2 - ind.scoped.doubletap / 100 / 2 + 5, y_s + 55, 255, 255, 255, ind.dt_alpha / 100 * 225 / 255, "-", 0, "RAPID ")
        if ind.dt_state == "ACTIVE" then
            rm, gm, bm = 211, 255, 50
        else
            rm, gm, bm = 150, 255, 150
        end
        render.text(x / 2 - ind.scoped.doubletap / 100 / 2 + 5 + x_rapid, y_s + 55, rm, gm, bm, ind.dt_alpha / 100 * ind.dt_charge_alpha / 255 * 225 / 255, "-", 0, string.sub(ind.dt_state == "ACTIVE" and "ACTIVE" or "READY", 1, math.floor(string.len(ind.dt_state == "ACTIVE" and "ACTIVE" or "READY") * ind.dt_charge_alpha / 255) + 0.5))
        render.text(x / 2 - ind.scoped.doubletap / 100 / 2 + 5 + x_rapid, y_s + 55, 255, 15, 15, ind.dt_alpha / 100 * ind.dt_wait_alpha / 255 * 225 / 255, "-", 0, string.sub("WAIT", 1, math.floor(string.len("WAIT") * ind.dt_wait_alpha / 255) + 0.5))
        add_y = add_y + 10 * math.ceil(ind.dt_alpha) / 100 / 255
    end
    if math.ceil(ind.hide_alpha) > 0 then
        render.text(x / 2 - ind.scoped.hideshots / 100 / 2 + 5, y_s + 55, 255, 255, 255, ind.hide_alpha / 100 * 225 / 255, "-", 0, "AAOS ")
        render.text(x / 2 - ind.scoped.hideshots / 100 / 2 + 5 + x_hide, y_s + 55, 255, 15, 15, ind.hide_alpha / 100 * 225 / 255 * ind.hide_charging_alpha / 255, "-", 0, string.sub("CHARGING", 1, math.floor(string.len("CHARGING") * ind.hide_charging_alpha / 255) + 0.5))
        if ind.hide_state == "ACTIVE" then
            rh, gh, bh = 211, 255, 50
        else
            rh, gh, bh = 150, 255, 150
        end
        render.text(x / 2 - ind.scoped.hideshots / 100 / 2 + 5 + x_hide, y_s + 55, rh, gh, bh, ind.hide_alpha / 100 * 225 / 255 * ind.hide_ready_alpha / 255, "-", 0, string.sub(ind.hide_state == "ACTIVE" and "ACTIVE" or "READY", 1, math.floor(string.len(ind.dt_state == "ACTIVE" and "ACTIVE" or "READY") * ind.hide_ready_alpha / 255) + 0.5))
        add_y = add_y + 10 * math.ceil(ind.hide_alpha) / 100 / 255
    end
    if math.ceil(ind.fr_alpha) > 0 then
        render.text(x / 2 - ind.scoped.freestand / 100 / 2 + 5, y_s + 55 + math.floor(add_y), 255, 255, 255, ind.fr_alpha / 100 * 225 / 255, "-", 0, string.sub("DIRECTION", 1, math.floor(string.len("DIRECTION") * ind.fr_alpha / 255 / 100) + 1))
    end
end

function paint()
    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then
        for_rendering = {}
    end
    watermark()
    if menu.visuals.screen_logs:get() then
        render_logs()
    end
    if menu.visuals.indicators:get() then
        indicators(lp)
    else
        ind = {
            alpha = 0,
            pulse = {
                alpha = 0,
                toggle = false,
            },
            dt_alpha = 0,
            dt_state = "",
            dt_charge_alpha = 0,
            dt_wait_alpha = 0,
            scoped = {
                name = 0,
                state = 0,
                state_name = "MENU",
                doubletap = 0,
                freestand = 0,
                hideshots = 0,
            },
            hide_state = "READY",
            zoomed = false,
            tickbase = 0,
            fr_alpha = 0,
            ideal_pick = 0,
            hide_alpha = 0,
            hide_charging_alpha = 0,
            hide_ready_alpha = 0,
        }
    end
    if menu.enable:get() and menu.misc.predict:get() and lp and entity.is_alive(lp) then
        local r, g, b = menu.visuals.ind_color:get()
        renderer.indicator(r, g, b, 255, "P")
    end
    set_menu_builder()
end

aspect_ratio()
menu.enable:set_callback(aspect_ratio)
menu.visuals.aspect_ratio_type:set_callback(aspect_ratio)
menu.visuals.normal_aspect_ratio:set_callback(aspect_ratio)
menu.visuals.newcomer_aspect_ratio:set_callback(aspect_ratio)

client.set_event_callback("paint_ui", paint)

-- client.set_event_callback("aim_miss", aim_miss)
-- client.set_event_callback("aim_hit", aim_hit)
-- client.set_event_callback("aim_fire", aim_fire)

function reset()
    for_rendering = {}
    reset_def()
end

client.set_event_callback("round_prestart", reset)

local duck_peek_fix = {}
do
    local saved_fd_state = nil
    local modified = false
    local last_enabled = false
    local hotkey_modes = { [0] = "Always on", [1] = "On hotkey", [2] = "Toggle", [3] = "Off hotkey" }

    function duck_peek_fix.run(cmd)
        if not menu.misc.duck_peek_assist_fix:get() then
            if last_enabled and saved_fd_state then
                ui.set(ref.fakeduck.ref, unpack(saved_fd_state))
                saved_fd_state = nil
                modified = false
                last_enabled = false
            end
            return
        end
        last_enabled = true

        local lp = entity.get_local_player()
        if (not lp) or (not entity.is_alive(lp)) then return end

        local ducking = (cmd.in_duck == 1) and (entity.get_prop(lp, "m_flDuckAmount") > 0.8)
        
        local active = ui.get(ref.fakeduck.ref)
        local mode, key
        if ui.get_hotkey ~= nil then
            mode, key = ui.get_hotkey(ref.fakeduck.ref)
        else
            local _, m, k = ui.get(ref.fakeduck.ref)
            mode = m
            key = k
        end

        if ducking and active and (not modified) then
            saved_fd_state = { hotkey_modes[mode] or "Off hotkey", key }
            local new_mode = (((mode == 2) or (mode == 3)) and "On hotkey") or "Off hotkey"
            ui.set(ref.fakeduck.ref, new_mode)
            modified = true
        elseif (not ducking) and modified and saved_fd_state then
            ui.set(ref.fakeduck.ref, unpack(saved_fd_state))
            saved_fd_state = nil
            modified = false
        end
    end
end

local auto_exploit = {}
do
    local last_enabled = false
    local saved_dt_state = nil

    local hotkey_modes = { [0] = "Always on", [1] = "On hotkey", [2] = "Toggle", [3] = "Off hotkey" }
    local saved_states = {}
    local forced_states = {}

    local function get_hotkey_state(item)
        if not item or not item.hotkey or not item.hotkey.ref then
            return nil
        end
        local mode, key
        if ui.get_hotkey ~= nil then
            mode, key = ui.get_hotkey(item.hotkey.ref)
        else
            local _, m, k = ui.get(item.hotkey.ref)
            mode = m
            key = k
        end
        return { hotkey_modes[mode] or "Off hotkey", key }
    end

    local function restore_hotkey(item, id)
        if forced_states[id] and saved_states[id] then
            item:set_hotkey(unpack(saved_states[id]))
            saved_states[id] = nil
            forced_states[id] = false
        end
    end

    local function force_hotkey(item, id)
        if not forced_states[id] then
            local state = get_hotkey_state(item)
            if state then
                saved_states[id] = state
                item:set_hotkey("Always on")
                forced_states[id] = true
            end
        end
    end

    local function table_contains(tbl, value)
        for _, v in ipairs(tbl) do
            if v == value then return true end
        end
        return false
    end

    local function is_in_fake_lag(cmd)
        local choked = cmd and cmd.chokedcommands or 0
        if ref.fl_enable:get() then
            if ref.fl_limit:get() > 1 then
                local dt = (saved_dt_state ~= nil and saved_dt_state or ref.dt:get()) and ref.dt:get_hotkey()
                local osaa = ref.hs:get() and ref.hs:get_hotkey()
                local not_fd = not ref.fakeduck:get()
                if dt and not_fd then
                    if choked > ref.dt_limit:get() then
                        return true
                    end
                elseif osaa and not_fd then
                    if choked > 1 then
                        return true
                    end
                elseif choked ~= nil then
                    return true
                end
            end
        end
        return false
    end

    local function get_state_name_local(lp)
        local flags = entity.get_prop(lp, "m_fFlags") or 0
        local on_ground = bit.band(flags, 1) ~= 0
        local speed = player.get_velocity(lp)
        if not on_ground then
            return "In air"
        end
        local fd = ref.fakeduck:get()
        local in_duck = player.in_duck(lp) or fd
        if in_duck then
            if speed > 10 then
                return "Sneaking"
            else
                return "Crouching"
            end
        else
            if speed > 10 then
                local slow_motion_active = ref.slow_motion and ref.slow_motion:get() and ref.slow_motion:get_hotkey()
                if slow_motion_active then
                    return "Walking"
                else
                    return "Moving"
                end
            else
                return "Standing"
            end
        end
    end

    local function get_weapon_category(lp)
        local active_weapon = entity.get_prop(lp, "m_hActiveWeapon")
        if not active_weapon then return "None" end
        local weapon_idx = entity.get_prop(active_weapon, "m_iItemDefinitionIndex")
        if not weapon_idx then return "None" end
        local info = csgo_weapons[weapon_idx]
        if not info then return "None" end
        local name = info.console_name or ""
        name = name:gsub("weapon_", ""):gsub("_.*", "")
        
        if name == "deagle" then
            return "Deagle"
        end
        if name == "g3sg1" or name == "scar20" then
            return "Auto snipers"
        end
        if info.type == 1 then
            return "Pistols"
        end
        return "Other"
    end

    local function should_exploit(cmd, lp)
        if is_in_fake_lag(cmd) then return false end
        local states = menu.misc.auto_exploit_states:get() or {}
        local state = get_state_name_local(lp)
        if not table_contains(states, state) then return false end

        local avoid = menu.misc.auto_exploit_avoid:get() or {}
        local weapon = get_weapon_category(lp)
        if table_contains(avoid, "Pistols") and (weapon == "Pistols") then return false end
        if table_contains(avoid, "Desert Eagle") and (weapon == "Deagle") then return false end
        if table_contains(avoid, "Auto snipers") and (weapon == "Auto snipers") then return false end
        if table_contains(avoid, "Desert Eagle + Crouch") and (weapon == "Deagle") and ((state == "Crouching") or (state == "Sneaking")) then return false end
        return true
    end

    function auto_exploit.run(cmd)
        if not menu.misc.auto_exploit:get() then
            if last_enabled then
                if saved_dt_state ~= nil then
                    ref.dt:override()
                    ref.dt:set(saved_dt_state)
                    saved_dt_state = nil
                end
                restore_hotkey(ref.hs, "on_shot")
                restore_hotkey(ref.dt, "double_tap")
                last_enabled = false
            end
            return
        end
        last_enabled = true

        local lp = entity.get_local_player()
        if not lp or not entity.is_alive(lp) then return end

        if should_exploit(cmd, lp) then
            if saved_dt_state == nil then
                saved_dt_state = ref.dt:get()
            end
            ref.dt:override(false)
            restore_hotkey(ref.dt, "double_tap")
            force_hotkey(ref.hs, "on_shot")
        else
            if saved_dt_state ~= nil then
                ref.dt:override()
                ref.dt:set(saved_dt_state)
                saved_dt_state = nil
            end
            restore_hotkey(ref.hs, "on_shot")
            restore_hotkey(ref.dt, "double_tap")
        end
    end
end

function setup_commanding(cmd)
    local lp = entity.get_local_player()
    update_data(cmd, lp, client.current_threat())
    
    local is_e = cmd.in_use == 1
    local is_defusing = false
    local bomb = entity.get_all("CPlantedC4")
    if #bomb > 0 then
        local lpos = vector(entity.get_origin(lp))
        local c4pos = vector(entity.get_origin(bomb[#bomb]))
        if lpos:dist(c4pos) < 50 and entity.get_prop(lp, "m_iTeamNum") == 3 then
            is_defusing = true
        end
    end
    local in_bomb_zone = entity.get_prop(lp, "m_bInBombZone") == 1
    local is_t = entity.get_prop(lp, "m_iTeamNum") == 2
    local is_planting = in_bomb_zone and is_t

    local is_legit_active = is_e and not is_defusing and not is_planting and menu.builder[8] and menu.builder[8].enable:get()
    ram.is_legit_active = is_legit_active
    local base_state = player.get_state(cmd, lp)
    if is_legit_active then
        base_state = 7
        cmd.in_use = 0
    end

    local is_manual_active = menu.aa_options.manual_base:get() ~= "None" and not is_legit_active
    local is_freestanding = is_freestand(lp) and menu.aa_options.freestand_cond:get(lua.conds_no_g[base_state]) and menu.aa_options.freestand:get() and not is_manual_active

    local state = base_state
    if is_manual_active then
        state = 8
    elseif is_freestanding then
        state = 9
    end

    ind.scoped.state_name = not is_manual_active and ("-" .. string.upper(lua.conds_no_g[state]) .. "-") or ("-" .. string.upper(menu.aa_options.manual_base:get()) .. "-")
    local avoid_backstabing = false
    local safe_head = false
    local side = "none"
    if menu.misc.avoid_backstab:get() then
        if target_data.en_num ~= nil then
            avoid_backstabing = avoid_backstab(lp, target_data.en_num)
        end
    end
    if(menu.builder[state + 1].enable:get()) then
        tab = menu.builder[state + 1]
        active_state_id = state + 1
    else
        tab = menu.builder[1]
        active_state_id = 1
    end
    if menu.aa_options.safe_head:get() then
        if lp_data.jumping or not lp_data.ground then
            if lp_data.weapon == "CKnife" or lp_data.weapon == "CWeaponTaser" then
                safe_head = true
            end
        end
    end
    if menu.aa_options.defensive:get() then
        side = body_freestand(lp)
    end
    builder(cmd, base_state, tab, avoid_backstabing, lp, safe_head, side)
    aa_setting(cmd)
    -- charging(lp)
    duck_peek_fix.run(cmd)
    auto_exploit.run(cmd)
end

function pre_rendering()
    local lp = entity.get_local_player()
    if lp == nil or not entity.is_alive(lp) then return end
    local local_index = c_entity.new(lp)
    local local_anim_state = local_index:get_anim_state()

    -- Original animfix
    local animfix_selected = menu.misc.animfix:get() or {}
    if #animfix_selected > 0 then
        if menu.misc.animfix:get("Legs") then
            entity.set_prop(lp, "m_flPoseParameter", 1, globals.tickcount() % 4 > 1 and 0.5 or 1)
        end
        if menu.misc.animfix:get("Jumping") then
            entity.set_prop(lp, "m_flPoseParameter", client.random_int(0, 10) / 10, 6)
        end
        if menu.misc.animfix:get("Dirty sprite") then
            local self_anim_overlay = local_index:get_anim_overlay(12)
            if self_anim_overlay then
                self_anim_overlay.weight = player.get_velocity(lp) / 30
            end
        end

        -- Static in air
        if menu.misc.animfix:get("Static in air") then
            local flags = entity.get_prop(lp, "m_fFlags")
            if flags and bit.band(flags, 1) == 0 then -- Not on ground
                local air_weight = menu.misc.static_in_air_value:get()
                entity.set_prop(lp, "m_flPoseParameter", air_weight * 0.01, 6)
            end
        end

        -- Move lean
        if menu.misc.animfix:get("Move lean") then
            local move_lean_val = menu.misc.move_lean_value:get()
            local vx, vy = entity.get_prop(lp, "m_vecVelocity")
            if vx and vy and (vx * vx + vy * vy) > 1.0 then
                local self_anim_overlay = local_index:get_anim_overlay(12)
                if self_anim_overlay then
                    self_anim_overlay.weight = move_lean_val * 0.01
                    pcall(function()
                        self_anim_overlay.weight_delta_rate = move_lean_val * 0.01
                    end)
                end
            end
        end
    end
end

client.set_event_callback('pre_render', pre_rendering)

function round_start()
    set_on()
    reset_tick()
    reset()
end

menu.misc.filter_console:set_callback(filter_console)
filter_console()
menu.misc.cvar_optimizer:set_callback(fps_opt)
fps_opt()
menu.misc.teammate_whitelist:set_callback(set_on)
client.set_event_callback("setup_command", setup_commanding) 
client.set_event_callback('round_start', round_start)

-- Defensive check system
client.set_event_callback('run_command', function(cmd)
    defensive_check.last_cmd = cmd.command_number
end)

client.set_event_callback('predict_command', function(arg_140_0)
    local lp = entity.get_local_player()
    if not lp then
        return
    end
    if defensive_check.last_cmd ~= arg_140_0.command_number then
        return
    end

    local tickbase = entity.get_prop(lp, "m_nTickBase") or 0

    if math.abs(tickbase - defensive_check.tickbase_max) > 64 then
        defensive_check.tickbase_max = 0
    end

    if tickbase > defensive_check.tickbase_max then
        defensive_check.tickbase_max = tickbase
    end

    defensive_check.lc_left = math.min(14, math.max(0, defensive_check.tickbase_max - tickbase - 1))
    defensive_check.defensive = defensive_check.lc_left > 0
end)

pui.setup({menu.builder, menu.aa_options, menu.misc, menu.visuals})


-- local function calculate_damage_to_stomach(weapon_idx, distance, enemy_armor)
--     local weapon = csgo_weapons[weapon_idx]
--     if not weapon then return 0 end
    
--     local weapon_adjust = weapon.damage
--     local dmg_after_range = (weapon_adjust * math.pow(weapon.range_modifier, (distance * 0.002)))
    
--     -- Проверяем существование armor_ratio
--     if weapon.armor_ratio then
--         -- Используем ту же логику расчета урона с броней, что и в ENEMY_DMG_HIT.lua
--         local newdmg = dmg_after_range * (weapon.armor_ratio * 0.5)
--         if dmg_after_range - (dmg_after_range * (weapon.armor_ratio * 0.5)) * 0.5 > enemy_armor then
--             newdmg = dmg_after_range - (enemy_armor / 0.5)
--         end
        
--         -- Применяем множитель для stomach (1.25)
--         return newdmg * 1.25
--     else
--         -- Если armor_ratio не существует, используем простой расчет
--         local base_damage = dmg_after_range * 1.25
--         if enemy_armor > 0 then
--             base_damage = base_damage * 0.45
--         end
--         return base_damage
--     end
-- end

local function calculate_damage_to_stomach(enemy_idx)
    local local_player = entity.get_local_player()
    if not local_player or not entity.is_alive(local_player) then return 0 end
    
    local weapon = entity.get_player_weapon(local_player)
    if not weapon then return 0 end
    
    local eye_x, eye_y, eye_z = client.eye_position()
    if not eye_x then return 0 end
    
    local hitboxes = {3, 4, 5, 6}
    local max_damage = 0
    
    for i = 1, #hitboxes do
        local hx, hy, hz = entity.hitbox_position(enemy_idx, hitboxes[i])
        if hx then
            local hit_ent, damage = client.trace_bullet(local_player, eye_x, eye_y, eye_z, hx, hy, hz, false)
            if damage and damage > max_damage then
                max_damage = damage
            end
        end
    end
    
    return max_damage
end

local function vtable_bind(module, interface, index, type)
    local ptr = ffi.cast("void***", client.create_interface(module, interface))
    local this = ptr[0]
    local fn = ffi.cast(type, this[index])
    return function(...)
        return fn(this, ...)
    end
end

local resolved_players = {}
local resolver_player_records = {}

function r_val(player_idx)
    if not player_idx then return 0 end
    local player_data = resolved_players[player_idx]
    if player_data then
        return player_data.resolve_yaw or 0
    end
    return 0
end

local function clear_resolver_data()
    resolver_player_records = {}
    resolved_players = {}
end

local get_client_entity = vtable_bind("client.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void*, int)")

local animstate_type = ffi.typeof([[
    struct {
        char pad0[0x18];
        float anim_update_timer;
        char pad1[0xC];
        float started_moving_time;
        float last_move_time;
        char pad2[0x10];
        float last_lby_time;
        char pad3[0x8];
        float run_amount;
        char pad4[0x10];
        void* entity;
        void* active_weapon;
        void* last_active_weapon;
        float last_client_side_animation_update_time;
        int last_client_side_animation_update_framecount;
        float eye_timer;
        float eye_angles_y;
        float eye_angles_x;
        float goal_feet_yaw;
        float current_feet_yaw;
        float torso_yaw;
        float last_move_yaw;
        float lean_amount;
        char pad5[0x4];
        float feet_cycle;
        float feet_yaw_rate;
        char pad6[0x4];
        float duck_amount;
        float landing_duck_amount;
        char pad7[0x4];
        float current_origin[3];
        float last_origin[3];
        float velocity_x;
        float velocity_y;
        char pad8[0x4];
        float unknown_float1;
        char pad9[0x8];
        float unknown_float2;
        float unknown_float3;
        float unknown;
        float m_velocity;
        float jump_fall_velocity;
        float clamped_velocity;
        float feet_speed_forwards_or_sideways;
        float feet_speed_unknown_forwards_or_sideways;
        float last_time_started_moving;
        float last_time_stopped_moving;
        bool on_ground;
        bool hit_in_ground_animation;
        char pad10[0x4];
        float time_since_in_air;
        float last_origin_z;
        float head_from_ground_distance_standing;
        float stop_to_full_running_fraction;
        char pad11[0x4];
        float magic_fraction;
        char pad12[0x3C];
        float world_force;
        char pad13[0x1CA];
        float min_yaw;
        float max_yaw;
    }**
]])

local function get_anim_state(player_idx)
    if not player_idx or entity.get_classname(player_idx) ~= "CCSPlayer" then
        return nil
    end
    local ent_ptr = get_client_entity(player_idx)
    if not ent_ptr then
        return nil
    end
    local casted_ptr = ffi.cast(animstate_type, ffi.cast("char*", ffi.cast("void***", ent_ptr)) + 39264)
    if casted_ptr == nil or casted_ptr[0] == nil then
        return nil
    end
    return casted_ptr[0]
end

local function get_old_simulation_time(player_idx)
    if not player_idx or entity.get_classname(player_idx) ~= "CCSPlayer" then
        return 0
    end
    local ent_ptr = get_client_entity(player_idx)
    if not ent_ptr then
        return 0
    end
    return ffi.cast("float*", ffi.cast("uintptr_t", ent_ptr) + 620)[0]
end

local function calculate_max_desync(animstate)
    if not animstate then
        return 60
    end
    local speed_fraction = math.clamp(animstate.feet_speed_forwards_or_sideways, 0, 1)
    local yaw_modifier = (((animstate.stop_to_full_running_fraction * -0.3) - 0.2) * speed_fraction) + 1
    local duck_amount = animstate.duck_amount
    if duck_amount > 0 then
        yaw_modifier = yaw_modifier + (duck_amount * speed_fraction * (0.5 - yaw_modifier))
    end
    return math.clamp(yaw_modifier, 0.5, 1) * 60
end

local function create_player_record(player_idx)
    local record = {}
    record.player = player_idx
    record.last_simtime = 0
    local origin_x, origin_y, origin_z = entity.get_origin(player_idx)
    record.origin = (origin_x ~= nil) and vector(origin_x, origin_y, origin_z) or nil
    record.broke_lc = false
    record.in_defensive = false
    record.ticks_left = 0
    record.max_tickbase = math.abs(client.get_cvar("sv_maxusrcmdprocessticks") or 16) - 1
    record.tickbase_difference = 0

    function record.update()
        local sim_time_prop = entity.get_prop(record.player, "m_flSimulationTime") or 0
        local sim_time_ticks = math.floor(sim_time_prop / globals.tickinterval() + 0.5)
        local temp_sim_ticks = sim_time_ticks
        local origin_x, origin_y, origin_z = entity.get_origin(record.player)
        local current_origin = (origin_x ~= nil) and vector(origin_x, origin_y, origin_z) or nil
        local tickbase = entity.get_prop(record.player, "m_nTickBase")
        local tick_difference = temp_sim_ticks - record.last_simtime
        if tickbase then
            if tick_difference < 0 then
                local choked_ticks = math.abs(tick_difference)
                record.ticks_left = math.clamp(choked_ticks, 0, record.max_tickbase)
                record.tickbase_difference = tickbase
            else
                if record.tickbase_difference > 0 then
                    local choked_ticks = math.abs(tickbase - record.tickbase_difference)
                    record.ticks_left = math.clamp(choked_ticks, 0, record.max_tickbase)
                end
                record.tickbase_difference = math.max(tickbase, record.tickbase_difference or 0)
            end
            record.in_defensive = (record.ticks_left > 1) and (record.ticks_left < record.max_tickbase)
        else
            record.in_defensive = false
            record.ticks_left = 0
        end
        if tick_difference >= 0 then
            if record.origin ~= nil and current_origin ~= nil then
                record.broke_lc = (record.origin - current_origin):length2dsqr() > 4096
            else
                record.broke_lc = false
            end
            if current_origin ~= nil then
                record.origin = current_origin
            end
        end
        record.last_simtime = temp_sim_ticks
    end

    resolver_player_records[player_idx] = record
    return record
end

local function apply_resolve_to_plist(player_idx, resolve_settings)
    plist.set(player_idx, "Force body yaw", resolve_settings.force_body_yaw and 1 or 0)
    plist.set(player_idx, "Force body yaw value", resolve_settings.yaw_value or 0)
end

local function analyze_update_delay(player_data, current_tick)
    if not player_data.angle_history then
        player_data.angle_history = {}
        player_data.delay_history = {}
        player_data.cached_delay = nil
        player_data.delay_consistency = 0
        player_data.last_update_tick = current_tick
        return nil
    end
    local tick_delta = current_tick - player_data.last_update_tick
    player_data.last_update_tick = current_tick
    if (tick_delta >= 2) and (tick_delta < 10) then
        table.insert(player_data.delay_history, tick_delta)
        if #player_data.delay_history > 8 then
            table.remove(player_data.delay_history, 1)
        end
        if #player_data.delay_history >= 3 then
            local sum_delays = 0
            local is_consistent = true
            local first_delay = player_data.delay_history[1]
            for idx = 1, #player_data.delay_history do
                sum_delays = sum_delays + player_data.delay_history[idx]
                if math.abs(player_data.delay_history[idx] - first_delay) > 1 then
                    is_consistent = false
                end
            end
            if is_consistent and (first_delay > 2) then
                player_data.cached_delay = first_delay
                player_data.delay_consistency = math.min(player_data.delay_consistency + 1, 5)
            else
                player_data.delay_consistency = math.max(player_data.delay_consistency - 1, 0)
                if player_data.delay_consistency == 0 then
                    player_data.cached_delay = nil
                end
            end
        end
    elseif tick_delta <= 2 then
        player_data.delay_consistency = math.max((player_data.delay_consistency or 0) - 1, 0)
        if player_data.delay_consistency == 0 then
            player_data.cached_delay = nil
            player_data.delay_history = {}
        end
    end
    return player_data.cached_delay
end

local function get_historical_angle(player_data, delay_ticks)
    if (not player_data.angle_history) or (#player_data.angle_history < (delay_ticks + 1)) then
        return nil
    end
    local history_idx = #player_data.angle_history - delay_ticks
    if (history_idx >= 1) and (history_idx <= #player_data.angle_history) then
        return player_data.angle_history[history_idx]
    end
    return nil
end

local function classify_anti_aim_state(player_data, yaw_delta, max_desync, current_tick)
    local abs_yaw_delta = math.abs(yaw_delta)
    if abs_yaw_delta < 5 then
        player_data.static_ticks = (player_data.static_ticks or 0) + 1
        if player_data.static_ticks >= 3 then
            return "S"
        end
    else
        player_data.static_ticks = 0
    end
    if abs_yaw_delta > 30 then
        player_data.jitter_ticks = (player_data.jitter_ticks or 0) + 1
        if player_data.jitter_ticks >= 2 then
            local cached_delay = analyze_update_delay(player_data, current_tick)
            if cached_delay and (player_data.delay_consistency >= 3) then
                return "DJ"
            end
            return "J"
        end
    else
        player_data.jitter_ticks = math.max((player_data.jitter_ticks or 0) - 1, 0)
    end
    return "S"
end

local function resolve_player(player_idx)
    local steamid = entity.get_steam64(player_idx)
    if steamid == 0 or steamid == "0" then
        return
    end
    local record = resolver_player_records[player_idx] or create_player_record(player_idx)
    record.update()
    local animstate = get_anim_state(player_idx)
    if not animstate then
        return
    end
    local sim_time = entity.get_prop(player_idx, "m_flSimulationTime")
    local old_sim_time = get_old_simulation_time(player_idx)
    local eye_angles_y = select(2, entity.get_prop(player_idx, "m_angEyeAngles"))
    if (not eye_angles_y) or (not sim_time) then
        return
    end
    local sim_time_ticks = math.floor(sim_time / globals.tickinterval() + 0.5)
    local player_data = resolved_players[player_idx]
    if not player_data then
        player_data = {
            last_yaw = eye_angles_y,
            last_simtime = sim_time,
            side = 1,
            jitter_ticks = 0,
            static_ticks = 0,
            no_update_ticks = 0,
            resolve_yaw = 0,
            last_resolve_yaw = 0,
            aa_state = "S",
            angle_history = {},
            delay_history = {},
            cached_delay = nil,
            delay_consistency = 0,
            last_update_tick = sim_time_ticks
        }
        resolved_players[player_idx] = player_data
        return
    end
    if (sim_time == player_data.last_simtime) or (sim_time == old_sim_time) then
        player_data.no_update_ticks = (player_data.no_update_ticks or 0) + 1
        local is_defensive = ((record.in_defensive ~= nil) and record.in_defensive) or false
        apply_resolve_to_plist(player_idx, {force_body_yaw = (not is_defensive), yaw_value = player_data.last_resolve_yaw})
        client.update_player_list()
        return
    end
    player_data.no_update_ticks = 0
    local yaw_delta = normalize_yaw(eye_angles_y - player_data.last_yaw)
    local max_desync = calculate_max_desync(animstate)
    table.insert(player_data.angle_history, eye_angles_y)
    if #player_data.angle_history > 16 then
        table.remove(player_data.angle_history, 1)
    end
    player_data.aa_state = classify_anti_aim_state(player_data, yaw_delta, max_desync, sim_time_ticks)
    if (player_data.aa_state == "DJ") and player_data.cached_delay then
        local historical_angle = get_historical_angle(player_data, player_data.cached_delay)
        if historical_angle then
            local angle_delta = normalize_yaw(eye_angles_y - historical_angle)
            if math.abs(angle_delta) > 30 then
                player_data.side = ((angle_delta > 0) and 1) or -1.0
            end
            local abs_delta = math.abs(angle_delta)
            local desync_scale = math.clamp(abs_delta / max_desync, 0.15, 1)
            player_data.resolve_yaw = player_data.side * max_desync * desync_scale
        else
            if math.abs(yaw_delta) > 30 then
                player_data.side = ((yaw_delta > 0) and 1) or -1.0
            end
            local abs_delta = math.abs(yaw_delta)
            local desync_scale = math.clamp(abs_delta / max_desync, 0.15, 1)
            player_data.resolve_yaw = player_data.side * max_desync * desync_scale
        end
    else
        if math.abs(yaw_delta) > 30 then
            player_data.side = ((yaw_delta > 0) and 1) or -1.0
        end
        local abs_delta = math.abs(yaw_delta)
        local desync_scale = math.clamp(abs_delta / max_desync, 0.15, 1)
        player_data.resolve_yaw = player_data.side * max_desync * desync_scale
    end
    player_data.last_resolve_yaw = player_data.resolve_yaw
    local is_defensive = ((record.in_defensive ~= nil) and record.in_defensive) or false
    apply_resolve_to_plist(player_idx, {force_body_yaw = (not is_defensive), yaw_value = player_data.resolve_yaw}) --1231231
    client.update_player_list()
    player_data.last_yaw = eye_angles_y
    player_data.last_simtime = sim_time
end

local function reset_resolver_settings()
    for player_idx in pairs(resolved_players) do
        if entity.is_enemy(player_idx) then
            apply_resolve_to_plist(player_idx, {force_body_yaw = false, yaw_value = 0})
        end
    end
    client.update_player_list()
end

local last_threat_player
local in_net_update = false
local function on_net_update_end()
    if in_net_update then return end
    in_net_update = true
    local local_player = entity.get_local_player()
    if (not local_player) or (not entity.is_alive(local_player)) then
        reset_resolver_settings()
        in_net_update = false
        return
    end
    local current_threat = client.current_threat()
    if current_threat ~= nil then
        last_threat_player = current_threat
    end
    if (not current_threat) or (not entity.is_alive(current_threat)) then
        if last_threat_player then
            apply_resolve_to_plist(last_threat_player, {force_body_yaw = false, yaw_value = 0})
        end
        in_net_update = false
        return
    end
    if entity.is_dormant(current_threat) then
        apply_resolve_to_plist(current_threat, {force_body_yaw = false, yaw_value = 0})
        in_net_update = false
        return
    end
    resolve_player(current_threat)
    in_net_update = false
end

local resolver_registered = false
local function on_resolver_toggle(control)
    local is_enabled = menu.enable:get() and control:get()
    if not is_enabled then
        clear_resolver_data()
        ref.reset_all:set(true)
    end
    if is_enabled then
        if not resolver_registered then
            client.set_event_callback("net_update_end", on_net_update_end)
            client.set_event_callback("round_prestart", clear_resolver_data)
            resolver_registered = true
        end
    else
        if resolver_registered then
            client.unset_event_callback("net_update_end", on_net_update_end)
            client.unset_event_callback("round_prestart", clear_resolver_data)
            resolver_registered = false
        end
    end
end

local predict_hooked = false

--[[
local function predict_cvars()
    cvar.cl_interpolate:set_int(0)
    cvar.cl_interp_ratio:set_int(1)
end

local function restore_predict_cvars()
    cvar.cl_interpolate:set_int(1)
    cvar.cl_interp_ratio:set_int(2)
end
]]

--[[
local function predict_cvars()
    cvar.cl_interpolate:set_int(0)
    cvar.cl_interp_ratio:set_int(1)
    cvar.cl_interp:set_float(0.0)
    -- cvar.cl_predict:set_float(1)
    -- cvar.cl_predictweapons:set_int(1)
    -- cvar.cl_lagcompensation:set_int(1)
end

local function restore_predict_cvars()
    cvar.cl_interpolate:set_int(1)
    cvar.cl_interp_ratio:set_int(2)
    cvar.cl_interp:set_float(0)
    -- cvar.cl_predict:set_float(1)
    -- cvar.cl_predictweapons:set_int(1)
    -- cvar.cl_lagcompensation:set_int(1)
end
]]

--[[
-- НАЧАЛО УЛУЧШЕННОГО ПРЕДИКТА (ENGINE PREDICTION: DEFAULT & EXPERIMENTAL)
local function predict_cvars()
    local mode = menu.misc.predict_mode:get()
    
    -- Общие улучшенные настройки предикта (Режим: Default)
    cvar.cl_interpolate:set_int(0)
    cvar.cl_interp_ratio:set_int(1)
    cvar.cl_interp:set_float(0.0)
    cvar.cl_predict:set_int(1)
    cvar.cl_predictweapons:set_int(1)
    cvar.cl_lagcompensation:set_int(1)
    
    -- Экспериментальные FFI/Cvar-настройки для уменьшения ограничений синхронизации
    if mode == "Experimental" then
        cvar.cl_pred_optimize:set_int(0)          -- Отключаем оптимизацию предикта (перерасчет каждый тик)
        cvar.sv_clockcorrection_msecs:set_int(0)   -- Минимизируем погрешность дрейфа тиков на клиенте до 0
    end
end

local function restore_predict_cvars()
    cvar.cl_interpolate:set_int(1)
    cvar.cl_interp_ratio:set_int(2)
    cvar.cl_interp:set_float(0.03125)
    cvar.cl_predict:set_int(1)
    cvar.cl_predictweapons:set_int(1)
    cvar.cl_lagcompensation:set_int(1)
    
    -- Возвращаем экспериментальные параметры к дефолтным значениям CS:GO
    cvar.cl_pred_optimize:set_int(2)
    cvar.sv_clockcorrection_msecs:set_int(30)
end
-- КОНЕЦ УЛУЧШЕННОГО ПРЕДИКТА (ENGINE PREDICTION)
]]

-- НАЧАЛО УЛУЧШЕННОГО ПРЕДИКТА (БЕЗОПАСНАЯ ВЕРСИЯ С ПРОВЕРКОЙ НАЛИЧИЯ CVAR)
local function safe_set_cvar(name, value, is_float)
    local cv = cvar[name]
    if cv then
        if is_float then
            cv:set_float(value)
        else
            cv:set_int(value)
        end
    end
end

local function predict_cvars()
    local mode = menu.misc.predict_mode:get()
    
    -- Общие улучшенные настройки предикта (Режим: Default)
    safe_set_cvar("cl_interpolate", 0)
    safe_set_cvar("cl_interp_ratio", 1)
    safe_set_cvar("cl_interp", 0, true)
    safe_set_cvar("cl_predict", 1)
    safe_set_cvar("cl_predictweapons", 1)
    safe_set_cvar("cl_lagcompensation", 1)
    
    -- Экспериментальные FFI/Cvar-настройки для уменьшения ограничений синхронизации
    if mode == "Experimental" then
        safe_set_cvar("cl_pred_optimize", 0)          -- Отключаем оптимизацию предикта (перерасчет каждый тик, если поддерживается)
        safe_set_cvar("sv_clockcorrection_msecs", 0)   -- Минимизируем погрешность дрейфа тиков на клиенте до 0
    end
end

local function restore_predict_cvars()
    safe_set_cvar("cl_interpolate", 1)
    safe_set_cvar("cl_interp_ratio", 2)
    safe_set_cvar("cl_interp", 0, true)
    safe_set_cvar("cl_predict", 1)
    safe_set_cvar("cl_predictweapons", 1)
    safe_set_cvar("cl_lagcompensation", 1)
    
    -- Возвращаем экспериментальные параметры к дефолтным значениям CS:GO
    safe_set_cvar("cl_pred_optimize", 2)
    safe_set_cvar("sv_clockcorrection_msecs", 30)
end
-- КОНЕЦ УЛУЧШЕННОГО ПРЕДИКТА (ENGINE PREDICTION)

local function predict_callback()
    if menu.misc.predict:get() then
        predict_cvars()
    end
end

local function on_predict_toggle()
    if not entity.get_local_player() then return end
    local enabled = menu.enable:get() and menu.misc.predict:get()
    if enabled then
        if not predict_hooked then
            client.set_event_callback("pre_render", predict_callback)
            predict_hooked = true
        end
    else
        if predict_hooked then
            client.unset_event_callback("pre_render", predict_callback)
            predict_hooked = false
        end
        restore_predict_cvars()
    end

end

local function aimtools_update()
    if not menu.misc.aimtools_enable:get() then 
        return 
    end
    
    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then 
        return 
    end
    
    local weapon_ent = entity.get_player_weapon(lp)
    if not weapon_ent then 
        return 
    end
    
    local weapon_idx = entity.get_prop(weapon_ent, "m_iItemDefinitionIndex")
    local weapon_name = csgo_weapons[weapon_idx] and csgo_weapons[weapon_idx].name or "Unknown"
    
    -- Автоматический выбор оружия в aimtools
    local current_weapon_selection = menu.misc.aimtools.weapon:get()
    local should_update_weapon = false
    
    if string.find(weapon_name, "Desert Eagle") and current_weapon_selection ~= "Desert Eagle" then
        menu.misc.aimtools.weapon:set("Desert Eagle")
        should_update_weapon = true
    elseif string.find(weapon_name, "SSG 08") and current_weapon_selection ~= "SSG 08" then
        menu.misc.aimtools.weapon:set("SSG 08")
        should_update_weapon = true
    elseif string.find(weapon_name, "AWP") and current_weapon_selection ~= "AWP" then
        menu.misc.aimtools.weapon:set("AWP")
        should_update_weapon = true
    end
    
    -- Если сменилось оружие, сбрасываем все настройки aimtools
    if should_update_weapon then
        local players = entity.get_players(true)
        for i = 1, #players do
            local player_index = players[i]
            if entity.is_alive(player_index) then
                plist.set(player_index, "Override Prefer safe point", "-")
                plist.set(player_index, "Override Prefer body aim", "-")
            end
        end
        
    end
    
    
    local players = entity.get_players(true)
    
    -- Определяем, какое оружие выбрано и получаем соответствующие настройки
    local selected_weapon = menu.misc.aimtools.weapon:get()
    local weapon_settings = nil
    
    if selected_weapon == "Desert Eagle" then
        weapon_settings = menu.misc.aimtools.deagle
    elseif selected_weapon == "SSG 08" then
        weapon_settings = menu.misc.aimtools.ssg08
    elseif selected_weapon == "AWP" then
        weapon_settings = menu.misc.aimtools.awp
    end
    
    if not weapon_settings then 
        return 
    end
    
    -- Проверяем, соответствует ли текущее оружие выбранному
    local is_weapon_selected = string.find(weapon_name, selected_weapon)
    if not is_weapon_selected then 
        for i = 1, #players do
            local player_index = players[i]
            if entity.is_alive(player_index) then
                plist.set(player_index, "Override Prefer safe point", "-")
                plist.set(player_index, "Override Prefer body aim", "-")
            end
        end
        return 
    end
    
    
    for i = 1, #players do
        local player_index = players[i]
        if not entity.is_alive(player_index) then 
            goto continue 
        end
        
        local enemy_health = entity.get_prop(player_index, "m_iHealth")
        local enemy_armor = entity.get_prop(player_index, "m_ArmorValue")
        local local_origin = vector(entity.get_prop(lp, "m_vecOrigin"))
        local enemy_origin = vector(entity.get_prop(player_index, "m_vecOrigin"))
        local distance = local_origin:dist(enemy_origin)
        
        local should_override = false
        
        local stomach_damage = calculate_damage_to_stomach(player_index)

        -- Mode 1: "If HP lower than X"
        if weapon_settings.mode1:get("If HP lower than X") then
            local hp_threshold = weapon_settings.ifhp:get()
            if enemy_health <= hp_threshold then
                should_override = true
            end
        end
        
        -- Mode 2: "If lethal"
        if weapon_settings.mode1:get("If lethal") then
            -- Добавляем проверку на минимальный урон
            if stomach_damage > 0 and enemy_health <= stomach_damage then
                should_override = true
            end
        end
    
        if should_override then
            -- Apply overrides based on mode2 selection
            if weapon_settings.mode2:get("Force Safe Point") then
                plist.set(player_index, "Override Prefer safe point", "Force")
            elseif weapon_settings.mode2:get("Prefer Safe Point") then
                plist.set(player_index, "Override Prefer safe point", "On")
            elseif weapon_settings.mode2:get("Force Body Aim") then
                plist.set(player_index, "Override Prefer body aim", "Force")
            elseif weapon_settings.mode2:get("Prefer Body Aim") then
                plist.set(player_index, "Override Prefer body aim", "On")
            end
        else
            -- Reset overrides if conditions not met
            plist.set(player_index, "Override Prefer safe point", "-")
            plist.set(player_index, "Override Prefer body aim", "-")
        end
        
        ::continue::
    end
end

-- client.set_event_callback("aim_fire", aim_fire)
-- client.set_event_callback("aim_miss", aim_miss)
-- client.set_event_callback("aim_hit", aim_hit)

client.set_event_callback("paint", aimtools_update)

menu.misc.resolver:set_callback(on_resolver_toggle, true)
menu.misc.predict:set_callback(on_predict_toggle, true)
menu.enable:set_callback(function()
    on_resolver_toggle(menu.misc.resolver)
    on_predict_toggle()
end)

client.set_event_callback('paint', function()
    if not menu.misc.resolver:get() or not entity.is_alive(entity.get_local_player()) then return end
    if not menu.misc.debug:get() then return end

    local screen_width, screen_height = client.screen_size()
    local center_y = screen_height / 3.2
    local y_offset = 0

    local players = entity.get_players(true)
    local target = client.current_threat()
    
    if target and entity.is_alive(target) then
        local body_yaw_newmethod_get_sda = string.format("%.0f", r_val(target))
        
        local desync_amount = adata.get_desync(2)
        
        for i = 1, #players do
            local player_index = players[i]
            if entity.is_alive(player_index) then      
                renderer.text(25, center_y + y_offset, 255, 255, 255, 255, 'b', 0, 'Desync new method: ' .. body_yaw_newmethod_get_sda .. '°')
                renderer.text(25, center_y + y_offset + 15, 255, 255, 255, 255, 'b', 0, 'Desync old method: ' .. desync_amount .. '°')
            end
        end
    end
end)

--для теста

client.set_event_callback("setup_command", function(cmd) 
    -- print(cvar.cl_interp:get_float())
end) 

-- Extrapolation System ported from 8_myfix v2.lua
local player_records = {}

local function get_lerp_time()
    local sv_minupdaterate = cvar.sv_minupdaterate
    local sv_maxupdaterate = cvar.sv_maxupdaterate
    local cl_updaterate = cvar.cl_updaterate
    local cl_interp_ratio = cvar.cl_interp_ratio
    local cl_interp = cvar.cl_interp

    if not sv_minupdaterate or not sv_maxupdaterate or not cl_updaterate or not cl_interp_ratio or not cl_interp then
        return 0.03125
    end

    local ur = math.max(sv_minupdaterate:get_float(), math.min(sv_maxupdaterate:get_float(), cl_updaterate:get_float()))
    local ratio = cl_interp_ratio:get_float()
    if ratio == 0 then ratio = 1 end
    return math.max(cl_interp:get_float(), ratio / ur)
end

local function store_records()
    if not menu.misc.extrap_enable:get() then return end
    local players = entity.get_players(true)
    if not players then return end
    local max_stored = menu.misc.extrap_record_window:get() * 2
    for i = 1, #players do
        local ply = players[i]
        if entity.is_alive(ply) and not entity.is_dormant(ply) then
            if not player_records[ply] then
                player_records[ply] = { simtimes = {}, positions = {}, velocities = {} }
            end
            local rec = player_records[ply]
            local st = entity.get_prop(ply, "m_flSimulationTime")
            local ox, oy, oz = entity.get_prop(ply, "m_vecOrigin")
            local pos = vector(ox or 0, oy or 0, oz or 0)

            table.insert(rec.simtimes, 1, st)
            table.insert(rec.positions, 1, pos)

            local vx, vy, vz = entity.get_prop(ply, "m_vecVelocity")
            local vel = vector(vx or 0, vy or 0, vz or 0)
            table.insert(rec.velocities, 1, vel)

            while #rec.simtimes > max_stored do table.remove(rec.simtimes) end
            while #rec.positions > max_stored do table.remove(rec.positions) end
            while #rec.velocities > max_stored do table.remove(rec.velocities) end
        end
    end
end

local function rescue_records()
    if not menu.misc.extrap_enable:get() then return end
    local players = entity.get_players(true)
    if not players then return end
    local lerp = get_lerp_time()
    local sv_maxunlag = cvar.sv_maxunlag
    local max_ul = sv_maxunlag and sv_maxunlag:get_float() or 0.2
    local curtime = globals.curtime()

    for i = 1, #players do
        local ply = players[i]
        if entity.is_alive(ply) and not entity.is_dormant(ply) then
            local st = entity.get_prop(ply, "m_flSimulationTime")
            if st then
                local correct = math.min(math.max(0, st + lerp), curtime)

                if math.abs(correct - curtime) > max_ul then
                    local rec = player_records[ply]
                    if rec then
                        for _, saved_st in ipairs(rec.simtimes) do
                            local sc = math.min(math.max(0, saved_st + lerp), curtime)
                            if math.abs(sc - curtime) <= max_ul then
                                entity.set_prop(ply, "m_flSimulationTime", saved_st)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

local EXTRAP_REDUCE = { ["No reduction"] = 0, ["Reduce by 1"] = 1, ["Reduce by 2"] = 2 }

local function get_extrap_ticks()
    local base = menu.misc.extrap_ticks:get()
    local reduce = EXTRAP_REDUCE[menu.misc.extrap_tick_adjust:get()] or 0
    return math.max(0, base - reduce)
end

local function extrapolate_origin(ply)
    if not menu.misc.extrap_enable:get() then return end
    local ticks = get_extrap_ticks()
    if ticks <= 0 then return end

    local rec = player_records[ply]
    if not rec or not rec.velocities or #rec.velocities < 1 then return end

    local vel = rec.velocities[1]
    if not vel then return end

    local flags = entity.get_prop(ply, "m_fFlags") or 0
    local on_ground = bit.band(flags, 1) ~= 0

    local vx, vy, vz = vel.x, vel.y, vel.z
    if menu.misc.extrap_zero_z:get() or on_ground then vz = 0 end

    local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
    if speed < 1 then return end

    if menu.misc.extrap_disable_interp:get() and #rec.positions >= 2 then
        local p1, p2 = rec.positions[1], rec.positions[2]
        if p1 and p2 then
            vx = p1.x - p2.x
            vy = p1.y - p2.y
            vz = (menu.misc.extrap_zero_z:get() or on_ground) and 0 or (p1.z - p2.z)
        end
    else
        local tickinterval = globals.tickinterval()
        vx = vx * tickinterval
        vy = vy * tickinterval
        vz = vz * tickinterval
    end

    local origin_x, origin_y, origin_z = entity.get_prop(ply, "m_vecOrigin")
    if not origin_x then return end

    entity.set_prop(ply, "m_vecOrigin", origin_x + vx * ticks, origin_y + vy * ticks, origin_z + vz * ticks)
end

client.set_event_callback("net_update_end", function()
    if menu.enable:get() and menu.misc.extrap_enable:get() then
        if menu.misc.extrap_preserve_valid:get() then
            store_records()
        end
    end
end)

client.set_event_callback("setup_command", function(cmd)
    if menu.enable:get() and menu.misc.extrap_enable:get() then
        if menu.misc.extrap_preserve_valid:get() then
            rescue_records()
        end
        local players = entity.get_players(true)
        if players then
            for i = 1, #players do
                local ply = players[i]
                if entity.is_alive(ply) and not entity.is_dormant(ply) then
                    extrapolate_origin(ply)
                end
            end
        end
    end
end)

client.set_event_callback("round_start", function()
    player_records = {}
end) 
