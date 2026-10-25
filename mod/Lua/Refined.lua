-- Standard BNW APIs only. No persistent counters: derive effects from current
-- team technologies and city buildings, including civilization replacements.
local function id(name)
    local value = GameInfoTypes[name]
    assert(value ~= nil, 'civ5-refined: missing database entry ' .. name)
    return value
end

local techComputers = id('TECH_COMPUTERS')
local techNetworks = id('TECH_REFINED_NETWORKS')
local techAI = id('TECH_REFINED_AI')
local techMicro = id('TECH_REFINED_MICROELECTRONICS')
local techAutomation = id('TECH_REFINED_AUTOMATION')
local dataCenter = id('BUILDING_REFINED_DATA_CENTER')

local function buildingsInClass(name)
    local result = {}
    for row in GameInfo.Buildings({BuildingClass = name}) do
        result[#result + 1] = row.ID
    end
    return result
end

local universities = buildingsInClass('BUILDINGCLASS_UNIVERSITY')
local laboratories = buildingsInClass('BUILDINGCLASS_LABORATORY')
local exchanges = buildingsInClass('BUILDINGCLASS_STOCK_EXCHANGE')
local factories = buildingsInClass('BUILDINGCLASS_FACTORY')
local effects = {
    computerUniversity = id('BUILDING_REFINED_COMPUTER_UNIVERSITY'),
    computerLab = id('BUILDING_REFINED_COMPUTER_LAB'),
    networkGold = id('BUILDING_REFINED_NETWORK_GOLD'),
    aiDataCenter = id('BUILDING_REFINED_AI_DATA_CENTER'),
    aiFactory = id('BUILDING_REFINED_AI_FACTORY'),
    aiLab = id('BUILDING_REFINED_AI_LAB'),
    microDataCenter = id('BUILDING_REFINED_MICRO_DATA_CENTER'),
    automationFactory = id('BUILDING_REFINED_AUTOMATION_FACTORY')
}

local function hasAny(city, buildings)
    for _, building in ipairs(buildings) do
        if city:GetNumBuilding(building) > 0 then return true end
    end
    return false
end

local function setEffect(city, building, enabled)
    local count = enabled and 1 or 0
    if city:GetNumRealBuilding(building) ~= count then
        city:SetNumRealBuilding(building, count)
    end
end

local function syncPlayer(playerID)
    local player = Players[playerID]
    if not player or not player:IsAlive() then return end
    local team = Teams[player:GetTeam()]
    local computers = team:IsHasTech(techComputers)
    local networks = team:IsHasTech(techNetworks)
    local ai = team:IsHasTech(techAI)
    local micro = team:IsHasTech(techMicro)
    local automation = team:IsHasTech(techAutomation)
    for city in player:Cities() do
        local lab = hasAny(city, laboratories)
        setEffect(city, effects.computerUniversity, computers and hasAny(city, universities))
        setEffect(city, effects.computerLab, computers and lab)
        setEffect(city, effects.networkGold, networks and hasAny(city, exchanges))
        setEffect(city, effects.aiDataCenter, ai and city:GetNumBuilding(dataCenter) > 0)
        setEffect(city, effects.aiFactory, ai and hasAny(city, factories))
        setEffect(city, effects.aiLab, ai and lab)
        setEffect(city, effects.microDataCenter, micro and city:GetNumBuilding(dataCenter) > 0)
        setEffect(city, effects.automationFactory, automation and hasAny(city, factories))
    end
end

-- Dirty UI events can fire synchronously during SetNumRealBuilding.
local syncing = false
local function syncAll()
    if syncing then return end
    syncing = true
    for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
        syncPlayer(playerID)
    end
    syncing = false
end

-- The turn sweep is also a fallback for gifts, unusual ownership changes and
-- building removal. UI dirty events handle construction/sales during the turn.
GameEvents.PlayerDoTurn.Add(syncAll)
GameEvents.TeamSetHasTech.Add(syncAll)
GameEvents.PlayerCityFounded.Add(syncAll)
GameEvents.CityCaptureComplete.Add(syncAll)
Events.SerialEventCityInfoDirty.Add(syncAll)
Events.SequenceGameInitComplete.Add(syncAll)
syncAll()
print('civ5-refined v5: technology and city effects loaded')
