-- v6 single-player BNW: tile yields, persistent team eurekas and achievement messages.
-- Save keys use stable Type strings, never database numeric IDs.
local save = Modding.OpenSaveData()
local saved = {}
local function get(key)
    if saved[key] == nil then
        local value = save.GetValue('refined.v6.' .. key)
        saved[key] = value == nil and false or value
    end
    if saved[key] ~= false then return saved[key] end
end
local function put(key, value)
    saved[key] = value
    save.SetValue('refined.v6.' .. key, value)
end
local function id(name) return assert(GameInfoTypes[name], 'civ5-refined: missing ' .. name) end
local farm = id('IMPROVEMENT_FARM')
local mine = id('IMPROVEMENT_MINE')
local quarry = id('IMPROVEMENT_QUARRY')
local pasture = id('IMPROVEMENT_PASTURE')
local boats = id('IMPROVEMENT_FISHING_BOATS')
local fish = id('RESOURCE_FISH')
local horses = id('RESOURCE_HORSE')
local iron = id('RESOURCE_IRON')
local coal = id('RESOURCE_COAL')
local uranium = id('RESOURCE_URANIUM')
local food = id('YIELD_FOOD')
local agriculture = id('TECH_REFINED_AGRICULTURAL_MECHANIZATION')
local refrigeration = id('TECH_REFRIGERATION')
local rules = {}
for row in GameInfo.Refined_Eurekas() do
    rules[#rules + 1] = {TechType = row.TechType, Rule = row.Rule,
        Threshold = row.Threshold, techID = id(row.TechType)}
end
-- Stable order for deterministic chain awards.
table.sort(rules, function(a, b) return a.techID < b.techID end)
local buildingClasses = {}
local neededClasses = {}
for _, rule in ipairs(rules) do neededClasses[rule.Rule] = true end
for row in GameInfo.Buildings() do
    if neededClasses[row.BuildingClass] then buildingClasses[row.ID] = row.BuildingClass end
end
local function key(teamID, tech) return 'team.' .. teamID .. '.' .. tech end
local function activePlayer(player)
    return player and player:IsAlive() and not player:IsMinorCiv() and not player:IsBarbarian()
end
local function notify(playerID, tag, ...)
    local active = Game.GetActivePlayer()
    if active >= 0 and Players[active] and Players[active]:GetTeam() == Players[playerID]:GetTeam() then
        Events.GameplayAlertMessage(Locale.ConvertTextKey(tag, ...))
    end
end

-- SetPlotExtraYield ADDS a delta despite its name. Save our contribution, not the
-- tile total, so repeated events/reloads preserve unrelated map/scenario bonuses.
local tiles, contributions, plotIndices = {}, {}, {}
local function plotKey(plot) return plot:GetX() .. ':' .. plot:GetY() end
local function syncPlot(plot, index)
    local owner = plot:GetOwner()
    local player = Players[owner]
    local bonus, counts = 0, {}
    if player and player:IsAlive() and not plot:IsImprovementPillaged() then
        local team = Teams[player:GetTeam()]
        local imp = plot:GetImprovementType()
        local resource = plot:GetResourceType(player:GetTeam())
        if imp == farm and team:IsHasTech(agriculture) then
            local neighbors = 0
            for direction = 0, 5 do
                local adjacent = Map.PlotDirection(plot:GetX(), plot:GetY(), direction)
                if adjacent and adjacent:GetOwner() == owner and
                   adjacent:GetImprovementType() == farm and not adjacent:IsImprovementPillaged() then
                    neighbors = neighbors + 1
                end
            end
            bonus = math.max(0, neighbors - 1)
        elseif imp == boats and resource == fish and team:IsHasTech(refrigeration) then bonus = 1 end
        if imp == mine then
            counts.mine = 1
            if resource == iron then counts.mineIron = 1 end
            if resource == coal then counts.mineCoal = 1 end
            if resource == uranium then counts.mineUranium = 1 end
        elseif imp == quarry then counts.quarry = 1
        elseif imp == pasture and resource == horses then counts.pastureHorse = 1 end
    end
    local previous = contributions[index]
    if previous then
        for name, n in pairs(previous.counts) do
            tiles[previous.owner][name] = tiles[previous.owner][name] - n
        end
    end
    tiles[owner] = tiles[owner] or {}
    for name, n in pairs(counts) do tiles[owner][name] = (tiles[owner][name] or 0) + n end
    contributions[index] = {owner = owner, counts = counts}
    local k = 'plot.' .. index .. '.food'
    local old = get(k) or 0
    if old ~= bonus then
        put(k, bonus)
        Game.SetPlotExtraYield(plot:GetX(), plot:GetY(), food, bonus - old)
    end
end
local lastMapTurn
local function syncPlots()
    for index = 0, Map.GetNumPlots() - 1 do
        local plot = Map.GetPlotByIndex(index)
        plotIndices[plotKey(plot)] = index
        syncPlot(plot, index)
    end
    lastMapTurn = Game.GetGameTurn()
