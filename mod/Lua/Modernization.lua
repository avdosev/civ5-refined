-- Stock projects persist in the team record (one civilization per team in
-- the supported single-player setup). Benefits follow the current owner.
local function id(name)
    return assert(GameInfoTypes[name], 'Refined modernization: missing ' .. name)
end

local droneTech = id('TECH_REFINED_DRONES')
local automationTech = id('TECH_REFINED_AUTOMATION')
local dataCenter = id('BUILDING_REFINED_DATA_CENTER')
local steelMill = id('BUILDING_REFINED_STEEL_MILL')
local steelBonus = id('BUILDING_REFINED_AUTOMATION_STEEL')
local droneProject = id('PROJECT_REFINED_DRONE_DEPLOYMENT')
local commandProject = id('PROJECT_REFINED_AUTONOMOUS_COMMAND')
local heritageProject = id('PROJECT_REFINED_DIGITAL_HERITAGE')
local expansionProject = id('PROJECT_REFINED_CULTURAL_EXPANSION')
local creativityProject = id('PROJECT_REFINED_MACHINE_CREATIVITY')
local dronePromotion = id('PROMOTION_REFINED_DRONES')
local deploymentPromotion = id('PROMOTION_REFINED_DRONE_DEPLOYMENT')
local commandPromotion = id('PROMOTION_REFINED_AUTONOMOUS_COMMAND')

local projects = {}
for row in GameInfo.Refined_NationalProjects() do
    projects[id(row.Type)] = {tech = id(row.Tech), needsDataCenter = row.NeedsDataCenter == 1}
end

