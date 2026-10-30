-- BNW v8. Native projects/buildings/process menu; no DLL or second currency.
local save = Modding.OpenSaveData()
local cache = {}
local function get(key, default)
    key = 'refined.v8.victory.' .. key
    if cache[key] == nil then cache[key] = save.GetValue(key) or false end
    if cache[key] == false then return default end
    return cache[key]
end
local function put(key, value)
    key = 'refined.v8.victory.' .. key
    if cache[key] ~= value then cache[key] = value; save.SetValue(key, value) end
end
local function id(name) return assert(GameInfoTypes[name], 'Refined v8: missing ' .. name) end
local scienceVictory = id('VICTORY_SPACE_RACE')
local scienceYield = id('YIELD_SCIENCE')
local process = id('PROCESS_REFINED_LEARNING')
local dataCenter = id('BUILDING_REFINED_DATA_CENTER')
local supercomputer = id('BUILDING_REFINED_SUPERCOMPUTER')
local command = id('BUILDING_REFINED_BATTLE_COMMAND')
local promotion = id('PROMOTION_REFINED_NETWORK_COMMAND')
local recursive = id('TECH_REFINED_RECURSIVE')
local rocketry, appliedAI = id('TECH_ROCKETRY'), id('TECH_REFINED_AI')
local universal = id('PROJECT_REFINED_UNIVERSAL_AI')
local colony = id('PROJECT_REFINED_MARS_COLONY')
local baseGoal
for row in GameInfo.Refined_VictorySettings() do
    if row.Name == 'LearningGoal' then baseGoal = row.Value end
end
assert(baseGoal and baseGoal > 0, 'Refined v8: invalid learning goal')
local speed = GameInfo.GameSpeeds[Game.GetGameSpeedType()]
-- Stored in hundredths of progress, like the native yield API. Speed only;
-- no extra city-count tax on this project. Round the displayed goal upward.
local goal = math.ceil(baseGoal * speed.ResearchPercent / 100) * 100
local projects, mars = {}, {}
for row in GameInfo.Refined_VictoryProjects() do
    local projectID = id(row.Type)
    projects[projectID] = {tech=id(row.TechType), sequence=row.Sequence, route=row.Route}
    if row.Route == 'mars' then mars[row.Sequence] = projectID end
