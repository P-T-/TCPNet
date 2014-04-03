<p align="center"><img src="http://i.imgur.com/Rj9rH3s.png"></p>

API
------

```
local handle=tcpnet.new([ip[,port]])
```
connects to the server, ip defaults to localhost and port defaults to 25476

```
handle:receive([timeout[,port]])
```
returns port,data
or just data if the port parameter is given

```
handle:send(port,data)
```
sends data to port

```
handle:open(...)
```
opens ports

```
handle:close(...)
```
closes ports

```
event "tcpnet_message",port,data
```

protocol
------

every message and response is a table serialized
ports can be strings or numbers
it does serialize the data, but because computer.pushSignal doesnt support tables, my api wont allow them
but it is really easy to write your own api

```
{"send",port=port,data=data}
```
sends data to everyone listening on port

```
{"open",ports={[port]=true,[port]=false}}
```
open/close ports

you receive

```
{"message",port=port,data=data}
```
