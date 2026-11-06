-- Execute the shipped script, using schema/rules exported from the real SQL.
local data = dofile(assert(arg[1]))
GameplayGameStateTypes={GAMESTATE_ON=0,GAMESTATE_OVER=1,GAMESTATE_EXTENDED=2}
local storage, turn, winner, state, enabled, speedType, wins = {}, 1, -1, GameplayGameStateTypes.GAMESTATE_ON, true, 'GAMESPEED_STANDARD', 0
local nextID = 0
GameInfoTypes = {}
local function id(name)
    if not GameInfoTypes[name] then nextID=nextID+1; GameInfoTypes[name]=nextID end
    return GameInfoTypes[name]
end
local function collection(rows)
    local result = {}
    for _,row in ipairs(rows) do
        if row.Type then row.ID=id(row.Type);result[row.ID]=row;result[row.Type]=row end
    end
    return setmetatable(result,{__call=function()
        local index=0;return function() index=index+1;return rows[index] end
    end})
end
GameInfo={}
for name,rows in pairs(data) do GameInfo[name]=collection(rows) end
id('VICTORY_SPACE_RACE');id('YIELD_SCIENCE')
local function event()
    local handlers={}
    return {Add=function(fn) handlers[#handlers+1]=fn end,
        Fire=function(...) for _,fn in ipairs(handlers) do fn(...) end end,
        Test=function(...) for _,fn in ipairs(handlers) do if fn(...)==false then return false end end;return true end}
end
local function resetEvents()
    GameEvents={};Events={}
    for _,name in ipairs({'CityCanConstruct','CityCanCreate','CityCanMaintain','PlayerDoTurn',
        'TeamSetHasTech','PlayerCityFounded','CityCaptureComplete','UnitSetXY'}) do GameEvents[name]=event() end
    for _,name in ipairs({'SerialEventCityInfoDirty','SerialEventUnitInfoDirty','SerialEventGameDataDirty',
        'SequenceGameInitComplete','SerialEventEnterCityScreen','SerialEventExitCityScreen','GameplaySetActivePlayer'}) do Events[name]=event() end
    ContextPtr={SetUpdate=function(self,fn) self.update=fn end}
end
local function control()
    return {SetText=function(self,v) self.text=v end,SetHide=function(self,v) self.hidden=v end,
        SetToolTipString=function(self,v) self.tooltip=v end}
end
Controls={VictoryPanel=control(),ProgramTitle=control(),ProgramProgress=control(),ProgramRate=control()}
GameDefines={MAX_CIV_PLAYERS=4}
Game={GetGameTurn=function() return turn end,GetActivePlayer=function() return 0 end,
    GetWinner=function() return winner end,GetGameState=function() return state end,
    IsVictoryValid=function(v) assert(v==id('VICTORY_SPACE_RACE'));return enabled end,
    GetGameSpeedType=function() return id(speedType) end,
    SetWinner=function(team,victory) assert(enabled and winner<0 and state==GameplayGameStateTypes.GAMESTATE_ON);winner=team;state=GameplayGameStateTypes.GAMESTATE_OVER;wins=wins+1 end}
Modding={OpenSaveData=function() return {GetValue=function(k) return storage[k] end,SetValue=function(k,v) storage[k]=v end} end}
Locale={ConvertTextKey=function(key,...) local t={key};for _,v in ipairs({...}) do t[#t+1]=tostring(v) end;return table.concat(t,'|') end}
NotificationTypes={NOTIFICATION_GENERIC=0}
local function city(index,science)
    local c={id=index,x=index*2,y=5,founded=0,science=science or 10000,buildings={},process=-1}
    function c:GetID() return self.id end
    function c:GetX() return self.x end
    function c:GetY() return self.y end
    function c:GetGameTurnFounded() return self.founded end
    function c:GetName() return 'City '..self.id end
    function c:GetNumBuilding(b) return self.buildings[b] or 0 end
    function c:GetProductionProcess() return self.process end
    function c:GetYieldRateTimes100(y) assert(y==id('YIELD_SCIENCE'));return self.science end
    function c:IsResistance() return self.resistance or false end
    function c:IsRazing() return self.razing or false end
    return c
end
local function unit(name)
    local u={type=id(name),promotions={},writes=0}
    function u:GetUnitType() return self.type end
    function u:IsHasPromotion(p) return self.promotions[p] or false end
    function u:SetHasPromotion(p,v) self.promotions[p]=v;self.writes=self.writes+1 end
    return u
end
local function iterator(rows)
    local n=0;return function() n=n+1;return rows[n] end
end
local function player(team,cities,human)
    local p={team=team,cities=cities,units={},human=human,alive=true,notifications=0}
    function p:IsAlive() return self.alive end
    function p:IsHuman() return self.human end
    function p:IsMinorCiv() return self.minor or false end
    function p:IsBarbarian() return false end
    function p:IsAnarchy() return self.anarchy or false end
    function p:GetTeam() return self.team end
    function p:Cities() return iterator(self.cities) end
    function p:Units() return iterator(self.units) end
    function p:GetCityByID(index) for _,c in ipairs(self.cities) do if c.id==index then return c end end end
    function p:GetUnitByID(index) return self.units[index] end
    function p:AddNotification(...) self.notifications=self.notifications+1 end
    return p
end
local function team()
    local t={techs={},projects={}}
    function t:IsHasTech(tech) return self.techs[tech] or false end
    function t:GetProjectCount(project) return self.projects[project] or 0 end
    for _,row in ipairs(data.Technologies) do t.techs[id(row.Type)]=true end
    return t
end
local a,b,c,d=city(0,12345),city(1,20000),city(2,50000),city(3,30000)
Players={[0]=player(0,{a,b},true),[1]=player(1,{c},false),[2]=player(0,{d},false),[3]=player(2,{},false)}
Players[3].minor=true
Teams={[0]=team(),[1]=team(),[2]=team()}
local dc,sc,cc=id('BUILDING_REFINED_DATA_CENTER'),id('BUILDING_REFINED_SUPERCOMPUTER'),id('BUILDING_REFINED_BATTLE_COMMAND')
local learning=id('PROCESS_REFINED_LEARNING')
local universal=id('PROJECT_REFINED_UNIVERSAL_AI')
local promo=id('PROMOTION_REFINED_NETWORK_COMMAND')
local mars={}
for _,name in ipairs({'RECON','TRANSPORT','HABITAT','COLONY'}) do mars[#mars+1]=id('PROJECT_REFINED_MARS_'..name) end
for _,x in ipairs({a,b,c,d}) do x.buildings[dc]=1 end
local function load()
    resetEvents();dofile('mod/Lua/Victories.lua')
end
local function progress(teamID) return storage['refined.v8.victory.team.'..teamID..'.progress'] or 0 end
local function nativeValidate(playerID)
    for _,city in ipairs(Players[playerID].cities) do
        if city.process==learning then GameEvents.CityCanMaintain.Test(playerID,city.id,learning) end
    end
end
local function tick(playerID)
    turn=turn+1;nativeValidate(playerID);GameEvents.PlayerDoTurn.Fire(playerID)
end
load()
Events.SerialEventEnterCityScreen.Fire();Events.SerialEventCityInfoDirty.Fire();ContextPtr.update(.5)
assert(Controls.VictoryPanel.hidden)
Events.SerialEventExitCityScreen.Fire();ContextPtr.update(.5);assert(not Controls.VictoryPanel.hidden)
-- Native content conditions: no global unlock from just possessing a technology.
assert(GameEvents.CityCanCreate.Test(0,0,mars[1]))
assert(not GameEvents.CityCanCreate.Test(0,0,mars[2]))
assert(not GameEvents.CityCanCreate.Test(0,0,universal))
assert(not GameEvents.CityCanMaintain.Test(0,0,learning))
for i=1,3 do Teams[0].projects[mars[i]]=1 end
assert(GameEvents.CityCanCreate.Test(0,0,mars[4]))
b.buildings[dc]=nil
assert(not GameEvents.CityCanCreate.Test(0,1,mars[4]))
assert(not GameEvents.CityCanConstruct.Test(0,1,sc))
assert(not GameEvents.CityCanConstruct.Test(0,1,cc))
assert(GameEvents.CityCanCreate.Test(0,0,id('PROJECT_APOLLO_PROGRAM')))
enabled=false;assert(not GameEvents.CityCanCreate.Test(0,0,mars[4]));enabled=true
b.buildings[dc]=1;a.buildings[sc]=1
assert(GameEvents.CityCanCreate.Test(0,1,universal)) -- center may be elsewhere.
Teams[0].projects[universal]=1
Teams[0].techs[id('TECH_REFINED_RECURSIVE')]=false
assert(not GameEvents.CityCanMaintain.Test(0,0,learning))
Teams[0].techs[id('TECH_REFINED_RECURSIVE')]=true
assert(GameEvents.CityCanMaintain.Test(0,0,learning))
a.process=learning;b.process=learning
tick(0);assert(progress(0)==32345) -- exact hundredths; no rounding per city.
GameEvents.PlayerDoTurn.Fire(0);assert(progress(0)==32345)
for i=1,20 do
    nativeValidate(0);Events.SerialEventCityInfoDirty.Fire();ContextPtr.update(.5)
end
assert(progress(0)==32345) -- menus, polling and validation never grant work.
load();GameEvents.PlayerDoTurn.Fire(0);assert(progress(0)==32345)
tick(0);assert(progress(0)==64690) -- save/load preserves both work and last turn.
b.process=-1;tick(0);assert(progress(0)==77035)
b.process=learning;b.buildings[dc]=nil;tick(0);assert(progress(0)==89380)
b.buildings[dc]=1;a.buildings[sc]=nil
tick(0);assert(progress(0)==89380) -- lost center pauses without wiping progress.
assert(not GameEvents.CityCanMaintain.Test(0,0,learning))
a.buildings[sc]=1;a.resistance=true;b.razing=true
tick(0);assert(progress(0)==89380)
a.resistance=false;b.razing=false
turn=turn+1;Players[0].anarchy=true;nativeValidate(0)
Players[0].anarchy=false -- native PlayerDoTurn is after the anarchy counter ticks.
GameEvents.PlayerDoTurn.Fire(0);assert(progress(0)==89380)
turn=turn+1;nativeValidate(0);a.process=-1;b.process=-1
GameEvents.PlayerDoTurn.Fire(0);assert(progress(0)==89380) -- changed queue cannot use old snapshot.
-- Teammates share projects/progress, but each player's work is credited once.
d.process=learning;nativeValidate(2);GameEvents.PlayerDoTurn.Fire(2)
assert(progress(0)==119380)
GameEvents.PlayerDoTurn.Fire(2);assert(progress(0)==119380)
-- The same process is available and effective for an AI, with no forced strategy.
c.buildings[sc]=1;Teams[1].projects[universal]=1;c.process=learning
turn=turn+1;GameEvents.PlayerDoTurn.Fire(1)
assert(progress(1)==0) -- newly chosen order with no worked/validated turn.
tick(1);assert(progress(1)==50000)
-- Ownership changes do not transfer earlier work snapshots.
Players[0].cities={b};Players[1].cities={c,a};a.process=learning
GameEvents.CityCaptureComplete.Fire(0,0,0,1)
turn=turn+1;GameEvents.PlayerDoTurn.Fire(1);assert(progress(1)==50000)
Players[0].cities={a,b};Players[1].cities={c}

-- Existing, newly created, upgraded and captured conventional units, all domains.
for _,name in ipairs({'UNIT_INFANTRY','UNIT_ARCHER','UNIT_BATTLESHIP','UNIT_FIGHTER','UNIT_WORKER','UNIT_ATOMIC_BOMB'}) do
    Players[0].units[#Players[0].units+1]=unit(name)
end
a.buildings[cc]=1;Events.SerialEventCityInfoDirty.Fire();ContextPtr.update(.5)
for i,u in ipairs(Players[0].units) do assert(u:IsHasPromotion(promo)==(i<=4)) end
local writes=Players[0].units[1].writes
load();assert(Players[0].units[1].writes==writes)
Players[0].units[1].type=id('UNIT_MECHANIZED_INFANTRY')
GameEvents.UnitSetXY.Fire(0,1);assert(Players[0].units[1]:IsHasPromotion(promo))
Players[0].units[7]=unit('UNIT_TANK');GameEvents.UnitSetXY.Fire(0,7)
assert(Players[0].units[7]:IsHasPromotion(promo))
-- Each civilization can own its national command center simultaneously.
c.buildings[cc]=1;Players[1].units={unit('UNIT_INFANTRY')}
Events.SequenceGameInitComplete.Fire()
assert(Players[0].units[1]:IsHasPromotion(promo))
assert(Players[1].units[1]:IsHasPromotion(promo))
-- The engine destroys the national wonder on capture; no transfer to the conqueror.
a.buildings[cc]=nil;c.buildings[cc]=nil
GameEvents.CityCaptureComplete.Fire(0,0,0,1)
for _,u in ipairs(Players[0].units) do assert(not u:IsHasPromotion(promo)) end
assert(not Players[1].units[1]:IsHasPromotion(promo))
-- A city founded after the late technologies participates without reloading.
local newborn=city(4,25000);newborn.buildings[dc]=1;newborn.process=learning
Players[0].cities[#Players[0].cities+1]=newborn
local before=progress(0)
GameEvents.PlayerCityFounded.Fire(0,8,5);ContextPtr.update(.5);assert(progress(0)==before)
tick(0);assert(progress(0)==before+12345+25000)
Players[0].cities={a,b}
for _,m in ipairs(mars) do Teams[2].projects[m]=1 end
Events.SerialEventCityInfoDirty.Fire();ContextPtr.update(.5);assert(wins==0) -- minor cannot win.
-- Disabled victories / ended games cannot be overwritten by either route.
for _,m in ipairs(mars) do Teams[0].projects[m]=1 end
enabled=false;Events.SequenceGameInitComplete.Fire();assert(wins==0)
enabled=true;winner=1;Events.SequenceGameInitComplete.Fire();assert(wins==0)
winner=-1;state=GameplayGameStateTypes.GAMESTATE_EXTENDED;Events.SequenceGameInitComplete.Fire();assert(wins==0)
state=GameplayGameStateTypes.GAMESTATE_OVER;Events.SequenceGameInitComplete.Fire();assert(wins==0)
state=GameplayGameStateTypes.GAMESTATE_ON;Events.SequenceGameInitComplete.Fire()
assert(wins==1 and winner==0 and storage['refined.v8.victory.team.0.route']=='mars')
Events.SequenceGameInitComplete.Fire();assert(wins==1)

-- Speed-scaled singularity victory, exactly once, via native science victory.
for _,speed in ipairs({'GAMESPEED_STANDARD','GAMESPEED_QUICK','GAMESPEED_MARATHON'}) do
    storage={};winner=-1;state=GameplayGameStateTypes.GAMESTATE_ON;wins=0;speedType=speed
    for _,t in pairs(Teams) do for _,m in ipairs(mars) do t.projects[m]=nil end end
    local target=math.ceil(13666*GameInfo.GameSpeeds[id(speed)].ResearchPercent/100)*100
    a.process=learning;b.process=-1;d.process=-1
    a.science=target-1;a.buildings[sc]=1
    load();tick(0);assert(progress(0)==target-1 and winner<0)
    a.science=1;tick(0)
    assert(progress(0)==target and winner==0 and wins==1)
    assert(storage['refined.v8.victory.team.0.route']=='singularity')
    GameEvents.PlayerDoTurn.Fire(0);load();assert(wins==1)
end
print('PASS: shipped v8 Lua: project gates, native work snapshots, exact science, no duplicate credit, reload, AI/teams, sale/capture/anarchy, command promotions, speed and both victories')

-- Execute the modernization addin using the same stock API model.
local function project(name) return id('PROJECT_REFINED_' .. name) end
local function promotion(name) return id('PROMOTION_REFINED_' .. name) end
local drones = id('TECH_REFINED_DRONES')
local automation = id('TECH_REFINED_AUTOMATION')
local deployment, command = project('DRONE_DEPLOYMENT'), project('AUTONOMOUS_COMMAND')
local heritage, expansion, creativity = project('DIGITAL_HERITAGE'), project('CULTURAL_EXPANSION'), project('MACHINE_CREATIVITY')
local steel = id('BUILDING_REFINED_STEEL_MILL')
local steelEffect = id('BUILDING_REFINED_AUTOMATION_STEEL')
local infantry, ship, fighter = unit('UNIT_INFANTRY'), unit('UNIT_DESTROYER'), unit('UNIT_FIGHTER')
local settler, nuke = unit('UNIT_SETTLER'), unit('UNIT_ATOMIC_BOMB')

Players[0], Players[1], Players[2] = player(0,{a,b},true), player(1,{c},false), nil
Teams[0], Teams[1] = team(), team()
Teams[0].techs[drones], Teams[0].techs[automation] = false, false
Teams[1].techs[drones] = false
Players[0].units = {infantry,ship,fighter,settler,nuke}
Players[1].units = {unit('UNIT_INFANTRY')}
for _,city in ipairs({a,b,c}) do
    city.works = 0
    city.GetNumRealBuilding = city.GetNumBuilding
    function city:SetNumRealBuilding(building,count) self.buildings[building]=count end
    function city:GetNumGreatWorks() return self.works end
end
for index = 0, 1 do
    local p = Players[index]
    p.freeCulture, p.cityCulture, p.minorCulture = 5, 70, 25
    function p:GetCapitalCity() return self.cities[1] end
    function p:GetJONSCulturePerTurnFromCities() return self.cityCulture end
    function p:GetJONSCulturePerTurnFromExcessHappiness() return 0 end
    function p:GetJONSCulturePerTurnFromTraits() return 0 end
    function p:GetJONSCulturePerTurnForFree() return self.freeCulture end
    function p:GetCulturePerTurnFromMinorCivs() return self.minorCulture end
    function p:GetCulturePerTurnFromReligion() return 0 end
    function p:ChangeJONSCulturePerTurnForFree(delta) self.freeCulture=self.freeCulture+delta end
    function p:GetTotalJONSCulturePerTurn() return self.cityCulture+self.minorCulture+self.freeCulture end
end
local function tourism(city)
    local total = 0
    for _,carrier in ipairs(data.Refined_TourismCarriers) do
        total = total + carrier.Weight * city:GetNumRealBuilding(id(carrier.Type))
    end
    return total
end
local function loadModernization()
    resetEvents()
    dofile('mod/Lua/Modernization.lua')
end

storage={}
a.buildings[steel]=1
a.buildings[dc]=1
b.buildings[dc]=0
a.works,b.works=2,3
enabled=false -- No science victory required.
loadModernization()
assert(not GameEvents.CityCanCreate.Test(0,a.id,deployment))
assert(GameEvents.CityCanCreate.Test(0,a.id,expansion))
assert(not GameEvents.CityCanCreate.Test(0,b.id,expansion))
assert(not GameEvents.CityCanCreate.Test(0,b.id,creativity))
assert(a:GetNumBuilding(steelEffect)==0 and tourism(a)==0)

Teams[0].techs[drones], Teams[0].techs[automation] = true, true
GameEvents.TeamSetHasTech.Fire(0,drones,true)
assert(GameEvents.CityCanCreate.Test(0,a.id,deployment))
assert(infantry:IsHasPromotion(promotion('DRONES')) and not ship:IsHasPromotion(promotion('DRONES')))
assert(a:GetNumBuilding(steelEffect)==1 and b:GetNumBuilding(steelEffect)==0)
Teams[0].projects[deployment],Teams[0].projects[command]=1,1
Teams[0].projects[heritage],Teams[0].projects[expansion],Teams[0].projects[creativity]=1,1,1
GameEvents.PlayerDoTurn.Fire(0)
assert(not GameEvents.CityCanCreate.Test(0,b.id,deployment))
assert(GameEvents.CityCanCreate.Test(1,c.id,command))
assert(Players[0].freeCulture==25 and Players[1].freeCulture==5)
assert(tourism(a)==20 and tourism(b)==3 and tourism(c)==0)
assert(infantry:IsHasPromotion(promotion('DRONE_DEPLOYMENT')))
assert(infantry:IsHasPromotion(promotion('AUTONOMOUS_COMMAND')))
for _,u in ipairs({ship,fighter}) do
    assert(u:IsHasPromotion(promotion('AUTONOMOUS_COMMAND')))
    assert(not u:IsHasPromotion(promotion('DRONE_DEPLOYMENT')))
end
for _,u in ipairs({settler,nuke,Players[1].units[1]}) do
    assert(not u:IsHasPromotion(promotion('AUTONOMOUS_COMMAND')))
end

local upgraded = unit('UNIT_MECHANIZED_INFANTRY')
Players[0].units[1]=upgraded
GameEvents.UnitSetXY.Fire(0,1)
assert(upgraded:IsHasPromotion(promotion('DRONES')))
assert(upgraded:IsHasPromotion(promotion('DRONE_DEPLOYMENT')))
assert(upgraded:IsHasPromotion(promotion('AUTONOMOUS_COMMAND')))
local writes = upgraded.writes
loadModernization()
assert(Players[0].freeCulture==25 and upgraded.writes==writes)

a.resistance=true
Events.SerialEventCityInfoDirty.Fire()
ContextPtr.update(.5)
assert(tourism(a)==2 and tourism(b)==21)
a.resistance=false

a.works,b.works=1,4
a.buildings[dc],a.buildings[steel]=0,0
Players[0].minorCulture=15
Events.SerialEventCityInfoDirty.Fire()
ContextPtr.update(.5)
assert(Players[0].freeCulture==23 and tourism(a)==17 and tourism(b)==4)
assert(a:GetNumBuilding(steelEffect)==0)
Players[0].cities,Players[1].cities={b},{c,a}
Players[0].units[1]=unit('UNIT_INFANTRY')
Players[1].units[2]=upgraded
GameEvents.CityCaptureComplete.Fire()
assert(tourism(a)==0 and tourism(b)==20 and Players[0].freeCulture==23)
assert(not upgraded:IsHasPromotion(promotion('AUTONOMOUS_COMMAND')))
assert(Players[0].units[1]:IsHasPromotion(promotion('AUTONOMOUS_COMMAND')))
Players[3].units[1]=Players[0].units[1]
Players[0].units[1]=nil
GameEvents.UnitSetXY.Fire(3,1)
assert(not Players[3].units[1]:IsHasPromotion(promotion('AUTONOMOUS_COMMAND')))
print('PASS: modernization Lua: project gates, military scope, upgrades, independent civilizations, tourism, culture, reload and capture')
