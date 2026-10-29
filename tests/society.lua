-- Execute the actual v7 Lua against stateful, BNW-shaped API mocks.
local data = dofile(assert(arg[1]))
GameInfoTypes, GameInfo = {}, {}
local function collection(rows)
    local c = {}
    for _, r in ipairs(rows) do
        if r.Type then c[r.Type] = r; GameInfoTypes[r.Type] = r.ID end
        if r.ID then c[r.ID] = r end
    end
    return setmetatable(c, {__call=function(_, filter)
        local i = 0
        return function()
            while true do
                i = i + 1
                local r = rows[i]
                if not r then return end
                local match = true
                for k,v in pairs(filter or {}) do if r[k] ~= v then match = false end end
                if match then return r end
            end
        end
    end})
end
for name, rows in pairs(data) do GameInfo[name] = collection(rows) end
local function id(name) return assert(GameInfoTypes[name], name) end
local storage, notices, writes = {}, {}, 0
Modding = {OpenSaveData=function() return {
    GetValue=function(k) return storage[k] end,
    SetValue=function(k,v) storage[k]=v end
} end}
Locale = {ConvertTextKey=function(k, ...) return k end}
NotificationTypes = {NOTIFICATION_GENERIC=1}
local function event()
    local f = {}
    return {Add=function(h) f[#f+1]=h end, Fire=function(...) for _,h in ipairs(f) do h(...) end end}
end
local update
local function resetEvents()
    GameEvents, Events = {}, {}
    for _,n in ipairs({'PlayerCityFounded','PlayerDoTurn','TeamSetHasTech','TeamTechResearched','CityCaptureComplete','PlayerAdoptPolicy','UnitSetXY','SetAlly'}) do GameEvents[n]=event() end
    for _,n in ipairs({'WarStateChanged','SerialEventCityInfoDirty','SerialEventUnitInfoDirty','SequenceGameInitComplete'}) do Events[n]=event() end
    ContextPtr = {SetUpdate=function(_,fn) update=fn end}
end
resetEvents()
local function iter(t) local i=0; return function() i=i+1;return t[i] end end
local function player(i, minor, team, human)
    local p={id=i,minor=minor,team=team,human=human,alive=true,cities={},units={},policies={},blocked={},era=0,gold=0,civ=id('CIVILIZATION_AMERICA')}
    function p:IsAlive() return self.alive end
    function p:IsMinorCiv() return self.minor end
    function p:IsBarbarian() return self.barbarian or false end
    function p:IsHuman() return self.human end
    function p:GetTeam() return self.team end
    function p:GetCurrentEra() return self.era end
    function p:HasPolicy(b) return self.policies[b] or false end
    function p:IsPolicyBlocked(b) return self.blocked[b] or false end
    function p:IsPolicyBranchBlocked(b) return self.blocked[b] or false end
    function p:GetUnitByID(index) return self.units[index+1] end
    function p:GetCivilizationType() return self.civ end
    function p:Cities() return iter(self.cities) end
    function p:Units() return iter(self.units) end
    function p:GetCapitalCity() return self.cities[1] end
    function p:GetMinorCivType() return self.type end
    function p:GetAlly() return self.ally or -1 end
    function p:GetName() return self.type end
    function p:ChangeGold(n) self.gold=self.gold+n end
    function p:AddNotification(...) notices[#notices+1]={self.id,...} end
    return p
end
Players = {[0]=player(0,false,0,true),[1]=player(1,false,0,false),[2]=player(2,false,1,false)}
Teams = {}
for i=0,1 do
    local t={known={[id('TECH_AGRICULTURE')]=true},counts={},war=0}
    function t:IsHasTech(b) return self.known[b] or false end
    function t:GetAtWarCount(ignoreMinors) assert(ignoreMinors==false); return self.war end
    function t:GetTeamTechs() return {GetTechCount=function(_,tech) return self.counts[tech] or 0 end} end
    Teams[i]=t
end
local minors = {}
for index,r in ipairs(data.MinorCivilizations) do
    local p=player(index+2,true,index+2,false);p.type=r.ID
    Players[index+2]=p;minors[r.Type]=p
end
GameDefines = {MAX_CIV_PLAYERS=61}
local speed = id('GAMESPEED_STANDARD')
Game = {GetGameSpeedType=function() return speed end}
local plots = {}
Map = {GetPlot=function(x,y) return plots[x..'.'..y] end}
local function city(owner,x,pop)
    local c={owner=owner,original=owner,x=x,pop=pop,coast=true,works=3,real={},free={},founded=1}
    function c:GetNumBuilding(b) return (self.real[b] or 0)+(self.free[b] or 0) end
    function c:GetNumRealBuilding(b) return self.real[b] or 0 end
    function c:SetNumRealBuilding(b,n) assert(n>=0);self.real[b]=n;writes=writes+1;Events.SerialEventCityInfoDirty.Fire() end
    function c:GetPopulation() return self.pop end
    function c:GetOriginalOwner() return self.original end
    function c:GetID() return self.x end
    function c:GetX() return self.x end
    function c:GetY() return 0 end
    function c:GetGameTurnFounded() return self.founded end
    function c:GetNumGreatWorks() return self.works end
    function c:IsCoastal() return self.coast end
    plots[x..'.0']={GetPlotCity=function() return c end}
    return c
end
local capital=city(0,0,11)
for r in GameInfo.BuildingClasses() do
    if r.DefaultBuilding and not r.Type:find('REFINED') then capital.real[id(r.DefaultBuilding)]=1 end
end
Players[0].cities={capital}
local aiCapital=city(2,2,10);Players[2].cities={aiCapital}
for b,n in pairs(capital.real) do aiCapital.real[b]=n end
local merchant={type=id('UNIT_MERCHANT'),promotions={}}
function merchant:GetUnitType() return self.type end
function merchant:IsHasPromotion(b) return self.promotions[b] or false end
function merchant:SetHasPromotion(b,v) self.promotions[b]=v end
Players[0].units={merchant}
local function reload() resetEvents();dofile('mod/Lua/Society.lua') end
local function sync() GameEvents.PlayerDoTurn.Fire(0) end
local function count(c,name) return c:GetNumRealBuilding(id('BUILDING_REFINED_SOCIETY_'..name)) end
reload()
-- Every shipped minor maps to a real effect; transferring its alliance removes
-- its carrier from the former ally, including minors with conditional bonuses.
for r in GameInfo.Refined_Allies() do
    local m=minors[r.MinorType];m.ally=0;sync()
    local n=capital:GetNumRealBuilding(id(r.BuildingType))
    assert(r.Scope=='technology' or n>0, r.MinorType..' did not apply')
    local before=writes;sync();assert(writes==before,'non-idempotent sweep')
    m.ally=2;GameEvents.SetAlly.Fire(m.id,0,2)
    assert(capital:GetNumRealBuilding(id(r.BuildingType))==0,'stale former ally effect')
    assert(r.Scope=='technology' or aiCapital:GetNumRealBuilding(id(r.BuildingType))>0, 'AI did not receive '..r.MinorType)
    m.ally=-1;sync()
end
print('PASS: all 58 alliance mappings, neutral/AI transfer and idempotent removal')
minors.MINOR_CIV_GENEVA.ally=0;sync();assert(count(capital,'GENEVA')==1)
Teams[0].war=1;Events.WarStateChanged.Fire();assert(count(capital,'GENEVA')==0)
Teams[0].war=0;Events.WarStateChanged.Fire();assert(count(capital,'GENEVA')==1)
minors.MINOR_CIV_FLORENCE.ally=0;minors.MINOR_CIV_MONACO.ally=0;sync()
assert(count(capital,'FLORENCE')==3 and count(capital,'MONACO')==3)
capital.works=0;Events.SerialEventCityInfoDirty.Fire();update(0.3);assert(count(capital,'FLORENCE')==0)
capital.works=3
local before=#notices;reload();assert(#notices==before,'reload repeated alliance notifications')
-- Captured cities must recompute for the new owner, never retain the old ally.
Players[0].cities={};Players[2].cities={aiCapital,capital};capital.owner=2
GameEvents.CityCaptureComplete.Fire();assert(count(capital,'GENEVA')==0)
Players[2].cities={aiCapital};Players[0].cities={capital};capital.owner=0;sync()
print('PASS: peace, Great Work transfer, city capture and save/reload')
local function adopt(name,p) (p or Players[0]).policies[id('POLICY_'..name)]=true end
adopt('LIBERTY_FINISHER');sync()
assert(not GameInfoTypes.BUILDING_REFINED_SOCIETY_LIBERTY,'population-dependent carrier must be removed')
Players[0].civ=id('CIVILIZATION_ETHIOPIA')
local colony=city(0,3,1);table.insert(Players[0].cities,colony)
GameEvents.PlayerCityFounded.Fire(0,3,0)
assert(colony:GetNumBuilding(id('BUILDING_STELE'))==1,'unique monument not granted')
colony.real[id('BUILDING_STELE')]=0;sync();assert(colony:GetNumBuilding(id('BUILDING_STELE'))==0,'sold monument regenerated')
colony.pop=6;sync();colony.pop=12;sync()
reload();assert(colony:GetNumBuilding(id('BUILDING_STELE'))==0,'reload regranted sold monument')
local captured=city(0,4,2);captured.original=2;table.insert(Players[0].cities,captured);sync()
assert(captured:GetNumBuilding(id('BUILDING_STELE'))==0,'captured city must not get a founding monument')
-- A base trade-route slot is represented once, in the current capital. It must
-- follow ownership/capital/policy changes and never multiply per city or reload.
adopt('COMMERCE_FINISHER');GameEvents.PlayerAdoptPolicy.Fire()
assert(count(capital,'COMMERCE_ROUTE')==1 and count(colony,'COMMERCE_ROUTE')==0 and count(captured,'COMMERCE_ROUTE')==0)
reload();assert(count(capital,'COMMERCE_ROUTE')==1)
Players[0].cities={colony,capital,captured};sync()
assert(count(colony,'COMMERCE_ROUTE')==1 and count(capital,'COMMERCE_ROUTE')==0)
Players[0].blocked[id('POLICY_BRANCH_COMMERCE')]=true;sync();assert(count(colony,'COMMERCE_ROUTE')==0)
Players[0].blocked[id('POLICY_BRANCH_COMMERCE')]=false
Players[0].cities={capital,captured};Players[2].cities={aiCapital,colony};colony.owner=2
GameEvents.CityCaptureComplete.Fire()
assert(count(capital,'COMMERCE_ROUTE')==1 and count(colony,'COMMERCE_ROUTE')==0)
adopt('COMMERCE_FINISHER',Players[2]);sync()
assert(count(aiCapital,'COMMERCE_ROUTE')==1 and count(colony,'COMMERCE_ROUTE')==0)
Players[2].cities={aiCapital};Players[0].cities={capital,colony,captured};colony.owner=0;sync()
adopt('TRADITION_FINISHER');Players[0].era=id('ERA_RENAISSANCE');sync();assert(count(capital,'TRADITION_LATE')==0)
Players[0].era=id('ERA_INDUSTRIAL');sync();assert(count(capital,'TRADITION_LATE')==2 and count(colony,'TRADITION_LATE')==0)
adopt('FLOURISHING_OF_ARTS');capital.works=2;sync();assert(count(capital,'COLLECTION')==1)
capital.works=1;sync();assert(count(capital,'COLLECTION')==0)
adopt('ORGANIZED_RELIGION');sync();assert(count(capital,'TEMPLE_LATE')==1)
capital.real[id('BUILDING_TEMPLE')]=0;sync();assert(count(capital,'TEMPLE_LATE')==0)
adopt('PATRONAGE_FINISHER');sync();assert(count(capital,'ALLIED_CULTURE')==3)
adopt('EXPLORATION_FINISHER');adopt('NAVIGATION_SCHOOL');sync()
assert(count(colony,'ARCHAEOLOGY')==1 and count(colony,'NAVIGATORS')==1)
adopt('ENTREPRENEURSHIP');sync();assert(merchant:IsHasPromotion(id('PROMOTION_REFINED_MERCHANT')))
Players[0].blocked[id('POLICY_ENTREPRENEURSHIP')]=true;sync();assert(not merchant:IsHasPromotion(id('PROMOTION_REFINED_MERCHANT')))
adopt('ENTREPRENEURSHIP',Players[2]);Players[2].units={merchant}
GameEvents.UnitSetXY.Fire(2,0,1,1)
assert(merchant:IsHasPromotion(id('PROMOTION_REFINED_MERCHANT')),'new AI merchant must work before deferred UI updates')
Players[2].units={};Players[0].units={merchant}
print('PASS: founding monuments without population bonus; Commerce route slot follows capital, capture, AI, policy and reload; late policies and merchant promotion')
-- Technology awards use the event's team and the current alliance, persist
-- through reload, do not pool teams, and never reward historical technologies.
local singapore=minors.MINOR_CIV_SINGAPORE;singapore.ally=0;sync()
GameEvents.TeamSetHasTech.Fire(0,id('TECH_AGRICULTURE'),true);assert(Players[0].gold==0)
Teams[0].known[id('TECH_POTTERY')]=true
GameEvents.TeamSetHasTech.Fire(0,id('TECH_POTTERY'),true)
local gold = 10
assert(Players[0].gold==gold and Players[1].gold==0 and Players[2].gold==0)
GameEvents.TeamSetHasTech.Fire(0,id('TECH_POTTERY'),true);reload();assert(Players[0].gold==gold)
singapore.ally=2;sync();speed=id('GAMESPEED_QUICK')
Teams[1].known[id('TECH_WRITING')]=true;GameEvents.TeamSetHasTech.Fire(1,id('TECH_WRITING'),true)
assert(Players[2].gold==math.floor(10*GameInfo.GameSpeeds[speed].ResearchPercent/100))
singapore.ally=0;sync();GameEvents.TeamSetHasTech.Fire(1,id('TECH_WRITING'),true)
assert(Players[0].gold==gold)
speed=id('GAMESPEED_STANDARD')
local future=id('TECH_FUTURE_TECH')
Teams[0].counts[future]=1;GameEvents.TeamTechResearched.Fire(0,future,1)
local afterFuture=Players[0].gold
assert(afterFuture==gold+10,'Future Tech must grant the same fixed reward as an early technology')
Teams[0].counts[future]=2;GameEvents.TeamTechResearched.Fire(0,future,1)
assert(Players[0].gold==afterFuture,'Future Tech repeat was rewarded twice')
reload();GameEvents.TeamTechResearched.Fire(0,future,1);assert(Players[0].gold==afterFuture)
print('PASS: Singapore exact-once event awards, current ally, team isolation, AI, speed and reload')
