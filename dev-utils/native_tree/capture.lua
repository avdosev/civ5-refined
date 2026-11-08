-- Recorder for the UI API used by the external, unmodified BNW TechTree.
-- No connector algorithm lives here: the external script creates every pipe.
local serial = 0
recorded = { instances = {}, events = {}, calls = {} }
local function copy(t)
    local r = {}; for k,v in pairs(t or {}) do r[k]=v end; return r
end
local methods = {}
local function nativeOrigin()
    for level=3,8 do
        local info=debug.getinfo(level,'Sl')
        if not info then break end
        if string.find(info.source or '', 'TechTree',1,true) then
            local values={}
            for index=1,100 do
                local name,value=debug.getlocal(level,index)
                if not name then break end
                values[name]=value
            end
            local row=values.row
            if type(row)=='table' and row.TechType and row.PrereqTech then
                return {kind='edge',parent=row.PrereqTech,child=row.TechType,line=info.currentline}
            end
            local pipe=values.thisPipe
            if type(pipe)=='table' and pipe.techType then
                return {kind='adapter',node=pipe.techType,line=info.currentline}
            end
            local tech=values.tech
            if type(tech)=='table' and tech.Type then
                return {kind='card',node=tech.Type,line=info.currentline}
            end
        end
    end
    return {kind='other'}
end
function methods:SetOffsetVal(x,y) self.offset={x=x,y=y} end
function methods:SetOffset(v) self.offset=copy(v) end
function methods:SetSize(v) self.size=copy(v) end
function methods:SetSizeVal(x,y) self.size={x=x,y=y} end
function methods:SetSizeX(x) self.size.x=x end
function methods:SetSizeY(y) self.size.y=y end
function methods:GetSize()
    local s=copy(self.size)
    if s.x=='Full' or s.x=='full' then s.x=self.parent:GetSize().x end
    if s.y=='Full' or s.y=='full' then s.y=self.parent:GetSize().y end
    return s
end
function methods:GetSizeX() return self:GetSize().x end
function methods:GetSizeY() return self:GetSize().y end
function methods:SetTexture(t) self.texture=t end
function methods:SetTextureOffset(v) self.textureOffset=copy(v) end
function methods:SetTextureOffsetVal(x,y) self.textureOffset={x=x,y=y} end
function methods:SetHide(b) self.hidden=b end
function methods:IsHidden() return self.hidden end
function methods:SetText(t) self.text=tostring(t) end
function methods:SetToolTipString(t) self.tooltip=t end
function methods:SetVoid1(v)
    if rawget(self,'firstVoid1')==nil then self.firstVoid1=v end
    self.void1=v
end
function methods:SetVoid2(v) self.void2=v end
function methods:SetVoids(a,b) self.void1=a;self.void2=b end
function methods:SetColor(v) self.color=v end
function methods:SetAlpha(v) self.alpha=v end
function methods:SetPercent(v) self.percent=v end
function methods:SetDisabled(v) self.disabled=v end
function methods:SetToolTipType(v) self.tooltipType=v end
function methods:SetToolTipCallback(v) self.tooltipCallback=v end
function methods:RegisterCallback(k,v) end
function methods:ClearCallback(k) end
function methods:CalculateSize()
    if self.tag=='Stack' then
        local x,y=0,0
        for _,child in ipairs(self.children) do
            local s=child:GetSize()
            if self.attrs.StackGrowth=='Right' then x=x+s.x;y=math.max(y,s.y)
            else y=y+s.y;x=math.max(x,s.x) end
        end
        self.size={x=x,y=y}
    end
end
function methods:ReprocessAnchoring() end
function methods:CalculateInternalSize() end
function methods:GetScrollValue() return 0 end
function methods:GetRatio() return 1 end
function methods:SetScrollValue(v) self.scroll=v end
function methods:RegisterAnimCallback(v) end
function methods:SetToBeginning() end
function methods:Play() end
function methods:Pause() end

