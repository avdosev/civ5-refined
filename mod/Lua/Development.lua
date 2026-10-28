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
for row in GameInfo.Buildings() do buildingClasses[row.ID] = row.BuildingClass end
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
local function syncPlots()
    local counts = {}
    for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do counts[playerID] = {} end
    for index = 0, Map.GetNumPlots() - 1 do
        local plot = Map.GetPlotByIndex(index)
        local owner = plot:GetOwner()
        local player = Players[owner]
        local bonus = 0
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
            elseif imp == boats and resource == fish and team:IsHasTech(refrigeration) then
                bonus = 1
            end
            local c = counts[owner]
            if c then
                if imp == mine then
                    c.mine = (c.mine or 0) + 1
                    if resource == iron then c.mineIron = 1 end
                    if resource == coal then c.mineCoal = 1 end
                    if resource == uranium then c.mineUranium = 1 end
                elseif imp == quarry then c.quarry = 1
                elseif imp == pasture and resource == horses then c.pastureHorse = 1 end
            end
        end
        local k = 'plot.' .. index .. '.food'
        local old = get(k) or 0
        if old ~= bonus then
            put(k, bonus)
            Game.SetPlotExtraYield(plot:GetX(), plot:GetY(), food, bonus - old)
        end
    end
    return counts
end

local function playerCounts(player, tileCounts)
    local counts = tileCounts or {}
    for city in player:Cities() do
        local seen = {}
        for building, class in pairs(buildingClasses) do
            if not seen[class] and city:GetNumBuilding(building) > 0 then
                seen[class] = true
                counts[class] = (counts[class] or 0) + 1
            end
        end
    end
    for unit in player:Units() do
        local class = GameInfo.Units[unit:GetUnitType()].Class
        if class == 'UNITCLASS_WRITER' or class == 'UNITCLASS_SCIENTIST' or
           class == 'UNITCLASS_MUSKETMAN' then
            counts[class] = (counts[class] or 0) + 1
        end
    end
    local destinations = {}
    for _, route in ipairs(player:GetTradeRoutes()) do
        if route.ToID ~= route.FromID and route.ToCity then
            destinations[route.ToID .. ':' .. route.ToCity:GetID()] = true
        end
    end
    counts.trade = 0
    for _ in pairs(destinations) do counts.trade = counts.trade + 1 end
    return counts
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
local function syncAll()
    if syncing then return end
    syncing = true
    pending = false
    local tiles = syncPlots()
    for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
        local player = Players[playerID]
        if activePlayer(player) then
            local counts = playerCounts(player, tiles[playerID])
            local teamID = player:GetTeam()
            local team = Teams[teamID]
            for _, rule in ipairs(rules) do
                local k = key(teamID, rule.TechType)
                if not team:IsHasTech(rule.techID) and not get(k .. '.achieved') and
                   (counts[rule.Rule] or 0) >= rule.Threshold then
                    put(k .. '.achieved', 1)
                end
            end
        end
    end
    -- A completed tech may unlock another pending eureka. Iterate to a fixed point
    -- so grants do not depend on row order or another UI event/turn.
    local changed = true
    while changed do
        changed = false
        for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
            local player = Players[playerID]
            if activePlayer(player) then
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
        if activePlayer(player) then
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
    syncing = false
end
local function markDirty() if not syncing then pending = true end end

-- Native UnitSetXY fires during unit creation, including AI and Great People.
-- Scan immediately: a Great Person may be expended before the next turn.
local function rememberGreatPerson(playerID, unitID)
    local player = Players[playerID]
    if not activePlayer(player) then return end
    local unit = player:GetUnitByID(unitID)
    if not unit then return end
    local class = GameInfo.Units[unit:GetUnitType()].Class
    local target = class == 'UNITCLASS_WRITER' and 'TECH_PRINTING_PRESS' or
                   class == 'UNITCLASS_SCIENTIST' and 'TECH_SCIENTIFIC_THEORY'
    if target then
        local k = key(player:GetTeam(), target) .. '.achieved'
        if not Teams[player:GetTeam()]:IsHasTech(id(target)) and not get(k) then
            put(k, 1)
        end
    end
    markDirty()
end
GameEvents.UnitSetXY.Add(rememberGreatPerson)
GameEvents.PlayerDoTurn.Add(syncAll)
GameEvents.TeamSetHasTech.Add(syncAll)
GameEvents.PlayerCityFounded.Add(markDirty)
GameEvents.CityCaptureComplete.Add(syncAll)
Events.SerialEventCityInfoDirty.Add(markDirty)
Events.SerialEventUnitInfoDirty.Add(markDirty)
Events.SerialEventImprovementCreated.Add(markDirty)
Events.SerialEventImprovementDestroyed.Add(markDirty)
Events.SerialEventHexCultureChanged.Add(markDirty)
Events.SequenceGameInitComplete.Add(syncAll)

-- Coalesce dirty UI events; never rescan the map once for every city carrier write.
local elapsed = 0
ContextPtr:SetUpdate(function(delta)
    elapsed = elapsed + delta
    if pending and elapsed >= 0.2 then elapsed = 0; syncAll() end
end)
syncAll()
print('civ5-refined v6: agriculture, fishing and 19 persistent eurekas loaded')
