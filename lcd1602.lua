------------------------------------------------------------------------------
-- LCD 1602 module
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
-- Compiled from various sources inc.
--   http://www.avrfreaks.net/forum/lcd-display-iic-1602-atmega328p
--   http://www.avrfreaks.net/sites/default/files/lcd_22.h
--   https://github.com/nekromant/esp8266-frankenstein/blob/4880a04452ab745b1d99c0aedbb69cc2ba7fd5cb/include/driver/i2c_hd44780.h
--
-- Example:
-- i2c.setup(0, 3, 4, i2c.SLOW)
-- lcd = dofile("lcd1602.lua")()
-- lcd.put(lcd.locate(0, 5), "Hello, dvv!")
-- function notice() print(node.heap()); lcd.run(0, "It's time! Skushai tvorojok!", 150, 1, notice) end; notice()
------------------------------------------------------------------------------
local M
do
  -- const
  local ADR = 0x27
  -- cache
  local i2c, tmr, delay, ipairs, type, bit, bor, band, bshl =
        i2c, tmr, tmr.delay, ipairs, type, bit, bit.bor, bit.band, bit.lshift
  -- helpers
  local _ctl = 0x08
  local w = function(b, mode)
    i2c.start(0)
    i2c.address(0, ADR, i2c.TRANSMITTER)
    local bh = band(b, 0xF0) + _ctl + mode
    local bl = bshl(band(b, 0x0F), 4) + _ctl + mode
    i2c.write(0, bh + 4, bh, bl + 4, bl)
    i2c.stop(0)
  end
  -- backlight on/off
  local light = function(on)
    _ctl = on and 0x08 or 0x00
    w(0x00, 0)
  end
  local clear = function()
    w(0x01, 0)
  end
  -- return command to set cursor at row/col
  local locate = function(row, col)
    return 0x80 + col + (row % 2) * 0x40
  end
  local define_char = function(index, bytes)
    w(0x40 + 8 * band(index, 0x07), 0)
    for i = 1, #bytes do w(bytes[i], 1) end
  end
  -- write to lcd
  local put = function(...)
    for _, x in ipairs({...}) do
      -- number?
      if type(x) == "number" then
        -- direct command
        w(x, 0)
      -- string?
      elseif type(x) == "string" then
        -- treat as data
        for i = 1, #x do w(x:byte(i), 1) end
      end
      delay(800)
    end
  end
  -- show a running string s at row. shift delay is _delay using timer,
  --     on completion spawn callback
  local run = function(row, s, _delay, timer, callback)
    _delay = _delay or 40
    tmr.stop(timer)
    local i = 16
    local runner = function()
      -- TODO: optimize calculus?
      put(
          locate(row, i >= 0 and i or 0),
          (i >= 0 and s:sub(1, 16 - i) or s:sub(1 - i, 16 - i)),
          " "
        )
      if i == -#s then
        if type(callback) == "function" then
          tmr.stop(timer)
          callback()
        else
          i = 16
        end
      else
        i = i - 1
      end
    end
    tmr.alarm(timer, _delay, 1, runner)
  end
  -- start lcd
  local init = function(adr)
    ADR = adr or 0x27
    w(0x33, 0)
    w(0x32, 0)
    w(0x28, 0)
    w(0x0C, 0)
    w(0x06, 0)
    w(0x01, 0)
    w(0x02, 0)
    -- expose
    return {
      define_char = define_char,
      light = light,
      clear = clear,
      locate = locate,
      put = put,
      run = run,
    }
  end
  -- expose constructor
  M = init
end
return M
