-- TellLevel's pure, runtime-independent rules (Lua 5.1 compatible).
-- The native monster-name buffer is limited to 23 visible bytes.
local M = {}

local MAX_NAME_BYTES = 23
local FORMATS = { full = true, compact = true, level = true, letters = true }

function M.letter(number)
    local result = ''
    while number > 0 do
        local digit = (number - 1) % 26
        result = string.char(65 + digit) .. result
        number = math.floor((number - 1) / 26)
    end
    return result
end

function M.build_names(mob_list)
    -- Sorting by index makes A/B/C assignments independent of pairs() order.
    local by_name, result = {}, {}
    for index, name in pairs(mob_list or {}) do
        if type(index) == 'number' and type(name) == 'string' and #name > 0 then
            by_name[name] = by_name[name] or {}
            table.insert(by_name[name], index)
        end
    end
    for name, indexes in pairs(by_name) do
        table.sort(indexes)
        for order, index in ipairs(indexes) do
            result[index] = {
                base = name,
                letter = #indexes > 1 and M.letter(order) or nil,
            }
        end
    end
    return result
end

function M.valid_level(level)
    return type(level) == 'number' and level >= 1 and level <= 255
        and level == math.floor(level)
end

function M.check_level(packet)
    -- A normal /check sends action message 170..178; Param 1 is the real level.
    -- Reject arbitrary action messages even when Param 1 resembles a level.
    if not packet then return nil end
    local message = tonumber(packet['Message'])
    if not message then return nil end
    message = message % 0x4000
    local value = tonumber(packet['Param 1'])
    if message >= 170 and message <= 178 and M.valid_level(value) then
        return value
    end
    return nil
end

function M.name(base, letter, level, format, use_letters, use_levels)
    format = FORMATS[format] and format or 'full'
    base = type(base) == 'string' and base or ''
    local letter_suffix = (use_letters and letter and format ~= 'level') and (' ' .. letter) or ''
    local level_suffix = ''
    if use_levels and M.valid_level(level) and format ~= 'letters' then
        if format == 'compact' then
            level_suffix = ' [' .. level .. ']'
        else
            level_suffix = ' Lv' .. level
        end
    end
    local suffix = letter_suffix .. level_suffix
    if suffix == '' then return base end -- Leave unchanged originals untouched.
    local max_base = math.max(1, MAX_NAME_BYTES - #suffix)
    return base:sub(1, max_base):gsub('%s+$', '') .. suffix
end

function M.is_chat_command(command)
    if type(command) ~= 'string' then return false end
    local verb = command:match('^%s*/([%a]+)')
    if not verb then return false end
    verb = verb:lower()
    return ({ s=true, say=true, p=true, party=true, a=true, alliance=true,
        l=true, linkshell=true, l2=true, tell=true, t=true, sh=true,
        shout=true, y=true, yell=true, em=true, emote=true })[verb] == true
end

return M
