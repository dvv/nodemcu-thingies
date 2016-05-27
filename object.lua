------------------------------------------------------------------------------
-- Object core module
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
--
-- Example:
-- require("object")
-- o = object({ a = 1 })
-- o:on("data", function(self, data) print("DATA", data, self.a) end)
-- o:emit("data", "b")
------------------------------------------------------------------------------

-- attach event handler
local addEventHandler = function(self, event, handler)
  -- TODO: multiple?
  self._handlers[event] = handler
end

-- remove event handler
local removeEventHandler = function(self, event, handler)
  -- TODO: multiple?
  self._handlers[event] = nil
end

-- emit event
local emit = function(self, event, ...)
  local handler = self._handlers[event]
  -- TODO: multiple?
  if handler then
    handler(self, ...)
  end
end

-- attach one-time (optionally expiring) event handler
local once = function(self, event, handler, timeout)
  local fired
  self:addEventHandler(event, function(self, ...)
    if not fired then
      fired = true
      handler(self, ...)
    end
    self:removeEventHandler(event, handler)
  end)
  if timeout then
    setTimeout(timeout, function()
      if not fired then
        fired = true
        handler(self, "expired")
      end
      self:removeEventHandler(event, handler)
    end)
  end
end

local meta = {
  __index = {
    addEventHandler = addEventHandler,
    emit = emit,
    on = addEventHandler,
    once = once,
    removeEventHandler = removeEventHandler,
  },
--  __newindex = function(t, k, v)
--    if t._handlers
--  end,
}

function object(t)
  local self = setmetatable(t or { }, {
    __index = setmetatable({
      _handlers = { },
    }, meta)
  })
  return self
end

function extend(o, t)
  return setmetatable(t or {}, {
    __index = o,
  })
end
