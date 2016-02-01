MCP23017_ADDRESS = 0x20

bit, i2c = require("bit"), require("i2c")
ipairs = ipairs

function readReg(reg, count)
  i2c.start(0)
  i2c.address(0, MCP23017_ADDRESS, i2c.TRANSMITTER)
  i2c.write(0, reg)
  i2c.stop(0)
  i2c.start(0)
  i2c.address(0, MCP23017_ADDRESS, i2c.RECEIVER)
  local data = i2c.read(0, count)
  i2c.stop(0)
  return data
end

function writeReg(reg, ...)
  i2c.start(0)
  i2c.address(0, MCP23017_ADDRESS, i2c.TRANSMITTER)
  i2c.write(0, reg)
  i2c.write(0, ...)
  i2c.stop(0)
end

function readState()
  local x = readReg(0x12, 2)
  return 0xff - x:byte(1), 0xff - x:byte(2)
end

function set(pin, val)
  -- validate pin
  assert(pin >= 1 and pin <= 16, "pin := 1..16")
  pin = pin - 1
  local reg = bit.isset(pin, 3) and 0x01 or 0x00
  pin = bit.clear(pin, 3)
  -- read direction
  local x = readReg(reg, 1):byte()
  if val == 0 then
    x = bit.set(x, pin)
  elseif val == 1 then
    x = bit.clear(x, pin)
  elseif val == 2 then
    x = bit.isset(x, pin) and bit.clear(x, pin) or bit.set(x, pin)
  end
  writeReg(reg, x)
end

function get()
  local x = readReg(0x12, 2)
  return x:byte(1) + 256 * x:byte(2)
end

  function run(pins, reporter, timerno, interval)
    -- setup pullups
    writeReg(0x0c, 0xff, 0xff)
    -- store state
    local state = 0xffff
    --
    tmr.alarm(timerno or 2, interval or 50, 1, function()
      tmr.wdclr()
      -- get changes
      local val = get()
      local changes = bit.bxor(state, val)
--print(("XX: %04x"):format(val))
      -- report changed pins
      local events = {}
      for i = 0, 15 do
        if bit.isset(changes, i) then
          events[#events + 1] = {i + 1, bit.isclear(val, i) and 1 or 0}
        end
      end
      state = val
      if #events > 0 and reporter then
        reporter(events)
      end
    end)
  end
