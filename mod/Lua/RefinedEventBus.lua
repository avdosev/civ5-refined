-- Context-local, synchronous dispatch. No engine subscriptions or gameplay here.
-- Each UI addin owns a bus; no dependency on cross-context load order.
RefinedEventBus = {}
function RefinedEventBus.Create()
    local listeners, queries = {}, {}
    local bus = {}
    function bus:Subscribe(name, handler)
        assert(type(handler) == 'function', 'Refined event handler must be a function')
        listeners[name] = listeners[name] or {}
        table.insert(listeners[name], handler)
    end
    function bus:Publish(name, ...)
        for _, handler in ipairs(listeners[name] or {}) do handler(...) end
    end
    -- Engine Can* callbacks require an immediate return value, not a broadcast.
    function bus:Answer(name, handler)
        assert(not queries[name], 'Refined query already handled: ' .. name)
        queries[name] = handler
    end
    function bus:Query(name, ...)
        return assert(queries[name], 'Refined query has no handler: ' .. name)(...)
    end
    return bus
end
