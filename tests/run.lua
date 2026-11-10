-- Lua 5.1-compatible mocked Windower smoke/regression tests for Test3.
package.path = './?.lua;' .. package.path
local core = require('telllevel_core')
local assertions = 0
local function eq(actual, expected, label)
    assertions = assertions + 1
    if actual ~= expected then
        error((label or 'assertion') .. ': expected ' .. tostring(expected)
            .. ', got ' .. tostring(actual), 2)
    end
end
local function check(test, label)
    eq(not not test, true, label)
end

-- Pure naming coverage including name clipping and omitted suffixes.
eq(core.name('Goblin', 'A', 32, 'full', false, true), 'Goblin Lv32', 'default formatting')
eq(core.name('Goblin', 'A', 32, 'full', true, true), 'Goblin A Lv32', 'letters optional')
eq(core.name('Goblin', 'B', 99, 'compact', false, true), 'Goblin [99]', 'compact no letters')
eq(core.name('Goblin', 'B', 99, 'compact', true, true), 'Goblin B [99]', 'compact letters')
eq(core.name('Goblin', 'C', 110, 'level', true, true), 'Goblin Lv110', 'level override')
eq(core.name('Goblin', 'A', 32, 'letters', true, true), 'Goblin A', 'letters only')
eq(core.name('Goblin', 'A', nil, 'full', false, true), 'Goblin', 'unknown level')
eq(core.name('Goblin', 'A', nil, 'full', true, true), 'Goblin A', 'unknown level with letters')
eq(core.name('Goblin', 'A', 32, 'full', false, false), 'Goblin', 'levels disabled')
eq(core.name('Goblin', 'A', 32, 'full', true, false), 'Goblin A', 'levels off letters on')
eq(core.name('Goblin', 'A', 32, 'full', false, true):find('Lv%.', 1), nil, 'no dot in level')
local long_name = core.name('Very Long Goblin Enemy', 'B', 123, 'full', true, true)
check(#long_name <= 23, '23-byte max native name')
check(long_name:sub(-7) == 'B Lv123', 'level suffix retained')
local identities = core.build_names({[10]='Goblin', [4]='Goblin', [11]='Crab'})
eq(identities[4].letter, 'A', 'stable letter A')
eq(identities[10].letter, 'B', 'stable letter B')
eq(identities[11].letter, nil, 'singleton no letter')
eq(core.check_level({Message = 170, ['Param 1']=32}), 32, 'check level accepted')
eq(core.check_level({Message = 249, ['Param 1']=32}), nil, 'impossible gauge ignored')

local function session(overrides, do_login)
    local events, names, saved, chatlines, commands = {}, {}, {}, {}, {}
    local name_writes, discovery_sweeps = 0, 0
    local settings
    local mobs = {
      [4] = {id=2004, index=4, name='Goblin', spawn_type=16},
      [10] = {id=2010, index=10, name='Goblin', spawn_type=16},
      [11] = {id=2011, index=11, name='Crab', spawn_type=16},
    }
    local logged_in = true
    local zone = 100
    _addon = {}
    windower = {
        add_to_chat = function(color, message) chatlines[#chatlines+1] = message end,
        set_mob_name = function(id, name)
            name_writes = name_writes + 1
            names[id] = name
        end,
        send_command = function(command) commands[#commands+1] = command end,
        register_event = function(name, fn)
            events[name] = events[name] or {}
            table.insert(events[name], fn)
        end,
        ffxi = {
            get_info = function() return {logged_in=logged_in, zone=zone} end,
            get_mob_list = function() return {[4]='Goblin',[10]='Goblin',[11]='Crab'} end,
            get_mob_by_index = function(index) return mobs[index] end,
            get_mob_array = function()
                discovery_sweeps = discovery_sweeps + 1
                return mobs
            end,
            get_mob_by_target = function(tag)
                if tag == 'st' or tag == 't' then return mobs[4] end
                return nil
            end,
        },
    }
    local packet_parser = function(direction, packet) return packet end
    package.loaded['packets'] = nil
    package.preload['packets'] = function()
        return {
          new=function(direction,id,fields) return {id=id, fields=fields} end,
          inject=function(packet) return true end,
          parse=packet_parser,
        }
    end
    package.loaded['config'] = nil
    package.preload['config'] = function()
        return {
          load=function(defaults)
              settings={}
              for k,v in pairs(defaults) do settings[k]=v end
              for k,v in pairs(overrides or {}) do settings[k]=v end
              return settings
          end,
          save=function(value)
              local snapshot={}
              for k,v in pairs(value) do snapshot[k]=v end
              saved[#saved+1]=snapshot
          end,
        }
    end
    package.loaded['chat'] = nil
    package.preload['chat'] = function() return {} end
    coroutine.schedule = function(fn, delay) end -- auto-check is off by default
    dofile('TellLevel.lua')
    local function emit(name, ...)
        for _, handler in ipairs(events[name] or {}) do handler(...) end
    end
    local function frame()
        for _=1,26 do emit('prerender') end
    end
    if do_login then
        logged_in = false
        emit('load')
        eq(#saved, 0, 'no migration before login')
        logged_in = true
        emit('login')
    else
        emit('load')
    end
    frame()
    return {
        settings=settings, mobs=mobs, events=events, names=names, saved=saved,
        frame=frame, emit=emit,
        name_writes=function() return name_writes end,
        discovery_sweeps=function() return discovery_sweeps end,
        command=function(...) emit('addon command', ...) end,
        chats=chatlines,
    }
end

local first = session()
eq(first.settings.format, 'full', 'new format full')
eq(first.settings.letters, false, 'new default no letters')
eq(first.settings.levels, true, 'new default levels on')
eq(first.settings.nameplate_defaults_version, 2, 'migration marker installed new user')
eq(first.names[2004], nil, 'unknown-level monster stays unchanged')
first.emit('incoming chunk', 0x029, {['Target Index']=4, Target=2004, Message=170, ['Param 1']=32}, nil, false, false)
first.frame()
eq(first.names[2004], 'Goblin Lv32', 'incoming check updates no-letter nameplate')
-- Simulate FFXI restoring the original name on an entity movement update.
-- A single prerender must repair it, not leave it flickering for up to 12 frames.
first.names[2004] = 'Goblin'
local sweeps_before = first.discovery_sweeps()
local writes_before = first.name_writes()
first.emit('prerender')
eq(first.names[2004], 'Goblin Lv32', 'movement rename repaired on next frame')
check(first.name_writes() > writes_before, 'movement refresh reapplied native name')
eq(first.discovery_sweeps(), sweeps_before, 'fast repaint does not repeat discovery')

first.emit('incoming chunk', 0x0F4, {Index=10, Level=34, Type='Enemy'}, nil, false, false)
first.frame()
eq(first.names[2010], 'Goblin Lv34', 'incoming Wide Scan updates no-letter nameplate')
first.command('letters', 'on')
first.frame()
eq(first.names[2004], 'Goblin A Lv32', 'letters on updates first monster')
eq(first.names[2010], 'Goblin B Lv34', 'letters on updates second monster')
first.command('letters', 'off')
first.frame()
eq(first.names[2004], 'Goblin Lv32', 'letters off restores no-letter form')
first.command('format', 'level')
first.command('letters', 'on')
first.frame()
eq(first.names[2004], 'Goblin Lv32', 'level override ignores letters')
first.command('format', 'full')
first.frame()
eq(first.names[2004], 'Goblin A Lv32', 'full format restores optional letters')
first.command('letters', 'off')
first.command('unload')
eq(first.names[2004], 'Goblin', 'unload restores original')

local previous = session({format='full',letters=true,nameplate_defaults_version=1})
eq(previous.settings.letters, false, 'Test1 original default migrated')
eq(previous.settings.nameplate_defaults_version, 2, 'Test1 marker advanced')
eq(previous.saved[#previous.saved].letters, false, 'migration persisted')
local custom = session({format='compact',letters=true,nameplate_defaults_version=1})
eq(custom.settings.letters, true, 'Test1 custom style preserved')
eq(custom.settings.format, 'compact', 'Test1 compact preserved')
custom.command('letters', 'off')
eq(custom.saved[#custom.saved].letters, false, 'manual toggle persisted')
local later = session({format='full',letters=true,nameplate_defaults_version=2})
eq(later.settings.letters, true, 'explicit user re-enable remains on after migration')
local login = session({format='full',letters=true,nameplate_defaults_version=1}, true)
eq(login.settings.letters, false, 'startup before login later migrates')

print(('TellLevel Test3: PASS (%d assertions, pure rules and mocked Windower integration)'):format(assertions))
