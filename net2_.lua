net2={}local n={send=function(n,e)n.queue[#n.queue+1]=e
if not n.sending then
n.sending=true
n:_send()end
end,_send=function(n)if#n.queue>0 then
if n.fd and not n.connecting then
local t,e=pcall(n.fd.send,n.fd,n.queue[1])if not t then
n:emit("error",e)end
end
else
n.sending=false
n:emit("drain")end
end,flush=function(n)n.queue={}end,_reconnect=function(n)local e=net.createConnection(n.proto or net.TCP,n.secure or 0)e:on("connection",function(e)n.fd=e
e:on("receive",function(t,e)n:emit("data",e)end)e:on("sent",function(e)table.remove(n.queue,1)n:_send()end)n.connecting=false
n:emit("connect")n:_send()end)e:on("disconnection",function(e)e:close()n.fd=nil
n:emit("end")if n.port then
tmr.alarm(6,1000,0,function()n:_reconnect()end)else
n:emit("close")end
end)n.connecting=true
e:connect(n.port,n.host)end,connect=function(n,t,e)n.host=assert(t,"no host")n.port=assert(e,"no port")n:_reconnect()end,close=function(n)n.port=nil
if n.fd then
n.fd:close()end
end,on=function(t,n,e)t._handlers[n]=e
end,emit=function(e,n,...)local n=e._handlers[n]if n then
n(e,...)end
end,}function net2:new()local n=setmetatable({_handlers={},},{__index=n})n:flush()return n
end
function net2:tcp()local n=net2:new()return n
end
function net2:udp()local n=net2:new()n.proto=net.UDP
return n
end
function net2.connect(e,t,o)local n=net2:tcp()n:on("connect",o)n:connect(e,t)return n
end
