--[[
	https://github.com/MightyPirates/OpenComputers/blob/master/src/main/resources/assets/opencomputers/lua/rom/lib/serialization.lua
]]
local function serialize(value, pretty)
	local kw = {
		["and"]=true,["break"]=true, ["do"]=true, ["else"]=true,
		["elseif"]=true, ["end"]=true, ["false"]=true, ["for"]=true,
		["function"]=true, ["goto"]=true, ["if"]=true, ["in"]=true,
		["local"]=true, ["nil"]=true, ["not"]=true, ["or"]=true,
		["repeat"]=true, ["return"]=true, ["then"]=true, ["true"]=true,
		["until"]=true, ["while"]=true
	}
	local id = "^[%a_][%w_]*$"
	local ts = {}
	local function s(v, l)
		local t = type(v)
		if t == "nil" then
			return "nil"
		elseif t == "boolean" then
			return v and "true" or "false"
		elseif t == "number" then
			if v ~= v then
				return "0/0"
			elseif v == math.huge then
				return "math.huge"
			elseif v == -math.huge then
				return "-math.huge"
			else
				return tostring(v)
			end
		elseif t == "string" then
			return string.format("%q", v):gsub("\\\n","\\n"
		elseif t == "table" and pretty and getmetatable(v) and getmetatable(v).__tostring then
			return tostring(v)
		elseif t == "table" then
			if ts[v] then
				if pretty then
					return "recursion"
				else
					error("tables with cycles are not supported")
				end
			end
			ts[v] = true
			local i, r = 1, nil
			local f
			if pretty then
				local ks, sks, oks = {}, {}, {}
				for k in pairs(v) do
					if type(k) == "number" then
						table.insert(ks, k)
					elseif type(k) == "string" then
						table.insert(sks, k)
					else
						table.insert(oks, k)
					end
				end
				table.sort(sks)
				for _, k in ipairs(sks) do
					table.insert(ks, k)
				end
				for _, k in ipairs(oks) do
					table.insert(ks, k)
				end
				local n = 0
				f = table.pack(function()
					n = n + 1
					local k = ks[n]
					if k ~= nil then
						return k, v[k]
					else
						return nil
					end
				end)
			else
				f = table.pack(pairs(v))
			end
			for k, v in table.unpack(f) do
				if r then
					r = r .. "," .. (pretty and ("\n" .. string.rep(" ", l)) or "")
				else
					r = "{"
				end
				local tk = type(k)
				if tk == "number" and k == i then
					i = i + 1
					r = r .. s(v, l + 1)
				else
					if tk == "string" and not kw[k] and string.match(k, id) then
						r = r .. k
					else
						r = r .. "[" .. s(k, l + 1) .. "]"
					end
					r = r .. "=" .. s(v, l + 1)
				end
			end
			ts[v] = nil -- allow writing same table more than once
			return (r or "{") .. "}"
		else
			if pretty then
				return tostring(t)
			else
				error("unsupported type: " .. t)
			end
		end
	end
	local result = s(value, 1)
	local limit = type(pretty) == "number" and pretty or 10
	if pretty then
		local truncate = 0
		while limit > 0 and truncate do
			truncate = string.find(result, "\n", truncate + 1, true)
			limit = limit - 1
		end
		if truncate then
			return result:sub(1, truncate) .. "..."
		end
	end
	return result
end

function unserialize(data)
	checkArg(1, data, "string")
	local result, reason = load("return " .. data, "=data", _, {math={huge=math.huge}})
	if not result then
		return nil, reason
	end
	local ok, output = pcall(result)
	if not ok then
		return nil, output
	end
	return output
end

--[[
	TCPNet by PixelToast https://github.com/P-T-/TCPNet/
	released in public domain because i know you hate seeing the all caps
]]

local config={
	port=25476,
}
local socket=require("socket")
local clients={}
local sv=socket.bind("*",config.port) -- bind port
local socketsel={}
local function newsocket(cl)
	cl:settimeout(0) -- make the socket non blocking
	local o={
		cl=cl,
		close=function(self)
			cl:close()
			clients[cl]=nil
			for k,v in pairs(socketsel) do
				if v==cl then
					socketsel[k]=nil
					break
				end
			end
		end,
		send=function(self,dat)
			cl:send(txt.."\n")
		end,
		open={},
	}
	clients[cl]=o
	return o
end
while true do
	local cl=sv:accept() -- accept new connections
	while cl do
		newsocket(cl) -- add them to clients
		cl=sv:accept()
	end
	for cl,cldat in pairs(clients) do
		local s,e=cl:receive(0)
		if not s and e=="closed" then
			cldat:close()
		else
			local dat,er=cl:receive() -- try to receive data from client
			if dat then
				err,dat=pcall(unserialize,dat)
				if err and type(dat=="table") then
					if dat[1]=="send" and type(dat.port):match("^[sn]") then
						for k,v in pairs(clients) do
							if v.open[dat.port] then
								k:send(serialize({"message",port=dat.port,data=dat.data})) -- send message
							end
						end
					elseif dat[1]=="open" and type(dat.ports)=="table" then
						for k,v in pairs(dat.ports) do
							cldat[k]=v~=false -- open/close ports
						end
					end
				end
			end
		end
	end
	socket.select(socketsel,nil,10) -- "Yield" to the sockets for a minimum of 10s
end