end
local function syncRegion(x, y)
    local plot = Map.GetPlot(x, y)
    local affected = {}
    if not plot then return affected end
    local function update(p)
        local index = p and plotIndices[plotKey(p)]
        if index then
            local previous = contributions[index]
            if previous then affected[previous.owner] = true end
            affected[p:GetOwner()] = true
            syncPlot(p, index)
        end
    end
    update(plot)
    for direction = 0, 5 do update(Map.PlotDirection(x, y, direction)) end
    return affected
end
local function buildingCounts(player)
    local counts = {}
    for city in player:Cities() do
        local seen = {}
        for building, class in pairs(buildingClasses) do
            if not seen[class] and city:GetNumBuilding(building) > 0 then
                seen[class] = true
                counts[class] = (counts[class] or 0) + 1
            end
        end
    end
    return counts
end
local function unitCounts(player)
    local counts = {}
    for unit in player:Units() do
        local class = GameInfo.Units[unit:GetUnitType()].Class
        if class == 'UNITCLASS_WRITER' or class == 'UNITCLASS_SCIENTIST' or class == 'UNITCLASS_MUSKETMAN' then
            counts[class] = (counts[class] or 0) + 1
        end
    end
    return counts
end
local function tradeCounts(player)
    local destinations = {}
    for _, route in ipairs(player:GetTradeRoutes()) do
        if route.ToID ~= route.FromID and route.ToCity then
            destinations[route.ToID .. ':' .. route.ToCity:GetID()] = true
        end
    end
    local count = 0
    for _ in pairs(destinations) do count = count + 1 end
    return {trade = count}
end

-- Player:GetResearchCost returns rounded-up whole beakers, whereas the native
-- completion threshold is in hundredths. Recover the integer city-count modifier
-- from that rounded value, using the SAME integer operations as CvTeamTechs.
-- This prevents a fractional overflow when a eureka completes a technology.
local function costTimes100(player, techID, teamTechs)
    local rounded = player:GetResearchCost(techID)
    local base = math.floor(teamTechs:GetResearchCost(techID) * 10000 /
                            math.max(1, player:CalculateResearchModifier(techID)))
    local cityMod = Game.GetNumCitiesTechCostMod()
    if cityMod == 0 then return base end
    local estimate = math.floor((rounded * 10000 / base - 100) / cityMod)
    local match
    for n = math.max(0, estimate - 2), estimate + 2 do
        local candidate = math.floor(base * (100 + cityMod * n) / 100)
        if math.ceil(candidate / 100) == rounded then
            if match and match ~= candidate then
                -- Never over-credit if an unusually cheap technology is ambiguous.
                return math.min(match, candidate)
            end
            match = candidate
        end
    end
    if match then return match end
    -- Conservative fallback for a nonstandard cost implementation. No overflow.
    print('civ5-refined: unrecognized research cost for ' .. techID)
    return math.max(1, rounded * 100 - 99)
end

local syncing, pending = false, false
local function achieve(player, counts)
    local teamID = player:GetTeam()
    for _, rule in ipairs(rules) do
        local k = key(teamID, rule.TechType)
        if not Teams[teamID]:IsHasTech(rule.techID) and not get(k .. '.achieved') and
           (counts[rule.Rule] or 0) >= rule.Threshold then put(k .. '.achieved', 1) end
    end
end
local function awardTeam(targetTeam)
    -- A completed tech may unlock another pending eureka. Iterate to a fixed point
    -- so grants do not depend on row order or another UI event/turn.
    local changed = true
    while changed do
        changed = false
        for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
            local player = Players[playerID]
            if activePlayer(player) and player:GetTeam() == targetTeam then
                local teamID = player:GetTeam()
                local team = Teams[teamID]
                local tt = team:GetTeamTechs()
                for _, rule in ipairs(rules) do
                    local k = key(teamID, rule.TechType)
                    if not team:IsHasTech(rule.techID) and not get(k .. '.awarded') and
                       get(k .. '.achieved') and player:CanResearch(rule.techID) then
                        local cost = costTimes100(player, rule.techID, tt)
                        local old = tt:GetResearchProgressTimes100(rule.techID)
                        local amount = math.min(math.floor(cost / 4), math.max(0, cost - old))
                        -- Persist BEFORE native research invokes TeamSetHasTech.
                        put(k .. '.awarded', 1)
                        tt:SetResearchProgressTimes100(rule.techID, old + amount, playerID)
                        notify(playerID, 'TXT_KEY_REFINED_EUREKA_NOTICE',
                               Locale.ConvertTextKey(GameInfo.Technologies[rule.techID].Description), amount / 100,
                               Locale.ConvertTextKey('TXT_KEY_REFINED_EUREKA_FLAVOR_' .. rule.TechType))
                        changed = true
                    end
                end
            end
        end
    end
    -- Announce pending breakthroughs only after all immediately available grants.
    -- This avoids two messages when the achievement and award happen together.
    for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
        local player = Players[playerID]
        if activePlayer(player) and player:GetTeam() == targetTeam then
            local teamID = player:GetTeam()
            for _, rule in ipairs(rules) do
                local k = key(teamID, rule.TechType)
                if get(k .. '.achieved') and not get(k .. '.awarded') and
                   not get(k .. '.notified') and not Teams[teamID]:IsHasTech(rule.techID) then
                    put(k .. '.notified', 1)
                    notify(playerID, 'TXT_KEY_REFINED_EUREKA_READY',
                           Locale.ConvertTextKey(GameInfo.Technologies[rule.techID].Description),
                           Locale.ConvertTextKey('TXT_KEY_REFINED_EUREKA_FLAVOR_' .. rule.TechType))
                end
            end
        end
    end