local function newControl(spec,parent,controls)
    serial=serial+1
    local c=setmetatable({serial=serial,id=spec.id,tag=spec.tag,attrs=spec.attrs,
        offset=copy(spec.offset),size=copy(spec.size),texture=spec.attrs.Texture,
        textureOffset=copy(spec.textureOffset),hidden=spec.hidden or false,
        children={},parent=parent}, {__index=function(_,k)
            if methods[k] then return methods[k] end
            error('Unsupported UI method: '..tostring(k)..' on '..tostring(spec.id))
        end})
    if spec.id then controls[spec.id]=c end
    for _,s in ipairs(spec.children) do
        c.children[#c.children+1]=newControl(s,c,controls)
    end
    return c
end

Controls={}
screenRoot=newControl(XML_SCREEN,nil,Controls)
InstanceManager={}
function InstanceManager:new(template,rootId,parent)
    return {GetInstance=function()
        local controls={}
        local roots={}
        local origin=nativeOrigin()
        for _,s in ipairs(XML_INSTANCES[template]) do
            roots[#roots+1]=newControl(s,parent,controls)
            roots[#roots].origin=origin
            parent.children[#parent.children+1]=roots[#roots]
        end
        recorded.instances[#recorded.instances+1]={template=template,rootId=rootId,
            controls=controls,roots=roots}
        return controls
    end}
end

GameInfo=setmetatable({}, {__index=function(self,name)
    local index={}
    for _,row in ipairs(DB_QUERY(name,nil)) do
        if row.Type then index[row.Type]=row end
        if row.ID then index[row.ID]=row end
    end
    setmetatable(index,{__call=function(_,condition)
        local rows=DB_QUERY(name,condition);local i=0
        return function() i=i+1;return rows[i] end
    end})
    rawset(self,name,index);return index
end})
GameInfoTypes=setmetatable({}, {__index=function(_,k) return DB_TYPE(k) end})
Vector2=function(x,y) return {x=x,y=y} end
Game={GetActivePlayer=function() return 0 end,GetActiveTeam=function() return 0 end,
    IsOption=function() return false end,GetGameSpeedType=function() return 2 end}
PreGame={GetGameOption=function() return 0 end}
Players={[0]={}}
local player=Players[0]
function player:GetCivilizationType() return CIVILIZATION_ID end
function player:GetTeam() return 0 end
function player:GetNumFreeTechs() return 0 end
function player:GetResearchTurnsLeft() return 0 end
function player:CanResearch(id) return RESEARCHABLE[id] or false end
function player:CanResearchForFree() return false end
function player:CanEverResearch() return true end
function player:GetCurrentResearch() return -1 end
function player:GetScienceTimes100() return 10000 end
function player:GetScience() return 0 end
function player:TechKnownCount() return 0 end
function player:GetResearchProgress() return 0 end
function player:GetResearchCost() return 100 end
function player:GetQueuePosition() return -1 end
function player:IsResearchingTech() return false end
function player:GetResearchProgressTimes100() return 0 end
Teams={[0]={IsHasTech=function(_,id) return RESEARCHED[id] or false end}}
Teams[0].GetTeamTechs=function(self) return {HasTech=function(_,id) return RESEARCHED[id] or false end} end
local function enum() return setmetatable({}, {__index=function(_,k) return k end}) end
GameOptionTypes=enum();ButtonPopupTypes=enum();Mouse=enum();KeyEvents=enum();Keys=enum()
DomainTypes={DOMAIN_LAND=0,DOMAIN_SEA=1,DOMAIN_AIR=2}
PopupPriority=enum();GameDefines={MAX_MAJOR_CIVS=22}
UI={};UIManager={}
function UI.GetUnitPortraitIcon(id)
    local u=GameInfo.Units[id];return u.PortraitIndex,u.IconAtlas
end
function UIManager:GetScreenSizeVal() return SCREEN_WIDTH,SCREEN_HEIGHT end
function UIManager:GetShift() return false end
Events=setmetatable({}, {__index=function(t,k)
    local e=setmetatable({Add=function(f) recorded.events[k]=f end},
        {__call=function() end});rawset(t,k,e);return e
end})
ContextPtr={SetInputHandler=function() end,SetShowHideHandler=function() end}
Locale={ConvertTextKey=LOCALIZE,Lookup=LOCALIZE,Length=UTF8_LENGTH,TruncateString=TRUNCATE}
Locale.Compare=function(a,b) if a==b then return 0 elseif a<b then return -1 else return 1 end end
GetHelpTextForTech=function(id) return TECH_HELP(id) end
GetTechPedia=function() end
GetHelpTextForUnit=function(id) return OBJECT_HELP('Units',id) end
GetHelpTextForBuilding=function(id) return OBJECT_HELP('Buildings',id) end
GetHelpTextForImprovement=function(id) return OBJECT_HELP('Improvements',id) end
GetHelpTextForProject=function(id) return OBJECT_HELP('Projects',id) end
function IconLookup(index,size,atlas)
    local r=ATLAS_LOOKUP(index,size,atlas)
    return Vector2(r.x,r.y),r.file
end
function IconHookup(index,size,atlas,control)
    control.icon={index=index,size=size,atlas=atlas}
    local uv,file=IconLookup(index,size,atlas)
    control:SetTexture(file);control:SetTextureOffset(uv);return true
end
function include(name)
    if name=='TechButtonInclude' then
        assert(loadstring(TECH_BUTTON_SOURCE,'@TechButtonInclude.lua'))()
    elseif name=='RefinedTechTreePipes' then
        assert(loadstring(REFINED_PIPE_SOURCE,'@RefinedTechTreePipes.lua'))()
    elseif name~='InstanceManager' and name~='TechHelpInclude'
        and name~='IconSupport' and name~='InfoTooltipInclude' then
        error('Unsupported include: '..name)
    end
end

-- Export acyclic state; parent links remain internal to the control model.
function exportControl(c)
    local r={}
    for _,k in ipairs({'serial','id','tag','attrs','offset','size','texture',
        'textureOffset','hidden','text','tooltip','void1','void2','firstVoid1','icon','disabled','origin'}) do
        if rawget(c,k)~=nil then r[k]=c[k] end
    end
    r.children={};for _,v in ipairs(c.children) do r.children[#r.children+1]=exportControl(v) end
    return r
end
function exportScene()
    local out={screenSize=screenRoot:GetSize(),viewport=Controls.TechTreeScrollPanel:GetSize(),instances={}}
    for _,i in ipairs(recorded.instances) do
        local r={template=i.template,rootId=i.rootId,roots={}}
        for _,c in ipairs(i.roots) do r.roots[#r.roots+1]=exportControl(c) end
        out.instances[#out.instances+1]=r
    end
    return out
end
