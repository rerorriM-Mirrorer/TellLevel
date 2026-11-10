_addon.name = 'TellLevel'
_addon.author = 'A collaboration (based on Tellapart by Lili)'
_addon.version = '0.1.2-test3'
_addon.commands = {'telllevel', 'tl'}

-- This is a standalone replacement for Tellapart, NOT something to load beside it.
-- Monster identity is the server ID; zone index supplies a deterministic letter.
local packets = require('packets')
local config = require('config')
require('chat')
require('coroutine')
local core = require('telllevel_core')

local defaults = {
    format = 'full',
    letters = false, -- Levels only until the user explicitly opts into spawn letters.
    nameplate_defaults_version = 1, -- Migration marker for settings saved by Test1.
    levels = true,
    mask = true,
    autoscan = true,
    scan_interval = 300,
    autocheck = false,
    check_delay = 0.7,
    debug = false,
}
local settings = config.load(defaults)

local function migrate_nameplate_defaults()
    -- Test1 persisted letters=true and format=full. The new source default
    -- alone cannot override that XML value, so migrate only the original
    -- Test1 default combination. Other saved formats are preserved.
    -- A user who explicitly chose that identical combination in Test1 is
    -- indistinguishable from the old default; they can use //tl letters on.
    local info = windower.ffxi.get_info()
    if not info or not info.logged_in then return end
    if (tonumber(settings.nameplate_defaults_version) or 1) >= 2 then return end
    if settings.format == 'full' and settings.letters == true then
        settings.letters = false
    end
    settings.nameplate_defaults_version = 2
    config.save(settings)
end

-- Tellapart's original safe-zone list. Keep combat-bearing cities enabled.
local city_list = {70,247,256,249,244,234,245,257,246,248,230,53,236,233,223,
    238,235,226,239,240,232,250,231,284,242,26,252,280,285,225,224,
    237,50,241,243,71}
local cities = {}
for _, zone in ipairs(city_list) do cities[zone] = true end

local known_names = {} -- zone index -> original name + deterministic letter
local visible = {}     -- server ID -> { index, base, letter, last_name }
local levels = {}      -- zone index -> { id, value, expires, source }
local active, current_zone = false, nil
local last_scan, last_scan_attempt = 0, 0
local frame_counter, last_discovery = 0, 0
local last_target_id, target_generation = nil, 0
local last_auto_check = {} -- server ID -> last /check request time
local scan_count = 0
local scans_received = 0
local last_prepare_attempt = 0

local function say(message, color)
    windower.add_to_chat(color or 207, 'TellLevel: ' .. message)
end

local function debug_log(message)
    if settings.debug then say(message, 160) end
end

local function is_enemy(mob)
    return mob and mob.id and mob.id ~= 0 and mob.index
        and mob.spawn_type == 0x010
end

local function is_logged_in()
    local info = windower.ffxi.get_info()
    return info and info.logged_in and info.zone and not cities[info.zone]
end

local function get_level(mob)
    if not is_enemy(mob) then return nil end
    local cached = levels[mob.index]
    if not cached then return nil end
    if cached.expires <= os.time() or (cached.id and cached.id ~= mob.id) then
        levels[mob.index] = nil
        return nil
    end
    -- A widescan result can precede loading the actual entity. Bind it only
    -- while that unbound result is very fresh; do not recycle an older spawn.
    if cached.id == nil then cached.id = mob.id end
    return cached.value
end

local function get_name_info(mob)
    local entry = known_names[mob.index]
    if entry then return entry end
    -- Fallback for a spawn absent from the zone DAT name list. Capture once.
    return {base = mob.name or '', letter = nil}
end

local function remember_monster(mob)
    if not is_enemy(mob) or not active then return end
    local existing = visible[mob.id]
    if existing and existing.index == mob.index then return end
    local entry = get_name_info(mob)
    visible[mob.id] = { index = mob.index, base = entry.base, letter = entry.letter }
    debug_log(('registered index %d, ID %d (%s)'):format(mob.index, mob.id, entry.base))
end

