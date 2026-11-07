include("RefinedEventSources")

RefinedModernizationEvents = {}
function RefinedModernizationEvents.Connect(bus)
    RefinedEventSources.Query(bus, GameEvents.CityCanCreate, 'CanCreateProject')
    RefinedEventSources.Event(bus, GameEvents.PlayerDoTurn, 'PlayerTurn')
    RefinedEventSources.Event(bus, GameEvents.TeamSetHasTech, 'TeamTechnologyChanged')
    RefinedEventSources.Event(bus, GameEvents.PlayerCityFounded, 'CityFounded')
    RefinedEventSources.Event(bus, GameEvents.CityCaptureComplete, 'CityCaptured')
    RefinedEventSources.Event(bus, GameEvents.UnitSetXY, 'UnitPositionChanged')
    RefinedEventSources.Event(bus, Events.SerialEventCityInfoDirty, 'CityInfoChanged')
    RefinedEventSources.Event(bus, Events.SequenceGameInitComplete, 'GameInitialized')
    RefinedEventSources.Update(bus)
    bus:Publish('Loaded')
end
