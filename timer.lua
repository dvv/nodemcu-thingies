------------------------------------------------------------------------------
-- Timer helpers
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
--
-- Example:
-- setTimeout(1000, print, "one", "shot")
-- setInterval(1000, print, "many", "times") -- = 3
-- clearInterval(3)
------------------------------------------------------------------------------

do
  local timers = {}
  local new = function(repeating, timeout, handler, ...)
    local a = {...}
    local n = #timers + 1
    tmr.alarm(n, timeout, repeating, function()
      handler(unpack(a))
    end)
    -- TODO: names?
    timers[n] = n
    return n
  end
  -- NB: globals!
  setInterval = function(...)
    return new(1, ...)
  end
  clearInterval = function(n)
    tmr.unregister(n)
    timers[n] = nil
  end
  setTimeout = function(...)
    return new(0, ...)
  end
  clearTimeout = clearInterval
end
