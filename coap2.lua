------------------------------------------------------------------------------
-- CoAP poorman module
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
--
-- NB: depend on struct module
--
-- Example:
-- c = require("coap2").Client("192.168.1.1", 5683)
-- c:post("/foo/bar", { foo = "bar" }) -- NON
-- c:post("/foo/bar", { foo = "bar" }, function(self, code, reply) ... end) -- CON
-- c:close()
--
-- s = require("coap2").Server(5683)
-- s:on("packet", function(self, packet) print(packet.payload); ...; self:send(packet2) end)
-- s:close()
------------------------------------------------------------------------------

require("object")
require("timer")

-- https://tools.ietf.org/html/rfc7252

local decode = function(s)
  local pkt = {
    options = { },
  }
  if #s < 4 then
    pkt.err = 1 -- ignore
    return pkt
  end
  local x = s:byte(1)
  -- version
  pkt.version = bit.rshift(x, 6)
  if pkt.version ~= 0x01 then
    pkt.err = 1 -- ignore
    return pkt
  end
  -- type
  pkt.type = bit.rshift(bit.band(x, 0x30), 4)
  --pkt.type2 = (({ [0] = "con", "non", "ack", "rst" })[pkt.type])
  -- token
  x = bit.band(x, 0x0F)
  if x > 8 then
    pkt.err = 2 -- format
    return pkt
  elseif x > 0 then
    pkt.token = s:sub(5, 4 + x)
  end
  local i = 5 + x
  -- code
  x = s:byte(2)
  pkt.class = bit.rshift(x, 5)
  pkt.detail = bit.band(x, 0x1F)
  pkt.code = ("%d.%02d"):format(pkt.class, pkt.detail)
  -- id
  pkt.id = struct.unpack(">H", s, 3)
  -- options
  local option = 0
  while i <= #s do
    local x = s:byte(i)
    i = i + 1
    -- payload marker?
    if x == 0xFF then
      -- the rest of packet is payload
      pkt.payload = s:sub(i)
      if #pkt.payload == 0 then
        pkt.err = 2 -- format
      end
      break
    end
    -- option number
    local delta = bit.rshift(x, 4)
    if delta == 13 then
      delta = s:byte(i) + 13
      i = i + 1
    elseif delta == 14 then
      delta = struct.unpack(">H", s, i) + 269
      i = i + 2
    elseif delta == 15 then
      pkt.err = 2 -- format
      break
    end
    option = option + delta
    -- option length
    local length = bit.band(x, 0x0F)
    if length == 13 then
      length = s:byte(i) + 13
      i = i + 1
    elseif length == 14 then
      length = struct.unpack(">H", s, i) + 269
      i = i + 2
    elseif length == 15 then
      pkt.err = 2 -- format
      break
    end
    -- option value
    local value = s:sub(i, i + length - 1)
    i = i + length
    -- print("OPT", option, length, value)
    pkt.options[#pkt.options + 1] = { option, value }
  end
  return pkt
end

local encode = function(pkt)
  local s = { }
  -- TODO: #pkt.token <= 8
  s[#s + 1] = string.char(bit.bor(
    -- version
    bit.lshift(pkt.version or 1, 6),
    -- type
    bit.lshift(bit.band(pkt.type or 1, 0x03), 4),
    -- token length
    bit.band(pkt.token and #pkt.token or 0, 0x0F)
  ))
  -- code
  s[#s + 1] = string.char(bit.bor(
    bit.lshift(pkt.class or 0, 5),
    bit.band(pkt.detail or 0, 0x1F)
  ))
  -- id
  s[#s + 1] = struct.pack(">H", pkt.id)
  -- token, if any
  if pkt.token then
    s[#s + 1] = pkt.token
  end
  -- options
  local option0 = 0
  for _, option in ipairs(pkt.options) do
    local i = #s + 1
    s[i] = 0 -- reserve
    local delta = option[1] - option0
    option0 = option[1]
    local x
    if delta < 13 then
      x = delta
    elseif delta < 269 then
      x = 13
      s[#s + 1] = string.char(delta - 13)
    else
--      x = delta - 269
--      s[#s + 1] = string.char(bit.rshift(bit.band(x, 0xFF00), 8), bit.band(x, 0xFF))
      x = 14
      s[#s + 1] = struct.pack(">H", delta - 269)
    end
    local x2
    local value = option[2]
    local length = #value
    if length < 13 then
      x2 = length
    elseif length < 269 then
      x2 = 13
      s[#s + 1] = string.char(length - 13)
    else
--      x2 = length - 269
--      s[#s + 1] = string.char(bit.rshift(bit.band(x2, 0xFF00), 8), bit.band(x2, 0xFF))
      x2 = 14
      s[#s + 1] = struct.pack(">H", length - 269)
    end
    s[#s + 1] = value
    --
    s[i] = string.char(bit.bor(
      bit.lshift(x, 4),
      bit.band(x2, 0x0F)
    ))
  end
  -- payload
  local payload = pkt.payload and tostring(pkt.payload)
  if payload and #payload > 0 then
    s[#s + 1] = string.char(0xFF)
    s[#s + 1] = payload
  end
  return table.concat(s)
end

local encode2 = function(uri, payload, callback)
  local s = { }
  -- confirmable POST request with token
  if callback then
    local key = struct.pack(">HHH", math.random(0xFFFF), math.random(0xFFFF), math.random(0xFFFF))
    s[#s + 1] = struct.pack("BBc0", 0x44, 0x02, key)
  -- non-confirmable POST request
  else
    s[#s + 1] = struct.pack("BB>H", 0x50, 0x02, math.random(0xFFFF))
  end
  -- Uri-Path
  local delta = 0xB0
  for p in uri:gmatch("[^/]+") do
    assert(#p < 13)
    s[#s + 1] = struct.pack("Bc0", bit.bor(delta, #p), p)
    delta = 0x00
  end
  -- payload
  if payload then
    -- for table payload use json
    if type(payload) == "table" then
      -- Content-Format: application/json
      s[#s + 1] = struct.pack("BB", 0x11, 50)
      payload = cjson.encode(payload)
    end
    s[#s + 1] = struct.pack("Bc0", 0xFF, payload)
  end
  return table.concat(s)
end

local close = function(self)
  self.fd:close()
  self.fd = nil
-- c = require("coap2").Client("192.168.1.1", 5683)
-- c:post("/foo/bar", { foo = "bar" }) -- NON
-- c:post("/foo/bar", { foo = "bar" }, function(self, code, reply) ... end) -- CON
-- c:close()
end

local send = function(self, pkt)
  self.fd:send(type(pkt) == "table" and encode(pkt) or pkt)
end

local post = function(self, uri, payload, callback)
  local s = encode2(uri, payload, callback)
  if callback then
    local event = "recv:" .. s:sub(3, 8)
    self:once(event, callback, 2000)
  end
  self:send(s)
end

local meta = {
  __index = {
    close = close,
    decode = decode,
    encode = encode,
    post = post,
    send = send,
  }
}

local Client = function(host, port)
  local self = extend(object(), meta.__index)
  self.fd = net.createConnection(net.UDP)
  self.fd:on("receive", function(_, s)
    --print("DEBUG", "RECV", s)
    -- packet valid?
    local pkt = decode(s)
    if not pkt.err then
      -- emit receive
      local event = "recv:" .. s:sub(3, 8)
      self:emit(event, pkt.code, pkt.payload)
    end
  end)
  self.fd:connect(port or 5683, host)
  return self
end

local Server = function(port)
  local self = extend(object(), meta.__index)
  self.fd = net.createServer(net.UDP)
  self.fd:on("receive", function(_, s)
    --print("DEBUG", "RECV", s)
    -- packet valid?
    local pkt = decode(s)
    if not pkt.err then
      self:emit("packet", pkt)
    end
  end)
  self.fd:listen(port or 5683)
  return self
end

return {
  Client = Client,
  Server = Server,
}
