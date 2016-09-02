------------------------------------------------------------------------------
-- NRF24L01 module
--
-- LICENSE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
--
-- Example:
-- dofile("nrf24.lua")
-- nrf24.start()
-- nrf24.prx(1, "1Node")
-- nrf24.ptx()
-- nrf24.write("2Node", "ABCDEF", print)
------------------------------------------------------------------------------

nrf24 = {
  autoack = false,      -- enable auto-ack for all pipes?
  channel = 76,         -- rf channel
  dynsize = false,      -- enable dynamic payload size?
  onevent = print,      -- default event handler
  --
  irqpin = nil,         -- irq pin. if unassigned a polling handler will be used
  -- polling handler parameters
  interval = 100,       -- calling interval in milliseconds
  timeout = 1000000,    -- send timeout in microseconds
}

local function r1(r)
  spi.transaction(1, 8, r, 0, 0, 0, 0, 8)
  return spi.get_miso(1, 0, 8, 1)
end

local function w0(r)
  spi.transaction(1, 8, r, 0, 0, 0, 0, 0)
end

local function w1(r, v)
  spi.transaction(1, 8, r, 8, v, 0, 0, 0)
end

local function rs(r, n)
  spi.transaction(1, 8, r, 0, 0, 0, 0, 8 * n)
  return string.char(spi.get_miso(1, 0, 8, n))
end

local function ws(r, s)
  local n = #s
  for i = 1, n do spi.set_mosi(1, 8 * i - 8, 8, s:byte(i)) end
  spi.transaction(1, 8, r, 0, 0, 8 * n, 0, 0)
end

local function flush_rx()
  -- flush rx fifo
  w0(0xe2)
  -- clear rx flag
  w1(0x27, 0x40)
end

local function flush_tx()
  -- flush tx fifo
  w0(0xe1)
  -- clear tx flags
  w1(0x27, 0x30)
end

function nrf24.status()
  return r1(0x07)
end

function nrf24.info()
  for i = 0, 0x17 do print(("%02x: %02x"):format(i, r1(i))) end
  for i = 0x1c, 0x1d do print(("%02x: %02x"):format(i, r1(i))) end
end

local function num(x) return x and "1" or "0" end

function nrf24.stat()
  local status = r1(0x07)
  local fifo = r1(0x17)
  local rx_dr = bit.isset(status, 6)
  local tx_ds = bit.isset(status, 5)
  local max_rt = bit.isset(status, 4)
  local tx_full = bit.isset(fifo, 5)
  local tx_empty = bit.isset(fifo, 4)
  local rx_full = bit.isset(fifo, 1)
  local rx_empty = bit.isset(fifo, 0)
  print(("ST=%02x:%02x===RX_DR=%d TX_DS=%d MX_RT=%d TF=%d TE=%d RF=%d RE=%d"):format(status, fifo, num(rx_dr), num(tx_ds), num(max_rt), num(tx_full), num(tx_empty), num(rx_full), num(rx_empty)))
end

--
-- receiver
--

local function read()
  local status = r1(0x07)
  -- while data in rx fifo
  while true do
    -- determine incoming pipe
    local pipe = bit.band(status / 2, 0x07)
    if pipe < 6 then
      -- get payload
      local s = rs(0x61, r1(0x60))
      -- reread status
      -- TODO: this per se should return 0x07
      w1(0x27, 0x70)
      status = r1(0x07)
      -- notify of data come
      nrf24.onevent("data", pipe, s)
    else
      break
    end
  end
end

-- start listening on pipe with address
function nrf24.prx(pipe, address)
  -- prx
  w1(0x20, 0x0f)
  -- clear flags
  w1(0x27, 0x70)
  -- TODO: ce high
  -- if nrf24.cepin then
  --   gpio.write(nrf24.cepin, 1)
  -- end
  -- setup pipe
  if pipe and pipe >= 1 and pipe < 6 then
    ws(0x2a + pipe, address)
  end
  -- notify
  nrf24.onevent("prx")
  -- read out
  read()
end

-- stop listening
function nrf24.ptx()
  -- TODO: ce low
  -- if nrf24.cepin then
  --   gpio.write(nrf24.cepin, 0)
  --   tmr.delay(200)
  --   w1(0x20, 0x0e)
  -- else
    -- NB: if ce always high we need powerdown/powerup cycle (5 ms)
    w1(0x20, 0x0c)
    w1(0x20, 0x0e)
    tmr.delay(5000)
  -- end
  -- notify
  nrf24.onevent("ptx")
end

--
-- transmitter
--