local function record_level(index, value, source, expected_id)
    value = tonumber(value)
    if type(index) ~= 'number' or index < 1 or not core.valid_level(value) then return end
    local mob = windower.ffxi.get_mob_by_index(index)
    if is_enemy(mob) and (not expected_id or mob.id == expected_id) then
        levels[index] = {id = mob.id, value = value, expires = os.time() + 600, source = source}
        remember_monster(mob)
        debug_log(('%s: %s index %d level %d'):format(source, mob.name or '?', index, value))
    elseif not expected_id then
        -- Widescan can arrive before the mob is rendered. Only retain for 20s.
        levels[index] = {id = nil, value = value, expires = os.time() + 20, source = source}
    end
end

local function scan_names()
    if not is_logged_in() then return end
    local zone = windower.ffxi.get_info().zone
    if current_zone == zone and active then return end
    local raw_names = windower.ffxi.get_mob_list() or {}
    last_prepare_attempt = os.time()
    -- Login events can arrive before the zone DAT name table is ready.
    -- Never latch an empty table as the definitive list for this zone.
    if next(raw_names) == nil then return end
    current_zone = zone
    known_names = core.build_names(raw_names)
    visible = {}
    levels = {}
    last_scan, last_scan_attempt = 0, 0
    last_target_id, target_generation = nil, target_generation + 1
    active = true
    for index in pairs(known_names) do
        remember_monster(windower.ffxi.get_mob_by_index(index))
    end
    debug_log(('zone %d: naming table built'):format(zone))
end

local function restore_names()
    for id, entry in pairs(visible) do
        local mob = windower.ffxi.get_mob_by_index(entry.index)
        if mob and mob.id == id and entry.applied and entry.base ~= '' then
            windower.set_mob_name(id, entry.base)
        end
    end
end

local function clear_zone()
    -- On zoning, old IDs may already be invalid; never write to the new zone.
    known_names, visible, levels, last_auto_check = {}, {}, {}, {}
    active, current_zone = false, nil
    last_target_id, target_generation = nil, target_generation + 1
    last_scan, last_scan_attempt, last_prepare_attempt = 0, 0, 0
end

local function scan(force)
    if not active or not is_logged_in() then return false end
    local now = os.time()
    -- Even manually triggered requests have a 5s safety floor.
    if now - last_scan_attempt < (force and 5 or 30) then return false end
    last_scan_attempt = now
    local ok, result = pcall(function()
        return packets.inject(packets.new('outgoing', 0x0F4,
            {Flags = 1, ['_unknown1'] = 0, ['_unknown2'] = 0}))
    end)
    if not ok or result == false then
        debug_log('widescan request failed: ' .. tostring(result))
        return false
    end
    last_scan, scan_count = now, scan_count + 1
    debug_log('widescan requested')
    return true
end

local function current_target()
    local mob = windower.ffxi.get_mob_by_target('st') or windower.ffxi.get_mob_by_target('t')
    return is_enemy(mob) and mob or nil
end

local function observe_target()
    local mob = current_target()
    local id = mob and mob.id or nil
    if mob then remember_monster(mob) end
    if id == last_target_id then return end
    last_target_id = id
    target_generation = target_generation + 1
    if mob and settings.autoscan and settings.levels and not get_level(mob) then
        -- New unknown target: request a refresh, subject to the 30s scan floor.
        scan(false)
    end
    if not mob or not settings.autocheck or not settings.levels or get_level(mob) then return end
    local index, generation = mob.index, target_generation
    local delay = math.max(0.3, math.min(3, tonumber(settings.check_delay) or 0.7))
    coroutine.schedule(function()
        if not active or not settings.autocheck or generation ~= target_generation then return end
        local current = current_target()
        if not current or current.id ~= id or current.index ~= index or get_level(current) then return end
        local now = os.time()
        if (last_auto_check[id] or 0) + 30 > now then return end
        last_auto_check[id] = now
        -- Send through the game's normal /check command; no forged /check packets.
        windower.send_command('input /check <t>')
        debug_log('auto-/check sent for ID ' .. id)
    end, delay)
end

