-- Run through tests/run_lua.py: rules are exported from the shipped SQL.
local data = dofile(assert(arg[1]))
local storage, messages, plots, units, nextID = {}, {}, {}, {}, 0
GameInfoTypes = {}
local function register(name)
    if not GameInfoTypes[name] then nextID = nextID + 1; GameInfoTypes[name] = nextID end
    return GameInfoTypes[name]
end
for _, name in ipairs({'IMPROVEMENT_FARM','IMPROVEMENT_MINE','IMPROVEMENT_QUARRY','IMPROVEMENT_PASTURE',
    'IMPROVEMENT_FISHING_BOATS','RESOURCE_FISH','RESOURCE_HORSE','RESOURCE_IRON','RESOURCE_COAL',
    'RESOURCE_URANIUM','RESOURCE_WHALE','YIELD_FOOD'}) do register(name) end
local function collection(rows)
    local c = {}
    for _, row in ipairs(rows) do row.ID = register(row.Type); c[row.ID] = row; c[row.Type] = row end
    return setmetatable(c, {__call = function()
        local n = 0
        return function() n = n + 1; return rows[n] end
    end})
end
GameInfo = {Technologies = collection(data.Technologies), Buildings = collection(data.Buildings)}
local unitRows = {}
for _, c in ipairs({'WRITER','SCIENTIST','MUSKETMAN','UNIQUE_MUSKET','WORKER'}) do
    unitRows[#unitRows+1] = {Type='UNIT_'..c, Class='UNITCLASS_'..(c=='UNIQUE_MUSKET' and 'MUSKETMAN' or c)}
end
GameInfo.Units = collection(unitRows)
GameInfo.Refined_Eurekas = function()
    local n = 0
    return function()
        n=n+1; local source=data.Refined_Eurekas[n]
        if not source then return end
        local copy={}; for k,v in pairs(source) do copy[k]=v end; return copy
    end
end
Modding = {OpenSaveData=function() return {
    GetValue=function(k) return storage[k] end,
    SetValue=function(k,v) storage[k]=v end
} end}
Locale = {ConvertTextKey = function(key, ...) return key end}
GameDefines = {MAX_CIV_PLAYERS=5}
local function event()
    local handlers={}
    return {Add=function(fn) handlers[#handlers+1]=fn end,
            Fire=function(...) for _,fn in ipairs(handlers) do fn(...) end end}
end
local update
local function resetEvents()
    GameEvents={};Events={}
    for _, name in ipairs({'UnitSetXY','PlayerDoTurn','TeamSetHasTech','PlayerCityFounded','CityCaptureComplete'}) do GameEvents[name]=event() end
    for _,name in ipairs({'SerialEventCityInfoDirty','SerialEventUnitInfoDirty','SerialEventImprovementCreated',
        'SerialEventImprovementDestroyed','SerialEventHexCultureChanged','SequenceGameInitComplete','GameplaySetActivePlayer'}) do Events[name]=event() end
    Events.GameplayAlertMessage=function(text) messages[#messages+1]=text end
    ContextPtr={SetUpdate=function(self,fn) update=fn end}
end
resetEvents()
local cityMod = 5
local yieldWrites = 0
Game={GetActivePlayer=function() return 0 end, GetNumCitiesTechCostMod=function() return cityMod end,
    SetPlotExtraYield=function(x,y,yield,delta)
        local p=Map.GetPlot(x,y);p.extra=p.extra+delta;yieldWrites=yieldWrites+1
        Events.SerialEventCityInfoDirty.Fire()
    end}
local directions={{1,0},{0,1},{-1,1},{-1,0},{0,-1},{1,-1}}
Map={GetNumPlots=function() return #plots end, GetPlotByIndex=function(i) return plots[i+1] end,
    GetPlot=function(x,y) for _,p in ipairs(plots) do if p.x==x and p.y==y then return p end end end,
    PlotDirection=function(x,y,d) local o=directions[d+1];return Map.GetPlot(x+o[1],y+o[2]) end}
local function plot(x,y,owner,improvement,resource)
    local p={x=x,y=y,owner=owner,improvement=GameInfoTypes[improvement] or -1,
             resource=GameInfoTypes[resource] or -1,pillaged=false,extra=2}
    function p:GetOwner() return self.owner end
    function p:GetImprovementType() return self.improvement end
    function p:GetResourceType(team) return self.resource end
    function p:IsImprovementPillaged() return self.pillaged end
    function p:GetX() return self.x end
    function p:GetY() return self.y end
    plots[#plots+1]=p;return p
end
local function city(id,initial)
    local c={id=id,buildings={}}
    for _,name in ipairs(initial or {}) do c.buildings[register(name)]=1 end
    function c:GetID() return self.id end
    function c:GetNumBuilding(b) return self.buildings[b] or 0 end
    return c
end
local function iterator(t) local n=0;return function() n=n+1;return t[n] end end
local function team()
    local t={known={},progress={},writes=0,overflow=0,base=101}
    function t:IsHasTech(tech) return self.known[tech] or false end
    local tt={}
    function tt:GetResearchCost(tech) return t.base end
    function tt:GetResearchProgressTimes100(tech) return t.progress[tech] or 0 end
    function tt:SetResearchProgressTimes100(tech,value,playerID)
        t.writes=t.writes+1
        local threshold=Players[playerID]:exactCost(tech)
        t.progress[tech]=value
        if value>=threshold then
            t.overflow=t.overflow+value-threshold;t.known[tech]=true
            GameEvents.TeamSetHasTech.Fire(0,tech,true)
        end
    end
    function t:GetTeamTechs() return tt end
    return t
end
Teams={[0]=team(),[1]=team(),[2]=team()}
local function player(teamID)
    local p={teamID=teamID,cities={},units={},routes={},ready={},modifier=113,effectiveCities=4}
    function p:IsAlive() return true end
    function p:IsMinorCiv() return self.minor or false end
    function p:IsBarbarian() return false end
    function p:GetTeam() return self.teamID end
    function p:Cities() return iterator(self.cities) end
    function p:Units() return iterator(self.units) end
    function p:GetUnitByID(uid) for _,u in ipairs(self.units) do if u.id==uid then return u end end end
    function p:GetTradeRoutes() return self.routes end
    function p:CanResearch(tech) return self.ready[tech] or false end
    function p:CalculateResearchModifier(tech) return self.modifier end
    function p:exactCost(tech)
        return math.floor(math.floor(Teams[self.teamID].base*10000/self.modifier)*(100+cityMod*self.effectiveCities)/100)
    end
    function p:GetResearchCost(tech) return math.ceil(self:exactCost(tech)/100) end
    return p
end
Players={[0]=player(0),[1]=player(1),[2]=player(0),[3]=player(2)}
Players[3].minor=true
local function unit(owner,kind,level)
    local u={id=#units+1,type=GameInfoTypes['UNIT_'..kind],level=level or 1}
    function u:GetUnitType() return self.type end
    function u:GetLevel() return self.level end
    units[#units+1]=u;table.insert(Players[owner].units,u);return u
end
local function saved(team,tech,field) return storage['refined.v6.team.'..team..'.TECH_'..tech..'.'..field] end
local function tick() GameEvents.PlayerDoTurn.Fire(0) end
local center=plot(0,0,0,'IMPROVEMENT_FARM')
local ring={}
for _,o in ipairs(directions) do ring[#ring+1]=plot(o[1],o[2],0,'IMPROVEMENT_FARM') end
local fish=plot(8,8,0,'IMPROVEMENT_FISHING_BOATS','RESOURCE_FISH')
local whale=plot(9,8,0,'IMPROVEMENT_FISHING_BOATS','RESOURCE_WHALE')
dofile('mod/Lua/Development.lua')
assert(center.extra==2 and fish.extra==2 and yieldWrites==0,'no early tile bonus')
Teams[0].known[GameInfoTypes.TECH_REFINED_AGRICULTURAL_MECHANIZATION]=true
Teams[0].known[GameInfoTypes.TECH_REFRIGERATION]=true
tick()
assert(center.extra==7,'six adjacent farms yield +5; preserve other +2')
assert(fish.extra==3 and whale.extra==2,'fish only')
for _,p in ipairs(ring) do assert(p.extra==4,'ring farm has three neighbors, +2') end
local writes=yieldWrites;tick();assert(yieldWrites==writes,'no accumulating writes')
ring[1].pillaged=true;fish.pillaged=true;tick()
assert(center.extra==6 and ring[1].extra==2 and fish.extra==2,'pillaged bonus removed')
ring[2].owner=1;tick();assert(center.extra==5,'foreign neighboring farm excluded')
center.improvement=GameInfoTypes.IMPROVEMENT_MINE;tick();assert(center.extra==2,'replacing farm removes food')
center.improvement=GameInfoTypes.IMPROVEMENT_FARM
ring[1].pillaged=false;ring[2].owner=0;fish.pillaged=false;tick()
assert(center.extra==7)
-- Save/load reopens storage without duplicating deltas or eureka rewards.
resetEvents();writes=yieldWrites;dofile('mod/Lua/Development.lua');assert(writes==yieldWrites,'reload must not add again')
center.owner=1;tick();assert(center.extra==2,'captured by unresearched owner')
center.owner=-1;tick();assert(center.extra==2,'unowned bonus removed')
center.owner=0;tick();assert(center.extra==7)
print('PASS: farm adjacency, foreign/pillaged/replaced/captured tiles, fish-only food, reload and additive API')

-- Infer precise native costs, award 25%, cap at fractional completion without overflow.
local workshopID=register('BUILDING_TEST_WORKSHOP')
-- Runtime class cache is constructed at script init, so add fixtures then reload.
table.insert(data.Buildings,{Type='BUILDING_TEST_WORKSHOP',BuildingClass='BUILDINGCLASS_WORKSHOP'})
table.insert(data.Buildings,{Type='BUILDING_TEST_LIBRARY',BuildingClass='BUILDINGCLASS_LIBRARY'})
table.insert(data.Buildings,{Type='BUILDING_TEST_PAPER_MAKER',BuildingClass='BUILDINGCLASS_LIBRARY'})
table.insert(data.Buildings,{Type='BUILDING_TEST_LAB',BuildingClass='BUILDINGCLASS_LABORATORY'})
GameInfo.Buildings=collection(data.Buildings)
Players[0].cities={city(0,{'BUILDING_TEST_WORKSHOP'}),city(1,{'BUILDING_TEST_WORKSHOP'})}
resetEvents();dofile('mod/Lua/Development.lua')
assert(saved(0,'INDUSTRIALIZATION','achieved')==1 and not saved(0,'INDUSTRIALIZATION','awarded'),'early achievement pending')
Players[0].cities={};tick();assert(saved(0,'INDUSTRIALIZATION','achieved')==1,'loss does not erase achievement')
local ind=GameInfoTypes.TECH_INDUSTRIALIZATION
Players[0].ready[ind]=true;tick()
assert(Teams[0].progress[ind]==math.floor(Players[0]:exactCost(ind)/4),'25% actual fractional cost')
assert(Teams[0].writes==1 and saved(0,'INDUSTRIALIZATION','awarded')==1)
tick();assert(Teams[0].writes==1,'one award per team')
Players[0].cities={city(0,{'BUILDING_TEST_LIBRARY'})}
Players[2].cities={city(0,{'BUILDING_TEST_PAPER_MAKER'})}
tick();assert(not saved(0,'EDUCATION','achieved'),'do not pool teammate buildings')
Players[0].cities[2]=city(1,{'BUILDING_TEST_PAPER_MAKER'})
local edu=GameInfoTypes.TECH_EDUCATION
Players[0].ready[edu]=true;Players[2].ready[edu]=true
Teams[0].progress[edu]=Players[0]:exactCost(edu)-37
tick();assert(Teams[0].known[edu] and Teams[0].overflow==0,'complete research with zero overflow')
assert(Teams[0].writes==2,'shared team and unique library replacement counted once')
-- AI shares conditions and uses its own cost modifiers/speed-adjusted team cost.
Players[1].modifier=97;Players[1].effectiveCities=7;Teams[1].base=307
Players[1].cities={city(0,{'BUILDING_TEST_LAB'}),city(1,{'BUILDING_TEST_LAB'})}
Players[1].ready[GameInfoTypes.TECH_COMPUTERS]=true;tick()
assert(Teams[1].progress[GameInfoTypes.TECH_COMPUTERS]==math.floor(Players[1]:exactCost(GameInfoTypes.TECH_COMPUTERS)/4))
assert(saved(1,'COMPUTERS','awarded')==1,'AI reward')
-- A writer can be expended immediately after creation; never rely on next turn.
local writer=unit(0,'WRITER');GameEvents.UnitSetXY.Fire(0,writer.id,0,0)
Players[0].units={};tick();assert(saved(0,'PRINTING_PRESS','achieved')==1,'writer milestone persists after expending')
local scientist=unit(1,'SCIENTIST');GameEvents.UnitSetXY.Fire(1,scientist.id,0,0)
Players[1].units={};tick();assert(saved(1,'SCIENTIFIC_THEORY','achieved')==1)
unit(0,'MUSKETMAN',5);unit(0,'UNIQUE_MUSKET',3)
Players[2].units={};unit(2,'MUSKETMAN')
tick();assert(not saved(0,'RIFLING','achieved'),'two muskets are insufficient, regardless of level; do not pool teammates')
unit(0,'UNIQUE_MUSKET',1);tick()
assert(saved(0,'RIFLING','achieved')==1,'three muskets including unique replacements, regardless of level')
Players[0].units={};tick()
assert(saved(0,'RIFLING','achieved')==1,'losing muskets after the milestone does not erase it')
-- Distinct destination cities, not three copies of the same destination.
local destination=city(9)
Players[0].routes={{FromID=0,ToID=1,ToCity=destination},{FromID=0,ToID=1,ToCity=destination},{FromID=0,ToID=0,ToCity=city(10)}}
tick();assert(not saved(0,'BANKING','achieved'))
Players[0].routes={{FromID=0,ToID=1,ToCity=city(0)},{FromID=0,ToID=1,ToCity=city(1)},{FromID=0,ToID=3,ToCity=city(0)}}
tick();assert(saved(0,'BANKING','achieved')==1,'distinct cities including city-state')
-- Already researched technology never grants a reward, including late start.
Teams[0].known[GameInfoTypes.TECH_CONSTRUCTION]=true
plot(20,0,0,'IMPROVEMENT_QUARRY');tick()
assert(not saved(0,'CONSTRUCTION','awarded'))
local oldWrites=Teams[0].writes
resetEvents();dofile('mod/Lua/Development.lua');assert(Teams[0].writes==oldWrites,'research reload does not reaward')
print('PASS: pending milestones, precise costs, completion without overflow, team once/no pooling, AI, GP and trade')

-- Exercise every SQL-defined condition once on a fresh team/player.
Players[4]=player(2);Players[3].minor=true
local p=Players[4]
p.cities={city(0),city(1)}
for _,row in ipairs(data.Buildings) do
    if row.BuildingClass then
        p.cities[1].buildings[GameInfoTypes[row.Type]]=1
        p.cities[2].buildings[GameInfoTypes[row.Type]]=1
    end
end
unit(4,'WRITER');unit(4,'SCIENTIST');unit(4,'MUSKETMAN');unit(4,'MUSKETMAN');unit(4,'UNIQUE_MUSKET')
for i=1,3 do plot(30+i,0,4,'IMPROVEMENT_MINE',({'RESOURCE_IRON','RESOURCE_COAL','RESOURCE_URANIUM'})[i]) end
plot(34,0,4,'IMPROVEMENT_QUARRY');plot(35,0,4,'IMPROVEMENT_PASTURE','RESOURCE_HORSE')
p.routes={{FromID=4,ToID=1,ToCity=city(0)},{FromID=4,ToID=1,ToCity=city(1)},{FromID=4,ToID=3,ToCity=city(0)}}
for _,r in ipairs(data.Refined_Eurekas) do p.ready[GameInfoTypes[r.TechType]]=true end
tick()
for _,r in ipairs(data.Refined_Eurekas) do
    assert(storage['refined.v6.team.2.'..r.TechType..'.awarded']==1,'unexercised rule: '..r.TechType)
end
assert(Teams[2].writes==19 and Teams[2].overflow==0)
cityMod=0 -- no city-cost modifier is also a native configuration
Players[0].ready[GameInfoTypes.TECH_PRINTING_PRESS]=true;tick()
assert(Teams[0].progress[GameInfoTypes.TECH_PRINTING_PRESS]==math.floor(Players[0]:exactCost(GameInfoTypes.TECH_PRINTING_PRESS)/4))
print('PASS: all 19 shipped eureka conditions, zero city-cost modifier and persistent grants')

-- Run the actual addin UI branch: status pages, open/close and active-player switch.
Controls={};Mouse={eLClick=1}
for _,name in ipairs({'Toggle','Panel','Status','Title','Close','Previous','Next','Page'}) do
    local c={hidden=name=='Panel'}
    function c:SetText(text) self.text=text end
    function c:SetToolTipString(text) self.tooltip=text end
    function c:SetHide(hidden) self.hidden=hidden end
    function c:IsHidden() return self.hidden end
    function c:RegisterCallback(event,callback) self.click=callback end
    Controls[name]=c
end
resetEvents();dofile('mod/Lua/Development.lua')
assert(Controls.Page.text=='1 / 4' and Controls.Status.text:find('TXT_KEY_REFINED_EUREKA_'))
Controls.Toggle.click();assert(not Controls.Panel.hidden)
Controls.Next.click();assert(Controls.Page.text=='2 / 4')
Controls.Next.click();Controls.Next.click();Controls.Next.click();assert(Controls.Page.text=='4 / 4')
Controls.Previous.click();assert(Controls.Page.text=='3 / 4')
Events.GameplaySetActivePlayer.Fire();assert(Controls.Panel.hidden)
print('PASS: eureka panel status rendering, pagination, toggle and active-player hiding (mock UI, not game rendering)')
