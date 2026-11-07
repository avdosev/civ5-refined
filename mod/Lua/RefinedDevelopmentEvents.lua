include("RefinedEventSources")
include("FLuaVector")

RefinedDevelopmentEvents = {}
function RefinedDevelopmentEvents.Connect(bus)
    RefinedEventSources.Event(bus, GameEvents.UnitSetXY, 'UnitPositionChanged')
    RefinedEventSources.Event(bus, GameEvents.PlayerDoTurn, 'PlayerTurn')
    RefinedEventSources.Event(bus, GameEvents.TeamSetHasTech, 'TeamTechnologyChanged')
    RefinedEventSources.Event(bus, GameEvents.PlayerCityFounded, 'CityFounded')
    RefinedEventSources.Event(bus, GameEvents.CityCaptureComplete, 'CityCaptured')
    RefinedEventSources.Event(bus, Events.SerialEventCityInfoDirty, 'CityInfoChanged')
    RefinedEventSources.Event(bus, Events.SequenceGameInitComplete, 'GameInitialized')
    -- BuildFinished uses grid coordinates and also fires for repairs (CvPlot).
    GameEvents.BuildFinished.Add(function(playerID, x, y) bus:Publish('PlotChanged', x, y) end)
    local function hexChanged(hexX, hexY)
        local x, y = ToGridFromHex(hexX, hexY)
        bus:Publish('PlotChanged', x, y)
    end
    Events.SerialEventImprovementCreated.Add(hexChanged)
    Events.SerialEventImprovementDestroyed.Add(hexChanged)
    Events.SerialEventHexCultureChanged.Add(hexChanged)
    RefinedEventSources.Update(bus)
    bus:Publish('Loaded')
end
