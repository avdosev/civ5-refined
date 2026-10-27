-- Behavioral checks in Lua 5.1 with a small BNW API stand-in.
-- This exercises the actual shipped script, not a translated implementation.
local function event()
    local handlers = {}
    return {
        Add = function(fn) handlers[#handlers + 1] = fn end,
        Fire = function(...) for _, fn in ipairs(handlers) do fn(...) end end
    }
end
GameEvents = {}
for _, name in ipairs({'PlayerDoTurn', 'TeamSetHasTech', 'PlayerCityFounded', 'CityCaptureComplete'}) do
    GameEvents[name] = event()
end
Events = {SerialEventCityInfoDirty = event(), SequenceGameInitComplete = event()}
GameDefines = {MAX_CIV_PLAYERS = 4}
GameInfoTypes = {}
local nextID = 0
local function register(name)
    nextID = nextID + 1
    GameInfoTypes[name] = nextID
    return nextID
end
for _, name in ipairs({'TECH_PRINTING_PRESS', 'BUILDING_REFINED_PRINTING_CULTURE', 'TECH_COMPUTERS', 'TECH_REFINED_NETWORKS', 'TECH_REFINED_AI',
    'TECH_REFINED_MICROELECTRONICS', 'TECH_REFINED_AUTOMATION',
    'BUILDING_REFINED_MICRO_DATA_CENTER', 'BUILDING_REFINED_AUTOMATION_FACTORY',
    'BUILDING_REFINED_DATA_CENTER', 'BUILDING_REFINED_COMPUTER_UNIVERSITY',
    'BUILDING_REFINED_COMPUTER_LAB', 'BUILDING_REFINED_NETWORK_GOLD',
    'BUILDING_REFINED_AI_DATA_CENTER', 'BUILDING_REFINED_AI_FACTORY', 'BUILDING_REFINED_AI_LAB'}) do
    register(name)
end
local buildings = {}
for _, row in ipairs({
    {'BUILDING_LIBRARY', 'BUILDINGCLASS_LIBRARY'},
    {'BUILDING_PAPER_MAKER', 'BUILDINGCLASS_LIBRARY'},
    {'BUILDING_UNIVERSITY', 'BUILDINGCLASS_UNIVERSITY'},
    {'BUILDING_WAT', 'BUILDINGCLASS_UNIVERSITY'},
    {'BUILDING_LABORATORY', 'BUILDINGCLASS_LABORATORY'},
    {'BUILDING_STOCK_EXCHANGE', 'BUILDINGCLASS_STOCK_EXCHANGE'},
    {'BUILDING_FACTORY', 'BUILDINGCLASS_FACTORY'},
}) do
    buildings[#buildings + 1] = {ID = register(row[1]), BuildingClass = row[2]}
end
GameInfo = {Buildings = function(filter)
    local index = 0
    return function()
        repeat index = index + 1 until not buildings[index] or buildings[index].BuildingClass == filter.BuildingClass
        return buildings[index]
    end
end}
local writes = 0
local function city(initial)
    local c = {real = {}, free = {}}
    for _, name in ipairs(initial or {}) do c.real[GameInfoTypes[name]] = 1 end
    function c:GetNumRealBuilding(id) return self.real[id] or 0 end
    function c:GetNumBuilding(id) return (self.real[id] or 0) + (self.free[id] or 0) end
    function c:SetNumRealBuilding(id, count)
        self.real[id] = count
        writes = writes + 1
        Events.SerialEventCityInfoDirty.Fire() -- exercise reentrant notifications
    end
    return c
end
local function player(teamID, cities)
    local p = {teamID = teamID, cities = cities, alive = true}
    function p:IsAlive() return self.alive end
    function p:GetTeam() return self.teamID end
    function p:Cities()
        local index = 0
        return function() index = index + 1; return self.cities[index] end
    end
    return p
end
local function team()
    return {techs = {}, IsHasTech = function(self, id) return self.techs[id] or false end}
end
Teams = {[0] = team(), [1] = team()}
local capital = city({'BUILDING_WAT', 'BUILDING_LABORATORY', 'BUILDING_STOCK_EXCHANGE',
                      'BUILDING_FACTORY', 'BUILDING_REFINED_DATA_CENTER'})
local aiCity = city({'BUILDING_UNIVERSITY', 'BUILDING_REFINED_DATA_CENTER'})
Players = {[0] = player(0, {capital}), [1] = player(1, {aiCity}), [2] = player(0, {})}
local function expect(c, name, count)
    assert(c:GetNumRealBuilding(GameInfoTypes[name]) == count, name .. ': unexpected count')
end
local function acquire(teamID, name)
    Teams[teamID].techs[GameInfoTypes[name]] = true
    GameEvents.TeamSetHasTech.Fire(teamID, GameInfoTypes[name], true)
end
dofile('mod/Lua/Refined.lua')
assert(writes == 0, 'no unearned bonuses at game start')
acquire(0, 'TECH_COMPUTERS')
expect(capital, 'BUILDING_REFINED_COMPUTER_UNIVERSITY', 1) -- unique replacement
expect(capital, 'BUILDING_REFINED_COMPUTER_LAB', 1)
expect(aiCity, 'BUILDING_REFINED_COMPUTER_UNIVERSITY', 0)
acquire(0, 'TECH_REFINED_NETWORKS')
expect(capital, 'BUILDING_REFINED_NETWORK_GOLD', 1)
acquire(0, 'TECH_REFINED_MICROELECTRONICS')
acquire(0, 'TECH_REFINED_AUTOMATION')
expect(capital, 'BUILDING_REFINED_MICRO_DATA_CENTER', 1)
expect(capital, 'BUILDING_REFINED_AUTOMATION_FACTORY', 1)
expect(aiCity, 'BUILDING_REFINED_MICRO_DATA_CENTER', 0)
acquire(0, 'TECH_REFINED_AI')
for _, name in ipairs({'BUILDING_REFINED_AI_DATA_CENTER', 'BUILDING_REFINED_AI_FACTORY', 'BUILDING_REFINED_AI_LAB'}) do
    expect(capital, name, 1)
end
local previousWrites = writes
for _ = 1, 10 do GameEvents.PlayerDoTurn.Fire(0) end
assert(writes == previousWrites, 'repeat events must not stack or rewrite bonuses')

-- Saved game/late start: already known techs must apply at script initialization.
capital.real[GameInfoTypes.BUILDING_REFINED_AI_LAB] = 0
dofile('mod/Lua/Refined.lua')
expect(capital, 'BUILDING_REFINED_AI_LAB', 1)

local founded = city()
Players[2].cities = {founded} -- allied player shares technology
GameEvents.PlayerCityFounded.Fire(2, 0, 0)
expect(founded, 'BUILDING_REFINED_AI_DATA_CENTER', 0)
founded.real[GameInfoTypes.BUILDING_REFINED_DATA_CENTER] = 1
Events.SerialEventCityInfoDirty.Fire()
expect(founded, 'BUILDING_REFINED_AI_DATA_CENTER', 1)
expect(founded, 'BUILDING_REFINED_MICRO_DATA_CENTER', 1)

-- Sell a source building; its effect must disappear immediately on dirty event.
capital.real[GameInfoTypes.BUILDING_FACTORY] = 0
capital.real[GameInfoTypes.BUILDING_LABORATORY] = 0
Events.SerialEventCityInfoDirty.Fire()
expect(capital, 'BUILDING_REFINED_AI_FACTORY', 0)
expect(capital, 'BUILDING_REFINED_AUTOMATION_FACTORY', 0)
expect(capital, 'BUILDING_REFINED_AI_LAB', 0)
expect(capital, 'BUILDING_REFINED_COMPUTER_LAB', 0)

-- Capture with surviving hidden buildings: new owner's techs determine bonuses.
Players[0].cities = {}
Players[1].cities[#Players[1].cities + 1] = capital
GameEvents.CityCaptureComplete.Fire(0, false, 0, 0, 1, true)
expect(capital, 'BUILDING_REFINED_COMPUTER_UNIVERSITY', 0)
expect(capital, 'BUILDING_REFINED_NETWORK_GOLD', 0)
expect(capital, 'BUILDING_REFINED_MICRO_DATA_CENTER', 0)
expect(capital, 'BUILDING_REFINED_AI_DATA_CENTER', 0)
acquire(1, 'TECH_COMPUTERS')
expect(aiCity, 'BUILDING_REFINED_COMPUTER_UNIVERSITY', 1) -- AI receives the same rules
expect(capital, 'BUILDING_REFINED_COMPUTER_UNIVERSITY', 1)
aiCity.real[GameInfoTypes.BUILDING_UNIVERSITY] = 0
aiCity.free[GameInfoTypes.BUILDING_UNIVERSITY] = 1
GameEvents.PlayerDoTurn.Fire(1)
expect(aiCity, 'BUILDING_REFINED_COMPUTER_UNIVERSITY', 1)
Teams[1].techs[GameInfoTypes.TECH_COMPUTERS] = false
GameEvents.TeamSetHasTech.Fire(1, GameInfoTypes.TECH_COMPUTERS, false)
expect(aiCity, 'BUILDING_REFINED_COMPUTER_UNIVERSITY', 0)
print('PASS: Lua lifecycle, shared teams, AI, replacements, free buildings and idempotence')

-- Printing Press applies to library replacements, survives reload and is removed
-- on sale/capture. The hidden building's exact +4 culture is checked in SQL.
aiCity.real[GameInfoTypes.BUILDING_PAPER_MAKER] = 1
acquire(1, 'TECH_PRINTING_PRESS')
expect(aiCity, 'BUILDING_REFINED_PRINTING_CULTURE', 1)
local beforePrinting = writes
GameEvents.PlayerDoTurn.Fire(1)
assert(writes == beforePrinting)
aiCity.real[GameInfoTypes.BUILDING_PAPER_MAKER] = 0
Events.SerialEventCityInfoDirty.Fire()
expect(aiCity, 'BUILDING_REFINED_PRINTING_CULTURE', 0)
print('PASS: Printing Press culture follows library classes and removal')
