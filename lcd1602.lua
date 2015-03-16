------------------------------------------------------------------------------
-- LCD 1602/1604 module
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
-- Compiled from various sources inc.
--   http://www.avrfreaks.net/forum/lcd-display-iic-1602-atmega328p
--   https://github.com/nekromant/esp8266-frankenstein/blob/4880a04452ab745b1d99c0aedbb69cc2ba7fd5cb/include/driver/i2c_hd44780.h
--
-- Example, after you initialized I2C as usual:
-- lcd = dofile("lcd1602.lua")(adr, rows); lcd.print("Hello, dvv!\n")
------------------------------------------------------------------------------
local M
do
  -- const
  local ADR = 0x27
  local _COLS, _ROWS = 16, 2
  local _LINES = {[0] = 0x00, 0x40, 0x14, 0x54}
  -- cache
  local i2c, delay, bit, bor, band, bshl =
        i2c, tmr.delay, bit, bit.bor, bit.band, bit.lshift
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
  local clear = function()
    _row, _col = 0, 0
    w(0x01, 0)
  end
  local home = function()
    _row, _col = 0, 0
    w(0x02, 0)
  end
  local set_backlight = function(on)
    _ctl = on and 0x08 or 0x00
    w(0x00, 0)
  end
  local create_char = function(c, bytes)
    w(0x40 + bshl(band(c, 0x07), 3), 0)
    for i = 1, 8 do
      w(bytes[i], 1)
    end
  end
  -- NB: 0-based
  local _row, _col = 0, 0
  local goto = function(row, col)
    row = row % _ROWS
    col = col % _COLS
    --if col < 0 then col = 0 end
    --if col >= _COLS then col = _COLS - 1 end
    _row, _col = row, col
    w(bor(0x80, _LINES[row] + col), 0)
  end
  local clear_to_eol = function()
    for i = 1, _COLS - _col do w(0x20, 1) end
  end
  local puts = function(s)
    for i = 1, #s do
      local c = s:byte(i)
      -- \n
      if c == 10 then
        -- NB: clear up to the eol
        clear_to_eol()
        goto(_row + 1, 0)
      -- \r
      elseif c == 13 then
        goto(_row, 0)
      -- \011
      elseif c == 11 then
        -- clear up to the eol
        clear_to_eol()
        goto(_row, _col)
      -- \012
      elseif c == 12 then
        -- clear all
        clear()
      else
        w(c, 1)
        _col = _col + 1
        if _col >= _COLS then
          goto(_row + 1, 0)
        end
      end
    end
  end
  local cursor_left = function()
    w(0x10, 0)
  end
  local cursor_right = function()
    w(0x14, 0)
  end
  local shift_left = function()
    w(0x18, 0)
  end
  local shift_right = function()
    w(0x1C, 0)
  end
  local init = function(adr, rows)
    ADR = adr or 0x27
    _ROWS = rows or 2
    w(0x33, 0)
    w(0x32, 0)
    w(0x28, 0)
    w(0x0C, 0)
    w(0x06, 0)
    w(0x01, 0)
    w(0x02, 0)
    goto(0, 0)
    -- expose
    return {
      clear = clear,
      home = home,
      goto = goto,
      print = puts,
      create_char = create_char,
      set_backlight = set_backlight,
      cursor_left = cursor_left,
      cursor_right = cursor_right,
      shift_left = shift_left,
      shift_right = shift_right,
      _w = w, -- raw writer
    }
  end
  -- expose constructor
  M = init
end
return M
