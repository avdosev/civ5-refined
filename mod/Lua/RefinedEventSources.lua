-- Translate BNW callbacks into local events without interpreting game state.
RefinedEventSources = {}
function RefinedEventSources.Event(bus, source, name)
    source.Add(function(...) bus:Publish(name, ...) end)
end
function RefinedEventSources.Query(bus, source, name)
    source.Add(function(...) return bus:Query(name, ...) end)
end
function RefinedEventSources.Update(bus)
    ContextPtr:SetUpdate(function(delta) bus:Publish('Update', delta) end)
end
