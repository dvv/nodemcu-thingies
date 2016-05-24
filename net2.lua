------------------------------------------------------------------------------
-- NET client module
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
--
-- Example:
-- require("net2")
-- c = net2.connect("192.168.1.1", 1234)
-- c:on("data", function(self, data) print("reply", data) end)
-- c:send("command!")
------------------------------------------------------------------------------

net2 = { }

local _meta = {

  -- send data
  send = function(self, s)
    -- just push to output queue tail
    self.queue[#self.queue + 1] = s
    -- and initiate sending helper
    self:_send()
  end,

  -- sending helper for draining output queue
  _send = function(self)
    -- queue not empty?
    if #self.queue > 0 then
      -- socket ready?
      if self.fd and not self.connecting then
        -- TODO: FIXME: without a delay broken data is sent (first char eaten?)
        tmr.delay(10000)
        -- gently send from queue head
        -- TODO: chunking?
        local ok, err = pcall(self.fd.send, self.fd, self.queue[1])
        -- send failed?
        if not ok then
          -- report error
          self:emit("error", err)
        -- sent ok
        else
          -- remove queue head
          table.remove(self.queue, 1)
        end
      end
    -- queue empty
    else
      -- report queue drained
      self:emit("drain")
    end
  end,

  -- reset output queue
  flush = function(self)
    self.queue = { }
  end,

  -- connecting helper
  _reconnect = function(self)
    -- create native socket
    local fd = net.createConnection(self.proto or net.TCP, self.secure or 0)
    -- connected ok?
    fd:on("connection", function(fd)
      -- store socket
      self.fd = fd
      -- report data received
      fd:on("receive", function(fd, s)
        self:emit("data", s)
      end)
      -- on data sent restart sending helper
      fd:on("sent", function(fd)
        self:_send()
      end)
      -- report connected ok
      self.connecting = false
      self:emit("connect")
      -- restart sending helper
      -- NB: it should send data which user might have send while socket was offline
      self:_send()
    end)
    -- disconnected?
    fd:on("disconnection", function(fd)
      -- close native socket, just in case
      fd:close()
      -- release socket
      self.fd = nil
      -- report socket dead
      self:emit("end")
      -- disconnected unexpectedly?
      if self.port then
        -- respawn connecting helper
        tmr.alarm(6, 1000, 0, function()
          self:_reconnect()
        end)
      -- disconnected ok
      else
        -- report close
        self:emit("close")
      end
    end)
    -- try to connect native socket
    self.connecting = true
    fd:connect(self.port, self.host)
  end,

  -- connect to peer
  connect = function(self, host, port)
    self.host = assert(host, "no host")
    self.port = assert(port, "no port")
    self:_reconnect()
  end,

  -- close connection
  close = function(self)
    -- mark we do not want to reconnect
    self.port = nil
    -- close native socket
    if self.fd then
      self.fd:close()
    end
  end,

  -- attach event handler
  on = function(self, event, handler)
    -- TODO: multiple?
    self._handlers[event] = handler
  end,

  -- emit event
  emit = function(self, event, ...)
    local handler = self._handlers[event]
    -- TODO: multiple?
    if handler then
      handler(self, ...)
    end
  end,
}

function net2:new()
  local self = setmetatable({
    _handlers = { },
  }, { __index = _meta })
  self:flush()
  return self
end

--
-- Create TCP connection to host:port
--
function net2:tcp()
  local self = net2:new()
  return self
end

--
-- Create UDP connection to host:port
--
function net2:udp()
  local self = net2:new()
  self.proto = net.UDP
  return self
end

--
-- Create TCP connection to host:port
--
function net2.connect(host, port, on_connect)
  local self = net2:tcp()
  self:on("connect", on_connect)
  self:connect(host, port)
  return self
end
