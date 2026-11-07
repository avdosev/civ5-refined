-- Diagnostic-only addin: no includes, custom tables, effects or save writes.
print('REFINED LOAD AUDIT v11/audit-1: independent addin entered')
local reported, elapsed = false, 0
local function report()
    if reported then return end
    local playerID = Game.GetActivePlayer()
    local player = playerID >= 0 and Players[playerID]
    if not player or not player:IsAlive() then return end
    local total, added = 0, 0
    for row in GameInfo.Technologies() do
        total = total + 1
        if row.Type:sub(1,13) == 'TECH_REFINED_' then added = added + 1 end
    end
    local function exists(name)
        return GameInfo.Technologies[name] and 'OK' or 'MISSING'
    end
    local liberty = GameInfo.Policies.POLICY_LIBERTY_FINISHER
    local institutions = liberty and liberty.BuildingProductionModifier == 10 and 'OK' or 'MISSING/CHANGED'
    local lines = {
        'Package v11 / audit-1',
        'Technologies: ' .. total .. '; refined: ' .. added,
        'Gameplay.sql: ' .. exists('TECH_REFINED_NETWORKS'),
        'Development.sql: ' .. exists('TECH_REFINED_AGRICULTURAL_MECHANIZATION'),
        'Victories.sql: ' .. exists('TECH_REFINED_RECURSIVE'),
        'Modernization.sql: ' .. exists('TECH_REFINED_DRONES'),
        'Institutions.sql (+10% Liberty buildings): ' .. institutions
    }
    local text = table.concat(lines, '[NEWLINE]')
    print('REFINED LOAD AUDIT: ' .. table.concat(lines, ' | '))
    -- Mark before calling UI so repeated callbacks never duplicate notifications.
    reported = true
    player:AddNotification(NotificationTypes.NOTIFICATION_GENERIC, text,
        'REFINED v11 LOAD AUDIT', -1, -1)
    Events.GameplayAlertMessage(text)
end
ContextPtr:SetUpdate(function(delta)
    if reported then return end
    elapsed = elapsed + delta
    if elapsed >= 3 then report() end
end)