end
assert(#mars == 4, 'Refined v8: expected four Mars stages')
local function major(player)
    return player and player:IsAlive() and not player:IsMinorCiv() and not player:IsBarbarian()
end
local function gameOpen()
    return Game.IsVictoryValid(scienceVictory) and Game.GetWinner() < 0
        and Game.GetGameState() == GameStateTypes.GAMESTATE_ON
end
local function hasBuilding(player, building)
    for city in player:Cities() do
        if city:GetNumBuilding(building) > 0 then return true end
    end
    return false
end
local function teamHasBuilding(teamID, building)
    for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
        local player = Players[playerID]
        if major(player) and player:GetTeam() == teamID and hasBuilding(player, building) then return true end
    end
    return false
end
local function ready(player)
    if not major(player) or not gameOpen() then return false end
    local teamID = player:GetTeam()
    local team = Teams[teamID]
    return team:IsHasTech(recursive) and team:GetProjectCount(universal) > 0
        and teamHasBuilding(teamID, supercomputer)
end
local function eligible(player, city)
    return city and ready(player) and city:GetNumBuilding(dataCenter) > 0
end
local function progressKey(teamID) return 'team.' .. teamID .. '.progress' end
local function stampKey(playerID, city)
    -- Coordinates/founding turn distinguish city-ID reuse and ownership changes.
    return 'work.' .. playerID .. '.' .. city:GetX() .. '.' .. city:GetY() .. '.' .. city:GetGameTurnFounded()
end

local function canConstruct(playerID, cityID, buildingID)
    if buildingID ~= supercomputer and buildingID ~= command then return true end
    local player = Players[playerID]
    local city = player and player:GetCityByID(cityID)
    return major(player) and city and city:GetNumBuilding(dataCenter) > 0 or false
end
local function canCreate(playerID, cityID, projectID)
    local config = projects[projectID]
    if not config then return true end
    local player = Players[playerID]
    local city = player and player:GetCityByID(cityID)
    if not major(player) or not city or not gameOpen() then return false end
    local team = Teams[player:GetTeam()]
    if not team:IsHasTech(config.tech) or team:GetProjectCount(projectID) > 0 then return false end
    if config.route == 'mars' then
        if config.sequence > 1 and team:GetProjectCount(mars[config.sequence - 1]) < 1 then return false end
        return projectID ~= colony or city:GetNumBuilding(dataCenter) > 0
    end
    return teamHasBuilding(player:GetTeam(), supercomputer)
end
local function canMaintain(playerID, cityID, processID)
    if processID ~= process then return true end
    local player = Players[playerID]
    local city = player and player:GetCityByID(cityID)
    if not eligible(player, city) then return false end
    -- Native CleanUpQueue validates the selected process before city production.
    -- Queries only snapshot work; they NEVER add progress. A newly selected AI
    -- order after completing a building cannot earn a full retrospective turn.
    if city:GetProductionProcess() == process then
        local key = stampKey(playerID, city)
        local amount = 0
        if not player:IsAnarchy() and not city:IsResistance() and not city:IsRazing() then
            amount = math.max(0, city:GetYieldRateTimes100(scienceYield))
        end
        put(key .. '.turn', Game.GetGameTurn())
        put(key .. '.science', amount)
    end
    return true
end

local function win(teamID, route)
    if not gameOpen() then return end
    put('team.' .. teamID .. '.route', route)
    local text = Locale.ConvertTextKey('TXT_KEY_REFINED_VICTORY_' .. route:upper() .. '_WON')
    for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
        local player = Players[playerID]
        if major(player) and player:GetTeam() == teamID and player:IsHuman() then
            player:AddNotification(NotificationTypes.NOTIFICATION_GENERIC, text,
                Locale.ConvertTextKey('TXT_KEY_REFINED_VICTORY_TITLE'), -1, -1)
        end
    end
    -- Native SetWinner records the winning turn, replay, notifications and game
    -- state. Both alternate routes use the existing science victory Type.
    Game.SetWinner(teamID, scienceVictory)
end
local function checkMars(player)
    if not major(player) or not gameOpen() then return end
    local team = Teams[player:GetTeam()]
    for _, projectID in ipairs(mars) do
        if team:GetProjectCount(projectID) < 1 then return end
    end
    win(player:GetTeam(), 'mars')
end

local function syncUnit(player, unit, active)
    if not unit then return end
    local info = GameInfo.Units[unit:GetUnitType()]
    local combat = info and (info.Combat > 0 or info.RangedCombat > 0)
        and (not info.NukeDamageLevel or info.NukeDamageLevel < 0)
    local wanted = active and combat or false
    if unit:IsHasPromotion(promotion) ~= wanted then unit:SetHasPromotion(promotion, wanted) end
end
local function syncArmy(player)
    if not major(player) then return end
    local active = hasBuilding(player, command)
    for unit in player:Units() do syncUnit(player, unit, active) end
end
local pending, syncing, cityScreen = true, false, false
local function markDirty() if not syncing then pending = true end end
local function syncAll()
    if syncing then return end
    syncing, pending = true, false
    for playerID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
        local player = Players[playerID]
        if major(player) then syncArmy(player); checkMars(player) end
    end
    syncing = false
end
local function playerTurn(playerID)
    local player = Players[playerID]
    if not major(player) then return end
    syncArmy(player)
    checkMars(player)
    local turn = Game.GetGameTurn()
    local key = 'player.' .. playerID .. '.creditedTurn'
    if get(key, -1) == turn then return end
    put(key, turn) -- even when stopped: UI events/reload cannot credit a second pass.
    if ready(player) then
        local total = 0
        for city in player:Cities() do
            if eligible(player, city) and city:GetProductionProcess() == process then
                local stamp = stampKey(playerID, city)
                if get(stamp .. '.turn', -1) == turn then total = total + get(stamp .. '.science', 0) end
            end
        end
        local progress = math.min(goal, get(progressKey(player:GetTeam()), 0) + total)
        put(progressKey(player:GetTeam()), progress)
        if progress >= goal then win(player:GetTeam(), 'singularity') end
    end
    pending = true
end

local function updatePanel()
    local player = Players[Game.GetActivePlayer()]
    if cityScreen or not major(player) or not Game.IsVictoryValid(scienceVictory) then
        Controls.VictoryPanel:SetHide(true); return
    end
    local teamID = player:GetTeam()
    local team = Teams[teamID]
    if not team:IsHasTech(rocketry) and not team:IsHasTech(appliedAI) then
        Controls.VictoryPanel:SetHide(true); return
    end
    Controls.VictoryPanel:SetHide(false)
    local count = 0
    for _, projectID in ipairs(mars) do if team:GetProjectCount(projectID) > 0 then count = count + 1 end end
    local progress = get(progressKey(teamID), 0)
    local rate, lines = 0, {}
    if ready(player) then
        for otherID = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
            local other = Players[otherID]
            if major(other) and other:GetTeam() == teamID and not other:IsAnarchy() then
                for city in other:Cities() do
                    if eligible(other, city) and city:GetProductionProcess() == process
                        and not city:IsResistance() and not city:IsRazing() then
                        local amount = math.max(0, city:GetYieldRateTimes100(scienceYield))
                        rate = rate + amount
                        lines[#lines + 1] = Locale.ConvertTextKey('TXT_KEY_REFINED_VICTORY_CITY_RATE',
                            city:GetName(), string.format('%.1f', amount / 100))
                    end
                end
            end
        end
    end
    local pct = math.floor(100 * progress / goal)
    Controls.ProgramTitle:SetText(Locale.ConvertTextKey('TXT_KEY_REFINED_VICTORY_PANEL'))
    Controls.ProgramProgress:SetText(Locale.ConvertTextKey('TXT_KEY_REFINED_VICTORY_LINE', count, pct))
    Controls.ProgramRate:SetText(Locale.ConvertTextKey('TXT_KEY_REFINED_VICTORY_RATE',
        string.format('%.1f', rate / 100), math.floor(progress / 100), goal / 100))
    if #lines == 0 then lines[1] = Locale.ConvertTextKey('TXT_KEY_REFINED_VICTORY_BLOCKED') end
    Controls.VictoryPanel:SetToolTipString(Locale.ConvertTextKey('TXT_KEY_REFINED_VICTORY_TOOLTIP',
        count, math.floor(progress / 100), goal / 100, string.format('%.1f', rate / 100), table.concat(lines, '[NEWLINE]')))
end

GameEvents.CityCanConstruct.Add(canConstruct)
GameEvents.CityCanCreate.Add(canCreate)
GameEvents.CityCanMaintain.Add(canMaintain)
GameEvents.PlayerDoTurn.Add(playerTurn)
GameEvents.TeamSetHasTech.Add(markDirty)
GameEvents.PlayerCityFounded.Add(markDirty)
GameEvents.CityCaptureComplete.Add(syncAll)
GameEvents.UnitSetXY.Add(function(playerID, unitID)
    local player = Players[playerID]
    if major(player) then syncUnit(player, player:GetUnitByID(unitID), hasBuilding(player, command)) end
    markDirty()
end)
Events.SerialEventCityInfoDirty.Add(markDirty)
Events.SerialEventUnitInfoDirty.Add(markDirty)
Events.SerialEventGameDataDirty.Add(markDirty)
Events.SequenceGameInitComplete.Add(function() syncAll(); updatePanel() end)
Events.SerialEventEnterCityScreen.Add(function() cityScreen = true; Controls.VictoryPanel:SetHide(true) end)
Events.SerialEventExitCityScreen.Add(function() cityScreen = false; markDirty() end)
Events.GameplaySetActivePlayer.Add(markDirty)
local elapsed = 0
ContextPtr:SetUpdate(function(delta)
    elapsed = elapsed + delta
    if pending and elapsed >= 0.25 then elapsed = 0; syncAll(); updatePanel() end
end)
syncAll()
updatePanel()
print('civ5-refined v8: interstellar, Mars, singularity and integrated command loaded')
