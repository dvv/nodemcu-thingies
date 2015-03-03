------------------------------------------------------------------------------
-- MQTT queuing publish helper
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Vladimir Dronnikov <dronnikov@gmail.com>
--
-- Example:
-- local mqtt = require("mqtt").Client(NAME, 60)
-- local pub = dofile("mqtt-queue-helper.lua")(mqtt)
-- pub(topic1, pload1); pub(topic2, pload2, qos); pub(topic3, pload3, 2, true)
------------------------------------------------------------------------------
do
  -- cache
  local shift = table.remove
  -- factory
  local make_publisher = function(client)
    local queue = { }
    local is_sending = false
    local function send()
      if #queue > 0 then
        local tp = shift(queue, 1)
        client:publish(tp[1], tp[2], tp[3], tp[4], send)
      else
        is_sending = false
      end
    end
    return function(...)
      queue[#queue + 1] = {...}
      if not is_sending then
        is_sending = true
        send()
      end
    end
  end
  -- expose
  return make_publisher
end
