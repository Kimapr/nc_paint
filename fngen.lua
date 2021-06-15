local base64
if not minetest then
	base64=require"base64"
else
	base64=dofile(minetest.get_modpath(minetest.get_current_modname()).."/base64.lua")
end
c=6
local function fngen(qr,qg,qb)
	--local qr,qg,qb=math.floor(r*(c-1)),math.floor(g*(c-1)),math.floor(b*(c-1))
	return string.format("%s",base64.enc(string.char(math.floor(qr*(c^2)+qg*(c)+qb))):gsub("=",""))
end
local function rgbtoid(r,g,b)
	return string.format("%s_%s_%s",r,g,b)
end
local function gencc(fn)
	local cc=base64.enc(fn)
	return cc:sub(1,1)
end
local fns={}
local fnmap={}
for r=0,c-1 do
	for g=0,c-1 do
		for b=0,c-1 do
			local fn=fngen(r,g,b):upper()
			local ff=false
			while fns[fn] do -- fuck windows
				if not ff then
					fn=fn..gencc(fn)
					ff=true
				else
					fn=fn:sub(1,-2)..gencc(fn)
				end
			end
			fns[fn]=true
			fnmap[rgbtoid(r,g,b)]=fn
		end
	end
end
return function(qr,qg,qb,raw)
	local pp=(raw and "" or ".png")
	assert(pp)
	return fnmap[rgbtoid(qr,qg,qb)]..pp
end