local function render_frame()
    if not active then
        if is_logged_in() and os.time() - last_prepare_attempt >= 5 then
            scan_names()
            if active and settings.autoscan then scan(false) end
        end
        if not active then return end
    end
    -- FFXI can restore a mob's original name whenever the server updates its
    -- position. Tellapart reapplies native names on every prerender for this
    -- reason. Do the same, while keeping the more expensive target discovery
    -- and Wide Scan scheduling on the previous 12-frame cadence.
    frame_counter = frame_counter + 1
    local maintenance_frame = frame_counter % 12 == 1
    if maintenance_frame then
        observe_target()

        -- A slower discovery sweep recovers monsters missed by spawn packets.
        local now = os.time()
        if now - last_discovery >= 5 then
            last_discovery = now
            local arr = windower.ffxi.get_mob_array()
            if arr then
                for _, mob in pairs(arr) do remember_monster(mob) end
            end
        end
    end

    for id, entry in pairs(visible) do
        local mob = windower.ffxi.get_mob_by_index(entry.index)
        if not is_enemy(mob) or mob.id ~= id then
            visible[id] = nil
        else
            local name = core.name(entry.base, entry.letter, get_level(mob),
                settings.format, settings.letters, settings.levels)
            if name ~= '' and (name ~= entry.base or entry.applied) then
                -- Game updates can overwrite renamed mobs. Never rewrite an
                -- unmodified singleton; reset a renamed mob just once.
                windower.set_mob_name(id, name)
                entry.applied = name ~= entry.base
            end
        end
    end
    if maintenance_frame and settings.autoscan and settings.levels
        and os.time() - last_scan >= settings.scan_interval then
        scan(false)
    end
end

local function observe_packet(id, original, _, injected, blocked)
    if not active or blocked or injected then return end
    if id == 0x0F4 then
        local success, packet = pcall(packets.parse, 'incoming', original)
        if not success or not packet then return end
        local index = tonumber(packet['Index'])
        local level = tonumber(packet['Level'])
        local kind = packet['Type']
        if index and core.valid_level(level) then
            -- Only treat widescan observations as levels for actual enemies.
            -- Non-rendered mobs may be bound during a subsequent spawn event.
            local mob = windower.ffxi.get_mob_by_index(index)
            if is_enemy(mob) or (not mob and (kind == 'Enemy' or kind == 2)) then
                record_level(index, level, 'widescan')
                scans_received = scans_received + 1
            end
        end
    elseif id == 0x029 then
        local success, packet = pcall(packets.parse, 'incoming', original)
        if not success or not packet then return end
        local value = core.check_level(packet)
        local index = tonumber(packet['Target Index'])
        local expected_id = tonumber(packet['Target'])
        if value and index and expected_id and expected_id > 0 then
            record_level(index, value, '/check', expected_id)
        end
    elseif id == 0x0F5 then
        local success, packet = pcall(packets.parse, 'incoming', original)
        if not success or not packet then return end
        local status = packet['Status']
        if status == 'Update' or status == 1 then
            record_level(tonumber(packet['Index']), packet['Level'], 'widescan tracking')
        end
    elseif id == 0x00E then
        -- Monster appearance; name changes and early level packets can race.
        local index = original:unpack('H', 0x009)
        if index then remember_monster(windower.ffxi.get_mob_by_index(index)) end
    end
end

local function help()
    local lines = {
        {'//tl help', 'show these commands'},
        {'//tl status', 'report settings and cached target level'},
        {'//tl scan', 'request Wide Scan (5s minimum between requests)'},
        {'//tl format <full|compact|level|letters>', 'choose native name style'},
        {'//tl letters [on|off]', 'show deterministic A/B/C suffixes'},
        {'//tl levels [on|off]', 'show exact levels when known'},
        {'//tl mask [on|off]', 'use original names for <t> in chat'},
        {'//tl autoscan [on|off]', 'request background Wide Scans'},
        {'//tl interval <60-3600>', 'seconds between Wide Scans'},
        {'//tl autocheck [on|off]', '/check a newly selected mob after 0.7s'},
        {'//tl debug [on|off]', 'report packet and targeting decisions'},
        {'//tl clear', 'forget cached levels and request a new scan'},
        {'//tl reload', 'reload addon without explicit unload'},
        {'//tl restart', 'unload then load the addon'},
        {'//tl unload', 'restore names and unload'},
    }
    windower.add_to_chat(0, ('TellLevel v' .. _addon.version):color(167))
    for _, line in ipairs(lines) do
        windower.add_to_chat(0, ('  '):color(140) .. line[1]:color(207)
            .. (' -> '):color(200) .. line[2]:color(0))
    end