end
local function syncPlayer(playerID)
    local player = Players[playerID]
    if syncing or not activePlayer(player) then return end
    syncing = true
    -- UI plot notifications can miss changes outside human visibility. Reconcile
    -- once per game turn, not once per player and never because a unit moved.
    if lastMapTurn ~= Game.GetGameTurn() then syncPlots() end
    achieve(player, tiles[playerID] or {})
    achieve(player, buildingCounts(player))
    achieve(player, unitCounts(player))
    achieve(player, tradeCounts(player))
    awardTeam(player:GetTeam())
    syncing = false
end
local function syncAll()
    if syncing then return end
    syncing = true
    syncPlots()
    syncing = false
    for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do syncPlayer(playerID) end
end
local function syncBuildings()
    if syncing then return end
    syncing, pending = true, false
    for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
        local player = Players[playerID]
        if activePlayer(player) then achieve(player, buildingCounts(player)); awardTeam(player:GetTeam()) end
    end
    syncing = false
end
local function markDirty() if not syncing then pending = true end end
local function changedPlot(x, y)
    if syncing then return end
    syncing = true
    local affected = syncRegion(x, y)
    for playerID in pairs(affected) do
        local player = Players[playerID]
        if activePlayer(player) then achieve(player, tiles[playerID] or {}); awardTeam(player:GetTeam()) end
    end
    syncing = false
end
local function researched(teamID, techID, value)
    if syncing then return end
    if techID == agriculture or techID == refrigeration then
        syncing = true
        for index = 0, Map.GetNumPlots() - 1 do
            local plot = Map.GetPlotByIndex(index)
            local player = Players[plot:GetOwner()]
            if player and player:GetTeam() == teamID then syncPlot(plot, index) end
        end
        syncing = false
    end
    syncing = true
    awardTeam(teamID)
    syncing = false
end
-- Creation also emits UnitSetXY. Ordinary movement does no broad work. A
-- musket only counts its owner's units while its milestone is still pending.
local function changedUnit(playerID, unitID)
    local player = Players[playerID]
    if syncing or not activePlayer(player) then return end
    local unit = player:GetUnitByID(unitID)
    if not unit then return end
    local class = GameInfo.Units[unit:GetUnitType()].Class
    local target = class == 'UNITCLASS_WRITER' and 'TECH_PRINTING_PRESS' or
                   class == 'UNITCLASS_SCIENTIST' and 'TECH_SCIENTIFIC_THEORY' or
                   class == 'UNITCLASS_MUSKETMAN' and 'TECH_RIFLING'
    if not target then return end
    local k = key(player:GetTeam(), target) .. '.achieved'
    if Teams[player:GetTeam()]:IsHasTech(id(target)) or get(k) then return end
    syncing = true
    if class == 'UNITCLASS_MUSKETMAN' then achieve(player, unitCounts(player)) else put(k, 1) end
    awardTeam(player:GetTeam())
    syncing = false
end
include("RefinedEventBus")
include("RefinedDevelopmentEvents")
local events = RefinedEventBus.Create()
events:Subscribe('UnitPositionChanged', changedUnit)
events:Subscribe('PlayerTurn', syncPlayer)
events:Subscribe('TeamTechnologyChanged', researched)
events:Subscribe('CityFounded', syncAll)
events:Subscribe('CityCaptured', syncAll)
events:Subscribe('CityInfoChanged', markDirty)
events:Subscribe('PlotChanged', changedPlot)
events:Subscribe('GameInitialized', syncAll)
local elapsed = 0
events:Subscribe('Update', function(delta)
    elapsed = elapsed + delta
    if pending and elapsed >= 0.2 then elapsed = 0; syncBuildings() end
end)
events:Subscribe('Loaded', syncAll)
RefinedDevelopmentEvents.Connect(events)
print('civ5-refined: scoped development and persistent eurekas loaded')
