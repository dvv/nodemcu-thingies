------------------------------------------------------------------------------
-- Redis client module
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
--
-- Example:
-- local redis = dofile("redis.lua").connect(host, port)
-- redis:publish("chan1", foo")
-- redis:subscribe("chan1", function(self, channel, msg) print(channel, msg) end)
------------------------------------------------------------------------------
local M
do
  -- const
  local REDIS_PORT = 6379
  -- cache
  local pairs, tonumber, join = pairs, tonumber, table.concat
  --
  local command = function(self, ...)
    local arg = { ... }
    local t = {
      ("*%d\r\n"):format(#arg)
    }
    for i = 1, #arg do
      local a = arg[i]
      t[#t + 1] = ("$%d\r\n%s\r\n"):format(#a, a)
    end
    self._fd:send(join(t))
    -- TODO: analyze reply! return ok/error
    -- TODO: shift reply from circular buffer
    return true
  end
  local publish = function(self, chn, s)
    return self:command("publish", chn, s)
  end
  local subscribe = function(self, chn, handler)
    if self:command("psubscribe", chn) then
      -- NB: overwrite handler or leave old one
      if handler then self.handler = handler end
    end
  end
  local unsubscribe = function(self, ...)
    -- NB: from all
    self:command("unsubscribe", ...)
    self.handler = false
  end
  -- NB: pity we can not just augment what net.createConnection returns
  local close = function(self)
    self._fd:close()
  end
  local connect = function(host, port)
    local _fd = net.createConnection(net.TCP, 0)
    local self = {
      _fd = _fd,
      handler = false,
      -- TODO: consider metatables?
      close = close,
      command = command,
      publish = publish,
      subscribe = subscribe,
      unsubscribe = unsubscribe,
    }
    _fd:on("connection", function()
      --print("+FD")
    end)
    _fd:on("disconnection", function()
      -- FIXME: this suddenly occurs. timeout?
      --print("-FD")
    end)
    _fd:on("receive", function(fd, s)
      --print("IN", s)
      -- pubsub?
      --local ok, _, chnn, chn, msgn, msg = s:find("^*3\r\n%$7\r\nmessage\r\n%$(%d-)\r\n(.-)\r\n%$(%d-)\r\n(.-)\r\n")
      local ok, _, chnn, chn, msgn, msg = s:find("^*4\r\n%$8\r\npmessage\r\n%$%d-\r\n.-\r\n%$(%d-)\r\n(.-)\r\n%$(%d-)\r\n(.-)\r\n")
      if ok then
        --print("MATCHED", chn, msg)
        if #chn == tonumber(chnn)
           and #msg == tonumber(msgn)
           and self.handler
        then
          self:handler(chn, msg)
        end
      -- reply
      else
        -- TODO: push s to circular buffer
      end
    end)
    _fd:connect(port or REDIS_PORT, host)
    return self
  end
  -- expose
  M = {
    connect = connect,
  }
end
return M
