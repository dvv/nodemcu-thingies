------------------------------------------------------------------------------
-- Redis client module
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
--
-- Example:
-- c = redis:new("192.168.1.1")
-- c:on("message", function(self, channel, msg) print(channel, msg) end)
-- c:command("psubscribe", "*")
-- c2 = redis:new("192.168.1.1")
-- c2:command("publish", "foo", "bar")
------------------------------------------------------------------------------

redis = { }

local formatCommand = function(...)
  local arg = { ... }
  local t = {
    ("*%d\r\n"):format(#arg)
  }
  for i = 1, #arg do
    local a = arg[i]
    t[#t + 1] = ("$%d\r\n%s\r\n"):format(#a, a)
  end
  return table.concat(t)
end

local parseMessage = function(s)
  local ok, _, chnn, chn, msgn, msg = s:find("^*4\r\n%$8\r\npmessage\r\n%$%d-\r\n.-\r\n%$(%d-)\r\n(.-)\r\n%$(%d-)\r\n(.-)\r\n")
  if ok then
    if #chn == tonumber(chnn)
       and #msg == tonumber(msgn)
    then
      return chn, msg
    end
  end
end

function redis:new(host, port)
  local self = net2.connect(host, port or 6379)
  self:on("data", function(self, data)
    self:emit("message", parseMessage(data))
  end)
  function self:command(...)
    -- TODO: response parser
    self:send(formatCommand(...))
  end
  return self
end
