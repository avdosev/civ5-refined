-- Dispatcher contracts and the existing BNW trigger surface, without game state.
function include(name)
    if name == 'FLuaVector' then ToGridFromHex = function(x,y) return x+10,y+20 end
    else dofile('mod/Lua/' .. name .. '.lua') end
end
include('RefinedEventBus')
local first, second = RefinedEventBus.Create(), RefinedEventBus.Create()
local trace = {}
first:Subscribe('Inner', function(value) trace[#trace+1] = value end)
first:Subscribe('Outer', function(a,b,c)
    assert(a == 7 and b == nil and c == false)
    trace[#trace+1] = 'before'
    first:Publish('Inner', 'inner')
    trace[#trace+1] = 'after'
end)
first:Subscribe('Outer', function() trace[#trace+1] = 'second' end)
second:Subscribe('Outer', function() error('contexts must be isolated') end)
first:Publish('Outer', 7, nil, false)
assert(table.concat(trace, ',') == 'before,inner,after,second', 'synchronous order/reentrancy')
first:Publish('Unobserved')
first:Answer('Allowed', function(a,b,c)
    assert(a == 7 and b == nil and c == false)
    return false, 'reason', nil, 9
end)
local allowed, reason, empty, last = first:Query('Allowed', 7, nil, false)
assert(allowed == false and reason == 'reason' and empty == nil and last == 9)
assert(not pcall(function() first:Answer('Allowed', function() end) end), 'duplicate query handler')
assert(not pcall(function() first:Query('Missing') end), 'missing query handler')
first:Subscribe('Failure', function() error('visible failure') end)
assert(not pcall(function() first:Publish('Failure') end), 'do not swallow handler errors')

-- Contract for scoped sources: unit UI dirtiness no longer schedules sweeps.
local contracts = {
    City = {
        'G.PlayerDoTurn:PlayerTurn', 'G.TeamSetHasTech:TeamTechnologyChanged',
        'G.PlayerCityFounded:CityFounded', 'G.CityCaptureComplete:CityCaptured',
        'E.SerialEventCityInfoDirty:CityInfoChanged', 'E.SequenceGameInitComplete:GameInitialized'},
    Development = {
        'G.UnitSetXY:UnitPositionChanged', 'G.PlayerDoTurn:PlayerTurn',
        'G.TeamSetHasTech:TeamTechnologyChanged', 'G.PlayerCityFounded:CityFounded',
        'G.CityCaptureComplete:CityCaptured', 'E.SerialEventCityInfoDirty:CityInfoChanged',
        'E.SequenceGameInitComplete:GameInitialized', 'G.BuildFinished:PlotChanged',
        'E.SerialEventImprovementCreated:PlotChanged', 'E.SerialEventImprovementDestroyed:PlotChanged',
        'E.SerialEventHexCultureChanged:PlotChanged'},
    Society = {
        'G.PlayerCityFounded:CityFounded', 'G.PlayerDoTurn:PlayerTurn',
        'G.TeamSetHasTech:TeamTechnologyChanged', 'G.TeamTechResearched:TeamTechnologyResearched',
        'G.CityCaptureComplete:CityCaptured', 'G.PlayerAdoptPolicy:PolicyAdopted',
        'G.UnitSetXY:UnitPositionChanged', 'G.SetAlly:AllianceChanged',
        'E.WarStateChanged:WarStateChanged', 'E.SerialEventCityInfoDirty:CityInfoChanged',
        'E.SequenceGameInitComplete:GameInitialized'},
    Victories = {
        'G.CityCanConstruct:CanConstructBuilding', 'G.CityCanCreate:CanCreateProject',
        'G.CityCanMaintain:CanMaintainProcess', 'G.PlayerDoTurn:PlayerTurn',
        'G.TeamSetHasTech:TeamTechnologyChanged', 'G.PlayerCityFounded:CityFounded',
        'G.CityCaptureComplete:CityCaptured', 'G.UnitSetXY:UnitPositionChanged',
        'E.SerialEventCityInfoDirty:CityInfoChanged',
        'E.SerialEventGameDataDirty:GameDataChanged', 'E.SequenceGameInitComplete:GameInitialized',
        'E.SerialEventEnterCityScreen:CityScreenEntered', 'E.SerialEventExitCityScreen:CityScreenExited',
        'E.GameplaySetActivePlayer:ActivePlayerChanged'},
    Modernization = {
        'G.CityCanCreate:CanCreateProject', 'G.PlayerDoTurn:PlayerTurn',
        'G.TeamSetHasTech:TeamTechnologyChanged', 'G.PlayerCityFounded:CityFounded',
        'G.CityCaptureComplete:CityCaptured', 'G.UnitSetXY:UnitPositionChanged',
        'E.SerialEventCityInfoDirty:CityInfoChanged', 'E.SequenceGameInitComplete:GameInitialized'}
}
for module, contract in pairs(contracts) do
    local connected, emitted, loaded, updated = {}, {}, 0, 0
    local function sources(prefix)
        return setmetatable({}, {__index = function(t, name)
            local handlers = {}
            local source = {
                Add = function(handler)
                    connected[#connected+1] = prefix .. '.' .. name
                    handlers[#handlers+1] = handler
                end,
                Fire = function(...)
                    assert(#handlers == 1, 'one bridge per source')
                    return handlers[1](...)
                end
            }
            rawset(t, name, source)
            return source
        end})
    end
    GameEvents, Events = sources('G'), sources('E')
    local update
    ContextPtr = {SetUpdate = function(_, callback) assert(not update); update = callback end}
    local bus = RefinedEventBus.Create()
    bus:Subscribe('Loaded', function() loaded = loaded+1 end)
    bus:Subscribe('Update', function(delta) assert(delta == .125); updated = updated+1 end)
    local subscribed = {}
    for _, binding in ipairs(contract) do
        local group, source, name = binding:match('^(%a)%.(%w+):(%w+)$')
        local function handler(a,b,c)
            if name == 'PlotChanged' then assert(a == 17 and b == 22 and c == nil)
            else assert(a == 7 and b == nil and c == false, 'exact argument forwarding') end
            emitted[#emitted+1] = name
            return false
        end
        if not subscribed[name] then
            if source:sub(1,7) == 'CityCan' then bus:Answer(name, handler)
            else bus:Subscribe(name, handler) end
            subscribed[name] = true
        end
    end
    include('Refined' .. module .. 'Events')
    _G['Refined' .. module .. 'Events'].Connect(bus)
    assert(loaded == 1 and #emitted == 0, 'initialization after connecting sources')
    assert(#connected == #contract, 'same number of native bindings')
    for index, binding in ipairs(contract) do
        local group, source, name = binding:match('^(%a)%.(%w+):(%w+)$')
        assert(connected[index] == group .. '.' .. source, 'same binding order')
        local fire = (group == 'G' and GameEvents or Events)[source].Fire
        local result
        if source == 'BuildFinished' then result = fire(0,17,22,-1)
        elseif name == 'PlotChanged' then result = fire(7,2)
        else result = fire(7,nil,false) end
        assert(emitted[index] == name, 'correct event translation')
        if source:sub(1,7) == 'CityCan' then assert(result == false, 'native query result') end
    end
    if module == 'City' then assert(not update, 'city effects have no update timer')
    else update(.125); assert(updated == 1) end
end
print('PASS: event dispatch order, isolation, reentrancy, nil/false arguments, query returns and all five BNW source contracts')
