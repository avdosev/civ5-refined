-- Refined controller for the game's existing TechTree.xml. Authored here;
-- stock game UI sources/textures are resolved by include and are not bundled.
include('InstanceManager')
g_UseSmallIcons = true
include('TechButtonInclude')
include('TechHelpInclude')
include('RefinedTechTreePipes')

local pipes = InstanceManager:new('TechPipeInstance', 'TechPipeIcon', Controls.TechTreeScrollPanel)
local eras = InstanceManager:new('EraBlockInstance', 'EraBlock', Controls.EraStack)
local buttons = InstanceManager:new('TechButtonInstance', 'TechButton', Controls.TechTreeScrollPanel)
local cards, panels, ranges = {}, {}, {}
local player, team, civType
local opened, popup, stealFrom = false, nil, -1
local rebuildIcons = false
local pendingFreeChoice = false
local states = {'AlreadyResearched', 'CurrentlyResearching', 'Available', 'Unavailable', 'Locked', 'FreeTech'}
local names = {'AlreadyResearchedTechName', 'CurrentlyResearchingTechName', 'AvailableTechName',
    'UnavailableTechName', 'LockedTechName', 'FreeTechName'}

local function bindPlayer()
    player = Players[Game.GetActivePlayer()]
    team = Teams[player:GetTeam()]
    civType = GameInfo.Civilizations[player:GetCivilizationType()].Type
    GatherInfoAboutUniqueStuff(civType)
end

function TechSelected(id)
    if id < 0 or pendingFreeChoice or Game.IsOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE) then return end
    local freeCount = stealFrom == -1 and player:GetNumFreeTechs() or 0
    pendingFreeChoice = freeCount > 0 and player:CanResearchForFree(id)
    Network.SendResearch(id, freeCount,
        stealFrom, UIManager:GetShift())
end

local function setState(card, state)
    for _, name in ipairs(states) do card[name]:SetHide(name ~= state) end
end

function RefreshDisplay()
    local highestEra = 0
    local disabled = Game.IsOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE)
    for tech in GameInfo.Technologies() do
        local id, card = tech.ID, cards[tech.ID]
        if rebuildIcons then AddSmallButtonsToTechButton(card, tech, 5, 45) end
        card.TechButton:SetToolTipString(GetHelpTextForTech(id))
        local known = team:GetTeamTechs():HasTech(id)
        local stealing = stealFrom ~= -1
        local allowedSteal = stealing and player:CanResearch(id)
            and Teams[Players[stealFrom]:GetTeam()]:IsHasTech(id)
            and player:GetNumTechsToSteal(stealFrom) > 0
        local free = player:GetNumFreeTechs() > 0 and player:CanResearchForFree(id)
        local state
        if known then
            state = 'AlreadyResearched'
            highestEra = math.max(highestEra, GameInfo.Eras[tech.Era].ID)
        elseif stealing and not allowedSteal or not player:CanEverResearch(id) then
            state = 'Locked'
        elseif not disabled and (free or allowedSteal) then
            state = 'FreeTech'
        elseif player:GetCurrentResearch() == id then
            state = 'CurrentlyResearching'
        elseif not disabled and player:CanResearch(id) then
            state = 'Available'
        elseif player:GetNumFreeTechs() > 0 then
            state = 'Locked'
        else
            state = 'Unavailable'
        end
        setState(card, state)
        local clickID = (known or disabled or state == 'Locked') and -1 or id
        card.TechButton:SetVoid1(clickID)
        card.TechButton:SetVoid2(player:GetNumFreeTechs())
        AddCallbackToSmallButtons(card, 5, clickID, player:GetNumFreeTechs(), Mouse.eLClick, TechSelected)
        local turnText = tostring(player:GetResearchTurnsLeft(id, true)) .. ' ' .. Locale.ConvertTextKey('TXT_KEY_TURNS')
        for _, label in ipairs({'CurrentlyResearchingTurns', 'AvailableTurns', 'UnavailableTurns', 'FreeTurns'}) do
            card[label]:SetText(turnText)
            card[label]:SetHide(disabled or player:GetScience() <= 0 or stealing)
        end
        local queue = player:GetQueuePosition(id)
        local queueText
        if state == 'FreeTech' then queueText = Locale.ConvertTextKey('TXT_KEY_FREE')
        elseif state == 'Locked' then queueText = '[ICON_LOCKED]'
        elseif not known and state ~= 'CurrentlyResearching' and queue ~= -1 then queueText = tostring(queue - 1) end
        card.TechQueue:SetHide(queueText == nil)
        if queueText then card.TechQueueLabel:SetText(queueText) end
    end
    for id, panel in pairs(panels) do
        panel.OldBar:SetHide(id >= highestEra)
        panel.CurrentBlock:SetHide(id ~= highestEra)
        panel.CurrentTop:SetHide(id ~= highestEra)
        panel.FutureBlock:SetHide(id <= highestEra)
    end
    rebuildIcons = false
