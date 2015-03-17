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
-- Example, after you initialized I2C as usual:
-- lcd = dofile("lcd1602.lua")()
-- lcd.put(lcd.locate(0, 5), "Hello, dvv!")
-- lcd.run(0, "It's time! Skushai tvorojok!", 150, 1, function() print("done") end); print("ok")
-- function notice() print(node.heap()); lcd.run(0, "Should not leak!", 50, 1, notice) end; notice()
------------------------------------------------------------------------------
local M
do
  -- const
  local ADR = 0x27
  local _COLS, _ROWS = 16, 2
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
  -- return command to set cursor at row/col
  local locate = function(row, col)
    return 0x80 + col + (row % _ROWS) * 0x40
  end
  -- write to lcd
  local put = function(...)
    for _, x in ipairs({...}) do
      -- table?
      if type(x) == "table" then
        -- first element sets command (true) or data (false) mode
        local mode = x[1] and 0 or 1
        for i = 2, #x do w(x[i], mode) end
        delay(1000)
      -- number?
      elseif type(x) == "number" then
        -- direct command
        w(x, 0)
        delay(1000)
      -- string?
      elseif type(x) == "string" then
        -- treat as data
        for i = 1, #x do
          w(x:byte(i), 1)
        end
        delay(1000)
      end
    end
  end
  -- show a running string s at row. shift delay is _delay using timer, on completion spawn callback
  local run = function(row, s, _delay, timer, callback)
    _delay = _delay or 40
    tmr.stop(timer)
    local i = 16
    local runner = function()
      -- TODO: optimize calculus?
      put(locate(row, i >= 0 and i or 0), (i >= 0 and s:sub(1, 16 - i) or s:sub(1 - i, 16 - i)), " ")
      if i == -#s then
        tmr.stop(timer)
        if type(callback) == "function" then callback() end
      else
        i = i - 1
      end
    end
    tmr.alarm(timer, _delay, 1, runner)
  end
  -- start lcd
  local init = function(rows, adr)
    _ROWS = rows or 2
    ADR = adr or 0x27
    w(0x33, 0)
    w(0x32, 0)
    w(_ROWS == 1 and 0x20 or 0x28, 0)
    w(0x0C, 0)
    w(0x06, 0)
    w(0x01, 0)
    w(0x02, 0)
    -- expose
    return {
      put = put,
      locate = locate,
      light = light,
      run = run,
    }
  end
  -- expose constructor
  M = init
end
return M
