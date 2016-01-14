------------------------------------------------------------------------------
-- Buttons debouncer and reporter
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
--
-- Example:
-- pin1 = 1
-- pin2 = 2 + 128 -- NB: 128 means active high
-- dofile("buttons.lua")({pin2, pin1}, function(ev) print(cjson.encode(ev)) end, 2)
-- tmr.stop(2) -- stop
-- -- events == {{1, 1}, {2, 0}, ...} -- pin2 (index 1) activated (1),
-- --                                    pin1 (index 2) deactivated (0)
------------------------------------------------------------------------------
do
  return function(pins, reporter, timerno, interval)
    local state = {}
    local counter = {}
    for i = 1, #pins do
      local p = pins[i] --
      -- NB: p >= 128 means active high
      if p < 128 then
        gpio.mode(p, gpio.INPUT, gpio.PULLUP)
      else
        gpio.mode(p - 128, gpio.INPUT)
      end
      state[i] = 0
      counter[i] = 0
    end
    --
    local val = gpio.read
    tmr.alarm(timerno or 2, interval or 4, 1, function()
      local events = { }
      for i = 1, #state do
        local p = pins[i] --
        local s = state[i] --
        local c = counter[i] --
        -- NB: p >= 128 means active high
        local v
        if p < 128 then
          v = val(p)
        else
          v = 1 - val(p - 128)
        end
        if s == v then
          c = c + 1
          if c > 9 then
            c = 0
            s = 1 - s
            events[#events + 1] = {i,  s}
            state[i] = s
          end
        else
          c = 0
        end
        counter[i] = c
      end
      if #events > 0 and reporter then
        reporter(events)
      end
    end)
  end
end
