------------------------------------------------------------------------------
-- Timer helpers
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
--
-- NB: occupies physical tmr #0
--
-- Example:
-- setInterval(1000, print, "many", "times") -- 1
-- setTimeout(1000, print, "one", "shot")
-- clearInterval(1)
------------------------------------------------------------------------------

--local 
handlers = { }

local function handler()
  local now = tmr.now() / 1000
  local nextTime
  local k, v = next(handlers, nil)
  while k do
    --print("DEBUG", "CHECK", now, v[1])
    -- on time?
    if now >= v[1] then
      -- callback valid?
      local fn = v[2]
      if fn then
        --print("DEBUG", "CALL", now, fn)
        -- do call
        fn(unpack(v[4]))
      end
      -- rearm if interval
      if v[3] then
        v[1] = now + v[3]
        if not nextTime or v[1] < nextTime then
          nextTime = v[1]
        end
      else
        handlers[k] = nil
      end
    -- get restart time
    else
      if not nextTime or v[1] < nextTime then
        nextTime = v[1]
      end
    end
    k, v = next(handlers, k)
  end
  -- active timers?
  if nextTime then
    --print("DEBUG", "REARM", nextTime - tmr.now() / 1000)
    nextTime = nextTime - tmr.now() / 1000
  else
    nextTime = 1000
  end
  pcall(tmr.alarm, 0, nextTime, 0, handler)
end

local new = function(repeating, timeout, fn, ...)
  local a = { ... }
  -- TODO: random names
  local n = #handlers + 1
  handlers[n] = { tmr.now() / 1000 + timeout, fn, repeating and timeout, a }
  handler()
  return n
end

setInterval = function(...)
  return new(true, ...)
end

clearInterval = function(n)
  handlers[n] = nil
  handler()
end

setTimeout = function(...)
  return new(false, ...)
end

clearTimeout = clearInterval