end

local function initialize()
    bindPlayer()
    Controls.TechTreeScrollBar:SetSizeX(Controls.TechTreeScrollPanel:GetSize().x - 150)
    for tech in GameInfo.Technologies() do
        local eraID = GameInfo.Eras[tech.Era].ID
        local range = ranges[eraID]
        if not range then ranges[eraID] = {tech.GridX, tech.GridX}
        else range[1] = math.min(range[1], tech.GridX); range[2] = math.max(range[2], tech.GridX) end
    end
    for era in GameInfo.Eras() do
        local panel = eras:GetInstance()
        panels[era.ID] = panel
        local range = ranges[era.ID]
        local width = (range and range[2] - range[1] + 1 or 1) * 366 + (era.ID == 0 and 32 or 0)
        for _, name in ipairs({'OldLabel', 'CurrentLabel', 'FutureLabel'}) do panel[name]:SetText(Locale.ConvertTextKey(era.Description)) end
        for _, name in ipairs({'EraBlock', 'FrameBottom', 'OldBar', 'OldBlock', 'CurrentBlock',
            'CurrentBlock1', 'CurrentBlock2', 'CurrentTop', 'CurrentTop1', 'CurrentTop2', 'FutureBlock'}) do
            panel[name]:SetSizeX(width)
        end
    end
    DrawRefinedTechTreePipes(pipes)
    techPediaSearchStrings = {}
    for tech in GameInfo.Technologies() do
        local card = buttons:GetInstance()
        cards[tech.ID] = card
        card.TechButton:SetVoid1(tech.ID)
        card.TechButton:SetVoid2(0)
        card.TechButton:SetOffsetVal(tech.GridX * 366 + 64, (tech.GridY - 5) * 68 + 32)
        card.TechButton:RegisterCallback(Mouse.eLClick, TechSelected)
        card.TechButton:RegisterCallback(Mouse.eRClick, GetTechPedia)
        techPediaSearchStrings[tostring(card.TechButton)] = tech.Description
        local name = Locale.TruncateString(Locale.ConvertTextKey(tech.Description),
            22 - Locale.Length(Locale.Lookup('TXT_KEY_TURNS')), true)
        for _, label in ipairs(names) do card[label]:SetText(name) end
        card.TechPortrait:SetHide(not IconHookup(tech.PortraitIndex, 64, tech.IconAtlas, card.TechPortrait))
        AddSmallButtonsToTechButton(card, tech, 5, 45)
    end
    Controls.EraStack:CalculateSize()
    Controls.EraStack:ReprocessAnchoring()
    Controls.TechTreeScrollPanel:CalculateInternalSize()
end

function OnCloseButtonClicked()
    UIManager:DequeuePopup(ContextPtr)
    if opened then Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_TECH_TREE, 0) end
    opened = false
end

function OnDisplay(info)
    if info.Type ~= ButtonPopupTypes.BUTTONPOPUP_TECH_TREE then return end
    if info.Data1 == 1 and not ContextPtr:IsHidden() then OnCloseButtonClicked(); return end
    popup, stealFrom, opened = info, info.Data2 or -1, true
    UIManager:QueuePopup(ContextPtr, info.Data1 == 1 and PopupPriority.eUtmost or PopupPriority.TechTree)
    Events.SerialEventGameMessagePopupShown(popup)
    RefreshDisplay()
end

Events.SerialEventGameMessagePopup.Add(OnDisplay)
Events.SerialEventResearchDirty.Add(function()
    pendingFreeChoice = false
    if opened then RefreshDisplay() end
end)
Events.GameplaySetActivePlayer.Add(function()
    bindPlayer()
    pendingFreeChoice = false
    rebuildIcons = true
    OnCloseButtonClicked()
end)
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnCloseButtonClicked)
ContextPtr:SetInputHandler(function(message, key)
    if opened and message == KeyEvents.KeyDown and (key == Keys.VK_ESCAPE or key == Keys.VK_RETURN) then
        OnCloseButtonClicked(); return true
    end
end)
ContextPtr:SetShowHideHandler(function(hidden, initial)
    if not initial then
        if hidden then UI.decTurnTimerSemaphore() else UI.incTurnTimerSemaphore() end
    end
end)
initialize()
