#!/usr/bin/env lua
local arg,seed = ...
local rand=require("random").new():seed(tonumber(seed)or 42)
local function c(r,g,b,a)
	io.write(string.char(r,g,b,a))
end
arg = (tonumber(arg)-1) / 8 * 0.8
for y=1,16 do for x=1,16 do
	local xx,yy=x-0.5,y-0.5 -- centerized
	local dist = math.min(1,math.sqrt((xx-8)^2+(yy-14)^2)/8)
	dist=math.max(dist*1.05-0.05,0.05)
	c(255,255,255,rand:value() < 0.125+0.875*(1-(dist*arg)) and 255 or 0)
end end