end

local function status()
    local total, known = 0, 0
    for _ in pairs(visible) do total = total + 1 end
    for _, entry in pairs(levels) do if entry.expires > os.time() then known = known + 1 end end
    local target = current_target()
    local target_info = target and ('; target ' .. (known_names[target.index]
        and known_names[target.index].base or target.name or '?')
        .. ' level ' .. tostring(get_level(target) or '?')) or ''
    say(('v%s | %s | format=%s letters=%s levels=%s mask=%s | autoscan=%s (%ds) autocheck=%s | visible=%d cached=%d scans=%d packets=%d%s')
        :format(_addon.version, active and 'active' or 'inactive', settings.format,
            tostring(settings.letters), tostring(settings.levels), tostring(settings.mask),
            tostring(settings.autoscan), settings.scan_interval, tostring(settings.autocheck),
            total, known, scan_count, scans_received, target_info))
end

local function toggle_setting(key, argument)
    local current = settings[key]
    local value
    if not argument or argument == '' then value = not current
    elseif argument == 'on' then value = true
    elseif argument == 'off' then value = false
    else say('Expected on or off.'); return end
    settings[key] = value
    config.save(settings)
    say(key .. '=' .. tostring(value))
    if key == 'autoscan' and value then scan(false) end
    if key == 'autocheck' then last_target_id = nil end
end

local handlers = {
    help = help, status = status,
    scan = function() say(scan(true) and 'Wide Scan requested.' or
        'Wide Scan unavailable or requested too recently.') end,
    format = function(value)
        if value ~= 'full' and value ~= 'compact' and value ~= 'level' and value ~= 'letters' then
            say('Use format full, compact, level, or letters.'); return
        end
        settings.format = value
        config.save(settings)
        say('format=' .. value)
    end,
    letters = function(value) toggle_setting('letters', value) end,
    levels = function(value) toggle_setting('levels', value) end,
    mask = function(value) toggle_setting('mask', value) end,
    autoscan = function(value) toggle_setting('autoscan', value) end,
    autocheck = function(value) toggle_setting('autocheck', value) end,
    debug = function(value) toggle_setting('debug', value) end,
    interval = function(value)
        local seconds = tonumber(value)
        if not seconds or seconds ~= math.floor(seconds) or seconds < 60 or seconds > 3600 then
            say('Use interval <60-3600> in whole seconds.'); return
        end
        settings.scan_interval = seconds
        config.save(settings)
        say('scan_interval=' .. seconds .. 's')
    end,
    clear = function()
        levels = {}
        say('Level cache cleared.')
        scan(true)
    end,
    reload = function() windower.send_command('lua reload TellLevel') end,
    restart = function()
        restore_names()
        windower.send_command('lua unload TellLevel; wait 1; lua load TellLevel')
    end,
    unload = function()
        restore_names()
        windower.send_command('lua unload TellLevel')
    end,
}

windower.register_event('load', function()
    migrate_nameplate_defaults()
    scan_names()
    if active and settings.autoscan then scan(false) end
end)
windower.register_event('login', function() migrate_nameplate_defaults(); scan_names() end)
windower.register_event('zone change', clear_zone)
windower.register_event('outgoing chunk', function(id)
    if id == 0x00C then scan_names() end
end)
windower.register_event('incoming chunk', observe_packet)
windower.register_event('prerender', render_frame)
windower.register_event('outgoing text', function(_, text, blocked)
    if blocked or not active or not settings.mask or not core.is_chat_command(text)
        or not text:find('<t>', 1, true) then return end
    local mob = windower.ffxi.get_mob_by_target('t')
    if not is_enemy(mob) then return end
    local entry = known_names[mob.index] or visible[mob.id]
    if not entry or not entry.base then return end
    return text:gsub('<t>', function() return entry.base end)
end)
windower.register_event('addon command', function(...)
    local args = {...}
    local command = type(args[1]) == 'string' and args[1]:lower() or 'help'
    local handler = handlers[command]
    if not handler then say('Unknown command: ' .. tostring(command)); help(); return end
    handler(type(args[2]) == 'string' and args[2]:lower() or nil)
end)
windower.register_event('unload', function() restore_names() end)
