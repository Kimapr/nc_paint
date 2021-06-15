local fngen
local unpack=unpack or table.unpack
if not minetest then
	fngen=require"fngen"
else
	fngen=dofile(minetest.get_modpath(minetest.get_current_modname()).."/fngen.lua")
end
local texgen={}
local function postoid(x,y)
	return string.format("%s_%s",x,y)
end
local bufmt={}
bufmt.__index=bufmt
local c=6
function bufmt:set(x,y,r,g,b)
	if not r then
		self[postoid(x,y)]=false
	else
		assert(r and g and b)
		for k,v in ipairs{r,g,b} do
			assert(v>=0 and v<=5)
		end
		self[postoid(x,y)]={c-1-r,c-1-g,c-1-b}
	end
end
function bufmt:get(x,y)
	local s=self[postoid(x,y)]
	if not s then return end
	local r,g,b=unpack(s)
	return c-1-r,c-1-g,c-1-b
end
if minetest then
	function texgen.buf_to_string(buf)
		local buf2={w=buf.w,h=buf.h}
		for x=1,buf.w do
			for y=1,buf.h do
				local i=postoid(x,y)
				buf2[i]=buf[i]
			end
		end
		return minetest.serialize(buf)
	end
	function texgen.string_to_buf(str)
		return setmetatable(minetest.deserialize(str),bufmt)
	end
end
function texgen.buf_new(w,h)
	local buf={}
	buf.w=w
	buf.h=h
	for x=1,buf.w do
		for y=1,buf.h do
			buf[postoid(x,y)]=false
		end
	end
	return setmetatable(buf,bufmt)
end
function texgen.render(buf)
	local mod={string.format("[combine:%sx%s",buf.w,buf.h)}
	for x=1,buf.w do
		for y=1,buf.h do
			local rx,ry=x-1,y-1
			local s=buf[postoid(x,y)]
			if s then
				mod[#mod+1]=string.format(":%s,%s=%s",rx,ry,fngen(unpack(s)))
			end
		end
	end
	return table.concat(mod)
end
return texgen
