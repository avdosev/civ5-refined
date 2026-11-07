-- Test both absent and present SQL content; no dependency on mod runtime.
for _, present in ipairs({false,true}) do
    local notices, messages, active = {}, {}, -1
    local rows = {{Type='TECH_AGRICULTURE'}}
    GameInfo = {Policies = {POLICY_LIBERTY_FINISHER = {BuildingProductionModifier=present and 10 or 0}}}
    if present then
        for _,name in ipairs({'NETWORKS','AGRICULTURAL_MECHANIZATION','RECURSIVE','DRONES'}) do
            rows[#rows+1] = {Type='TECH_REFINED_' .. name}
        end
    end
    local technologies = {}
    for _, row in ipairs(rows) do technologies[row.Type] = row end
    GameInfo.Technologies = setmetatable(technologies, {__call=function()
        local i=0; return function() i=i+1; return rows[i] end
    end})
    local player = {IsAlive=function() return true end,
        AddNotification=function(_,_,text,title) notices[#notices+1] = text; assert(title=='REFINED v11 LOAD AUDIT') end}
    Players = {[0]=player}
    Game = {GetActivePlayer=function() return active end}
    NotificationTypes = {NOTIFICATION_GENERIC=0}
    Events = {GameplayAlertMessage=function(text) messages[#messages+1]=text end}
    local update
    ContextPtr = {SetUpdate=function(_,fn) update=fn end}
    dofile('tools/diagnostics/LoadAudit.lua')
    update(4);assert(#notices==0, 'wait for active game')
    active=0;update(.1)
    assert(#notices==1 and #messages==1)
    assert(notices[1]:find(present and 'refined: 4' or 'refined: 0',1,true))
    assert(notices[1]:find(present and 'Gameplay.sql: OK' or 'Gameplay.sql: MISSING',1,true))
    update(10);assert(#notices==1, 'one report only')
end
print('PASS: independent load audit, missing/present SQL, inactive game and no duplicate notifications')
