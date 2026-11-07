include("RefinedEventSources")

RefinedSocietyEvents = {}
function RefinedSocietyEvents.Connect(bus)
    RefinedEventSources.Event(bus, GameEvents.PlayerCityFounded, 'CityFounded')
    RefinedEventSources.Event(bus, GameEvents.PlayerDoTurn, 'PlayerTurn')
    RefinedEventSources.Event(bus, GameEvents.TeamSetHasTech, 'TeamTechnologyChanged')
    RefinedEventSources.Event(bus, GameEvents.TeamTechResearched, 'TeamTechnologyResearched')
    RefinedEventSources.Event(bus, GameEvents.CityCaptureComplete, 'CityCaptured')
    RefinedEventSources.Event(bus, GameEvents.PlayerAdoptPolicy, 'PolicyAdopted')
    RefinedEventSources.Event(bus, GameEvents.UnitSetXY, 'UnitPositionChanged')
    RefinedEventSources.Event(bus, GameEvents.SetAlly, 'AllianceChanged')
    RefinedEventSources.Event(bus, Events.WarStateChanged, 'WarStateChanged')
    RefinedEventSources.Event(bus, Events.SerialEventCityInfoDirty, 'CityInfoChanged')
    RefinedEventSources.Event(bus, Events.SequenceGameInitComplete, 'GameInitialized')
    RefinedEventSources.Update(bus)
    bus:Publish('Loaded')
end