local tourismCarriers = {}
local maxTourism = 0
for row in GameInfo.Refined_TourismCarriers() do
    tourismCarriers[#tourismCarriers + 1] = {building = id(row.Type), weight = row.Weight}
    maxTourism = maxTourism + row.Weight
end

local save = Modding.OpenSaveData()
local creativityBonuses = {}

local function major(player)
    return player and player:IsAlive() and not player:IsMinorCiv() and not player:IsBarbarian()
end

local function canCreate(playerID, cityID, projectID)
    local project = projects[projectID]
    if not project then return true end
    local player = Players[playerID]
    if not major(player) then return false end
    local city = player:GetCityByID(cityID)
    if not city then return false end
    local team = Teams[player:GetTeam()]
    return team:IsHasTech(project.tech) and team:GetProjectCount(projectID) == 0
        and (not project.needsDataCenter or city:GetNumBuilding(dataCenter) > 0)
end

local function setBuilding(city, building, wanted)
    local count = wanted and 1 or 0
    if city:GetNumRealBuilding(building) ~= count then city:SetNumRealBuilding(building, count) end
end

local function setPromotion(unit, promotion, wanted)
    if unit:IsHasPromotion(promotion) ~= wanted then unit:SetHasPromotion(promotion, wanted) end
end

local function syncUnit(unit, drones, deployment, command)
    if not unit then return end
    local info = GameInfo.Units[unit:GetUnitType()]
    local combat = (info.Combat > 0 or info.RangedCombat > 0)
        and (not info.NukeDamageLevel or info.NukeDamageLevel < 0)
    local land = combat and info.Domain == 'DOMAIN_LAND'
    setPromotion(unit, dronePromotion, land and drones)
    setPromotion(unit, deploymentPromotion, land and deployment)
    setPromotion(unit, commandPromotion, combat and command)
end

local function syncCreativity(playerID, player)
    local key = 'refined.modernization.creativity.' .. playerID
    local previous = creativityBonuses[playerID]
    if previous == nil then
        previous = save.GetValue(key) or 0
        creativityBonuses[playerID] = previous
    end
    -- Add to the native empire-wide culture subtotal. Exclude our previous
    -- contribution and let BNW apply temporary boosts and Golden Ages once.
    local base = player:GetJONSCulturePerTurnFromCities()
        + player:GetJONSCulturePerTurnFromExcessHappiness()
        + player:GetJONSCulturePerTurnFromTraits()
        + player:GetJONSCulturePerTurnForFree() - previous
        + player:GetCulturePerTurnFromMinorCivs()
        + player:GetCulturePerTurnFromReligion()
    local bonus = math.floor(math.max(0, base) / 5)
    if bonus ~= previous then
        creativityBonuses[playerID] = bonus
        player:ChangeJONSCulturePerTurnForFree(bonus - previous)
        save.SetValue(key, bonus)
    end
end

local function syncCity(city, automate, heritage, expansion)
    setBuilding(city, steelBonus, automate and city:GetNumBuilding(steelMill) > 0)
    local tourism = expansion
    if heritage then tourism = tourism + city:GetNumGreatWorks() end
    tourism = math.min(tourism, maxTourism)
    for _, carrier in ipairs(tourismCarriers) do
        local enabled = math.floor(tourism / carrier.weight) % 2 == 1
        setBuilding(city, carrier.building, enabled)
    end
end

local armyStates = {}
local function syncArmy(playerID, player, force)
    local team = major(player) and Teams[player:GetTeam()]
    local drones = team and team:IsHasTech(droneTech) or false
    local deployment = team and team:GetProjectCount(droneProject) > 0 or false
    local command = team and team:GetProjectCount(commandProject) > 0 or false
    local previous = armyStates[playerID]
    if force or not previous or previous[1] ~= drones or previous[2] ~= deployment or previous[3] ~= command then
        armyStates[playerID] = {drones, deployment, command}
        for unit in player:Units() do syncUnit(unit, drones, deployment, command) end
    end
end
local syncing, pending = false, true
local function syncPlayer(playerID, forceArmy)
    local player = Players[playerID]
    if not player or not player:IsAlive() then return end
    if not major(player) then
        syncArmy(playerID, player, forceArmy)
        return
    end
    local team = Teams[player:GetTeam()]
    local automate = team:IsHasTech(automationTech)
    local heritage = team:GetProjectCount(heritageProject) > 0
    if team:GetProjectCount(creativityProject) > 0 then syncCreativity(playerID, player) end
    local expansion = 0
    if team:GetProjectCount(expansionProject) > 0 then
        expansion = math.floor(math.max(0, player:GetTotalJONSCulturePerTurn()) * 15 / 100)
    end
    local capital = player:GetCapitalCity()
    local tourismCity = capital and not capital:IsResistance() and not capital:IsRazing() and capital:GetID()
    if not tourismCity and expansion > 0 then
        for city in player:Cities() do
            if not city:IsResistance() and not city:IsRazing() then
                tourismCity = city:GetID()
                break
            end
        end
    end
    for city in player:Cities() do
        syncCity(city, automate, heritage, city:GetID() == tourismCity and expansion or 0)
    end

    syncArmy(playerID, player, forceArmy)
end

local function markDirty()
    if not syncing then pending = true end
end

local function syncAll()
    if syncing then return end
    syncing, pending = true, false
    for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do syncPlayer(playerID, true) end
    syncing = false
end

include("RefinedEventBus")
include("RefinedModernizationEvents")
local events = RefinedEventBus.Create()

local function syncOne(playerID, forceArmy)
    if syncing then return end
    syncing = true
    syncPlayer(playerID, forceArmy)
    syncing = false
end
events:Answer('CanCreateProject', canCreate)
events:Subscribe('PlayerTurn', function(playerID) syncOne(playerID, true) end)
events:Subscribe('TeamTechnologyChanged', function(teamID, techID)
    if syncing or (techID ~= droneTech and techID ~= automationTech) then return end
    syncing = true
    for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
        local player = Players[playerID]
        if player and player:GetTeam() == teamID then syncPlayer(playerID, false) end
    end
    syncing = false
end)
events:Subscribe('CityFounded', function(playerID) syncOne(playerID, false) end)
events:Subscribe('CityCaptured', syncAll)
events:Subscribe('UnitPositionChanged', function(playerID, unitID)
    local player = Players[playerID]
    if not player or not player:IsAlive() then return end
    local unit = player:GetUnitByID(unitID)
    if not major(player) then
        syncUnit(unit, false, false, false)
        return
    end
    local team = Teams[player:GetTeam()]
    syncUnit(unit, team:IsHasTech(droneTech),
        team:GetProjectCount(droneProject) > 0, team:GetProjectCount(commandProject) > 0)
end)
events:Subscribe('CityInfoChanged', markDirty)
events:Subscribe('GameInitialized', syncAll)
local elapsed = 0
events:Subscribe('Update', function(delta)
    elapsed = elapsed + delta
    if pending and elapsed >= 0.25 then
        elapsed = 0
        if not syncing then
            syncing, pending = true, false
            for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do syncPlayer(playerID, false) end
            syncing = false
        end
    end
end)
events:Subscribe('Loaded', syncAll)
RefinedModernizationEvents.Connect(events)
print('civ5-refined: modernization projects loaded')