local tx_queue = { }
local tx_sending = false
local tx_address
local function send()
  if #tx_queue > 0 then
    -- get next send item
    local q = tx_queue[1]
    -- setup pipe
    local a = q[1]
    if a ~= tx_address then
      tx_address = a
      -- set tx pipe
      ws(0x30, a)
      -- set ack pipe
      ws(0x2a, a)
    end
    -- put payload
    -- NB: fill up to 32 bytes if dynsize was disabled in options
    ws(0xa0, nrf24.dynsize and q[2] or q[2] .. string.rep("\000", 32 - #q[2]))
    -- TODO: ce high
    -- if nrf24.cepin then
    --   gpio.write(nrf24.cepin, 1)
    -- end
  else
    -- TODO: ce low
    -- if nrf24.cepin then
    --   gpio.write(nrf24.cepin, 0)
    -- end
    tx_sending = false
    -- TODO: emit drain event?
--    nrf24.onevent("drain")
  end
end

-- NB: cb("fail") means send failed
function nrf24.write(address, s, cb)
  -- enqueue
  tx_queue[#tx_queue + 1] = { address, s, cb }
  -- start sender
  if not tx_sending then
    tx_sending = tmr.now()
    send()
  end
end

-- NB: to be called periodically
function nrf24.handler()
  local status = r1(0x07)
--  local fifo = r1(0x17)
  local rx_dr = bit.isset(status, 6)
  local tx_ds = bit.isset(status, 5)
  local max_rt = bit.isset(status, 4)
--  local tx_full = bit.isset(fifo, 5)
--  local tx_empty = bit.isset(fifo, 4)
--  local rx_full = bit.isset(fifo, 1)
--  local rx_empty = bit.isset(fifo, 0)
--  print(("ST=%02x:%02x===RX_DR=%d TX_DS=%d MX_RT=%d TF=%d TE=%d RF=%d RE=%d"):format(status, fifo, num(rx_dr), num(tx_ds), num(max_rt), num(tx_full), num(tx_empty), num(rx_full), num(rx_empty)))
  -- rx ready?
  if rx_dr then
    read()
  end
  -- NB: if send stales mimick failure after 1 sec
--  if not max_rt and tx_sending and tmr.now() - tx_sending > nrf24.timeout then
--    max_rt = true
--  end
  -- sent or send failed?
  if tx_ds or max_rt then
    -- clear flags
    w1(0x27, 0x70)
    -- flush tx. NB: not really needed if tx_ds as we use only one fifo slot in this method
    flush_tx()
    -- dequeue
    local q = table.remove(tx_queue, 1)
    -- report success or failure
    -- TODO: merge with nrf24.onevent?
    if q[3] then
      q[3](tx_ds and "sent" or "fail")
    end
    -- restart sender
    send()
  end
end

--
-- scheduler
--

local ticks

local function start()
  if not ticks then
    ticks = tmr.create()
    ticks:alarm(nrf24.interval, tmr.ALARM_AUTO, nrf24.handler)
  end
end

function nrf24.stop()
  if ticks then
    ticks:stop()
    ticks:unregister()
    ticks = nil
  end
end

--
-- setup
--

nrf24.start = function()
  -- 2Mbs SPI
  spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, 40, spi.FULLDUPLEX)
  -- enable auto-ack on all pipes by default
  w1(0x21, nrf24.autoack and 0x3f or 0x00)
  -- pipes: enable all pipes
  w1(0x22, 0x3f)
  -- address length: 5
  w1(0x23, 0x03)
  -- retransmits: 1.5 msec, 15 times
  w1(0x24, 0x5f)
  -- spi speed: 1Mbs
  w1(0x26, 0x07)
  -- set maximum payload size
  if not nrf24.dynsize then
    for i = 0x31, 0x36 do w1(i, 32) end
  end
  -- activate features
  w1(0x50, 0x73)
  -- setup dynamic payload size
  w1(0x3c, nrf24.dynsize and 0x3f or 0x00)
  w1(0x3d, nrf24.dynsize and 0x04 or 0x00)
  -- clear flags
  w1(0x27, 0x70)
  -- set rf channel
  if nrf24.channel then
    w1(0x25, nrf24.channel)
  end
  -- flush fifos
  flush_rx()
  flush_tx()
  -- become ptx
  w1(0x20, 0x0e)
  -- start handler
  if nrf24.irqpin then
    gpio.mode(nrf24.irqpin, gpio.INT)
    gpio.trig(nrf24.irqpin, "down", nrf24.handler)
  elseif nrf24.interval then
    start()
  end
end
