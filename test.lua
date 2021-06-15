#!/usr/bin/env lua
local texgen=require"texgen"
local w=8
local buf=texgen.buf_new(w,w)
for n=1,1000 do
	buf:set(math.random(1,w),math.random(1,w),math.random(0,5),math.random(0,5),math.random(0,5))
	texgen.render(buf)
end
local bb=texgen.render(buf)
print(bb)
print(#bb)
