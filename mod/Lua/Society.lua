-- BNW: derive alliance/institution effects from current state. No dummy policies:
-- hidden policies count toward policy cost in the stock DLL.
local save = Modding.OpenSaveData()
local cache = {}
local function get(key)
    key = 'refined.v7.' .. key
    if cache[key] == nil then cache[key] = save.GetValue(key) or false end
    return cache[key]
end
local function put(key, value)
    key = 'refined.v7.' .. key
    cache[key] = value
    save.SetValue(key, value)
end
local function id(name) return assert(GameInfoTypes[name], 'Refined v7: missing ' .. name) end
local function major(p) return p and p:IsAlive() and not p:IsMinorCiv() and not p:IsBarbarian() end
local function policy(p, name)
    local index = id('POLICY_' .. name)
    if not p:HasPolicy(index) or p:IsPolicyBlocked(index) then return false end
    if name:sub(-9) == '_FINISHER' then
        return not p:IsPolicyBranchBlocked(id('POLICY_BRANCH_' .. name:sub(1, -10)))
    end
    return true
end
local carriers, bonuses, classes = {}, {}, {}
for row in GameInfo.Refined_SocietyCarriers() do carriers[#carriers + 1] = id(row.BuildingType) end
for row in GameInfo.Refined_Allies() do
    bonuses[row.MinorType] = {building=id(row.BuildingType), scope=row.Scope, help=row.Help, type=row.MinorType}
end
for row in GameInfo.Refined_AllyClasses() do
    classes[row.MinorType] = classes[row.MinorType] or {}
    classes[row.MinorType][#classes[row.MinorType] + 1] = row.BuildingClass
end
local buildingClasses = {}
for b in GameInfo.Buildings() do
    buildingClasses[b.BuildingClass] = buildingClasses[b.BuildingClass] or {}
    table.insert(buildingClasses[b.BuildingClass], b.ID)
end
local function classCount(city, cls)
    local count = 0
    for _, b in ipairs(buildingClasses[cls] or {}) do count = count + city:GetNumBuilding(b) end
    return count
end
local function carrier(name) return id('BUILDING_REFINED_SOCIETY_' .. name) end
local merchantPromotion = id('PROMOTION_REFINED_MERCHANT')
local industrial = GameInfo.Eras[id('ERA_INDUSTRIAL')].ID
local function settlementKey(playerID, city)
    return 'settlement.' .. playerID .. '.' .. city:GetX() .. '.' .. city:GetY() .. '.' .. city:GetGameTurnFounded()
end
local function monumentFor(p)
    local cls = 'BUILDINGCLASS_MONUMENT'
    local civilization = GameInfo.Civilizations[p:GetCivilizationType()].Type
    for row in GameInfo.Civilization_BuildingClassOverrides({CivilizationType=civilization, BuildingClassType=cls}) do
        return row.BuildingType and id(row.BuildingType) or -1
    end
    return id(GameInfo.BuildingClasses[cls].DefaultBuilding)
end
local function notify(p, minor, effect, gained)
    if not p:IsHuman() then return end
    local key = gained and 'TXT_KEY_REFINED_ALLY_GAIN' or 'TXT_KEY_REFINED_ALLY_LOST'
    local cap = minor:GetCapitalCity()
    p:AddNotification(NotificationTypes.NOTIFICATION_GENERIC,
        Locale.ConvertTextKey(effect.help), Locale.ConvertTextKey(key, minor:GetName()),
        cap and cap:GetX() or -1, cap and cap:GetY() or -1)
end
local function currentAllies(announce)
    local result = {}
    for i = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
        local minor = Players[i]
        if minor and minor:IsMinorCiv() then
            local row = GameInfo.MinorCivilizations[minor:GetMinorCivType()]
            local effect = row and bonuses[row.Type]
            if effect then
                local owner = minor:IsAlive() and minor:GetAlly() or -1
                if not major(Players[owner]) then owner = -1 end
                local previous = get('ally.' .. row.Type)
                if previous ~= owner then
                    -- No notification for neutral minors on first initialization.
                    if announce then
                        if previous and previous >= 0 and major(Players[previous]) then
                            notify(Players[previous], minor, effect, false)
                        end
                        if owner >= 0 then notify(Players[owner], minor, effect, true) end
                    end
                    if announce then put('ally.' .. row.Type, owner) end
                end
                if owner >= 0 then
                    result[owner] = result[owner] or {}
                    table.insert(result[owner], effect)
                end
            end
        end
    end
    return result
end
local function apply(city, desired)
    for _, b in ipairs(carriers) do
        local n = desired[b] or 0
        if city:GetNumRealBuilding(b) ~= n then city:SetNumRealBuilding(b, n) end
    end
end
local syncing, pending = false, false
local function syncAll()
    if syncing then pending = true; return end
    syncing = true
    local allies = currentAllies(true)
    for i = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
        local p = Players[i]
        if p and p:IsAlive() then
            local active = major(p)
            local patrons = active and policy(p, 'PATRONAGE_FINISHER')
            local commercialRoutes = active and policy(p, 'COMMERCE_FINISHER')
            local tradition = active and policy(p, 'TRADITION_FINISHER') and p:GetCurrentEra() >= industrial
            local collections = active and policy(p, 'FLOURISHING_OF_ARTS')
            local religion = active and policy(p, 'ORGANIZED_RELIGION') and p:GetCurrentEra() >= industrial
            local archaeology = active and policy(p, 'EXPLORATION_FINISHER')
            local navigation = active and policy(p, 'NAVIGATION_SCHOOL')
            local commerce = active and policy(p, 'ENTREPRENEURSHIP')
            local capital = p:GetCapitalCity()
            for city in p:Cities() do
                local isCapital = capital and city:GetID() == capital:GetID()
                local desired = {}
                if active then
                    for _, effect in ipairs(allies[i] or {}) do
                        local n, scope = 1, effect.scope
                        if scope == 'technology' then n = 0
                        elseif scope == 'coast' then n = city:IsCoastal() and 1 or 0
                        elseif scope == 'capital' then n = isCapital and 1 or 0
                        elseif scope == 'peace' then n = Teams[p:GetTeam()]:GetAtWarCount(false) == 0 and 1 or 0
                        elseif scope == 'works' then n = city:GetNumGreatWorks()
                        elseif scope == 'population' then n = math.floor(city:GetPopulation() / 5) end
                        if classes[effect.type] then
                            local count = 0
                            for _, cls in ipairs(classes[effect.type]) do count = count + classCount(city, cls) end
                            n = n * count
                        end
                        desired[effect.building] = n
                    end
                    if commercialRoutes and isCapital then desired[carrier('COMMERCE_ROUTE')] = 1 end
                    if tradition and isCapital then desired[carrier('TRADITION_LATE')] = math.floor(city:GetPopulation() / 5) end
                    if collections and city:GetNumGreatWorks() >= 2 then desired[carrier('COLLECTION')] = 1 end
                    if religion then desired[carrier('TEMPLE_LATE')] = classCount(city, 'BUILDINGCLASS_TEMPLE') end
                    if patrons and isCapital then desired[carrier('ALLIED_CULTURE')] = #(allies[i] or {}) end
                    if archaeology then desired[carrier('ARCHAEOLOGY')] = 1 end
                    if navigation then desired[carrier('NAVIGATORS')] = 1 end
                end
                apply(city, desired)
            end
            -- The same trade mission promotion is synchronized for human and AI
            -- merchants, including Venice, without changing the mission itself.
            for unit in p:Units() do
                local row = GameInfo.Units[unit:GetUnitType()]
                local enabled = commerce and row.Class == 'UNITCLASS_MERCHANT' or false
                if unit:IsHasPromotion(merchantPromotion) ~= enabled then unit:SetHasPromotion(merchantPromotion, enabled) end
            end
        end
    end
    syncing = false
end
local function markDirty() if not syncing then pending = true end end
local function movedUnit(playerID, unitID)
    local p = Players[playerID]
    local unit = p and p:GetUnitByID(unitID)
    if not unit then return end
    local row = GameInfo.Units[unit:GetUnitType()]
    if row.Class == 'UNITCLASS_MERCHANT' then
        local enabled = major(p) and policy(p, 'ENTREPRENEURSHIP') or false
        if unit:IsHasPromotion(merchantPromotion) ~= enabled then unit:SetHasPromotion(merchantPromotion, enabled) end
    end
end
local function founded(playerID, x, y)
    local p = Players[playerID]
    local plot = Map.GetPlot(x, y)
    local city = plot and plot:GetPlotCity()
    if city and major(p) and policy(p, 'LIBERTY_FINISHER') and not get(settlementKey(playerID, city)) then
        put(settlementKey(playerID, city), 1)
        -- Grant once; subsequent selling/pillaging/recapture never regenerates it.
        if classCount(city, 'BUILDINGCLASS_MONUMENT') == 0 then
            local monument = monumentFor(p)
            if monument >= 0 then city:SetNumRealBuilding(monument, 1) end
        end
    end
    syncAll()
end
local function techKey(teamID, row) return 'tech.' .. teamID .. '.' .. row.Type end
local function researched(teamID, techID, value)
    if not value then return end
    local row = GameInfo.Technologies[techID]
    if not row or get(techKey(teamID, row)) then return end
    put(techKey(teamID, row), 1) -- before ChangeGold and any reentrant UI events
    local allies = currentAllies(false)
    local speed = GameInfo.GameSpeeds[Game.GetGameSpeedType()].ResearchPercent
    for i, effects in pairs(allies) do
        local p = Players[i]
        if p:GetTeam() == teamID then
            for _, effect in ipairs(effects) do
                if effect.scope == 'technology' then
                    p:ChangeGold(math.floor(10 * speed / 100))
                end
            end
        end
    end
    syncAll()
end
-- Initialize researched Types without retroactive rewards. Save keys are stable
-- across database ID changes and remain present after losing an alliance.
for i = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
    local p = Players[i]
    if major(p) then
        local team = Teams[p:GetTeam()]
        for row in GameInfo.Technologies() do
            if (team:IsHasTech(row.ID) or team:GetTeamTechs():GetTechCount(row.ID) > 0) and not get(techKey(p:GetTeam(), row)) then
                put(techKey(p:GetTeam(), row), 1)
            end
        end
    end
end
GameEvents.PlayerCityFounded.Add(founded)
GameEvents.PlayerDoTurn.Add(syncAll)
GameEvents.TeamSetHasTech.Add(researched)
GameEvents.TeamTechResearched.Add(function(teamID, techID, change)
    if change > 0 then researched(teamID, techID, true) end
    syncAll()
end)
GameEvents.CityCaptureComplete.Add(syncAll)
GameEvents.PlayerAdoptPolicy.Add(syncAll)
GameEvents.UnitSetXY.Add(movedUnit)
GameEvents.SetAlly.Add(syncAll)
Events.WarStateChanged.Add(syncAll)
Events.SerialEventCityInfoDirty.Add(markDirty)
Events.SerialEventUnitInfoDirty.Add(markDirty)
Events.SequenceGameInitComplete.Add(syncAll)
local elapsed = 0
ContextPtr:SetUpdate(function(delta)
    elapsed = elapsed + delta
    if pending and elapsed >= 0.2 then pending = false; elapsed = 0; syncAll() end
end)
syncAll()
print('civ5-refined v7: 58 allied benefits and nine institution branches loaded')
