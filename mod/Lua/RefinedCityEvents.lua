include("RefinedEventSources")

RefinedCityEvents = {}
function RefinedCityEvents.Connect(bus)
    RefinedEventSources.Event(bus, GameEvents.PlayerDoTurn, 'PlayerTurn')
    RefinedEventSources.Event(bus, GameEvents.TeamSetHasTech, 'TeamTechnologyChanged')
    RefinedEventSources.Event(bus, GameEvents.PlayerCityFounded, 'CityFounded')
    RefinedEventSources.Event(bus, GameEvents.CityCaptureComplete, 'CityCaptured')
    RefinedEventSources.Event(bus, Events.SerialEventCityInfoDirty, 'CityInfoChanged')
    RefinedEventSources.Event(bus, Events.SequenceGameInitComplete, 'GameInitialized')
    bus:Publish('Loaded')
end
