#!/usr/bin/env lua
local base64=require"base64"
local fngen=require"fngen"
local unpack=unpack or table.unpack
function gen(a,b,c,fn)
	print(fn)
	local e=os.execute(string.format("convert -size 1x1 canvas:\\#%s%s%s%s%s%s PNG24:textures/%s",a,a,b,b,c,c,fn))
	if (type(e)=="number" and {e~=0} or {not e})[1] then
		error(string.format("error: %s",e))
	end
end
local ha={"a","b","c","d","e","f"}
local colors={}
for n=0,9 do
	colors[n]=tostring(n)
end
for n=1,6 do
	colors[#colors+1]=ha[n]
end
local c=6
local m=(15/(c-1))
fns={}
for qr=0,c-1 do
	local r=colors[qr*m]
	for qg=0,c-1 do
		local g=colors[qg*m]
		for qb=0,c-1 do
			local b=colors[qb*m]
			local fn=fngen(qr,qg,qb)
			assert(not fns[fn])
			fns[fn]=true
			gen(r,g,b,fn)
		end
	end
end

local obj1={"#this shitty object is shittomatically generated\no Le_NodePaint"}
local obj2={}
local pp={{{-0.5,-0.5,0.5},{-0.5,0.5,0.5},{0.5,0.5,0.5},{0.5,-0.5,0.5}},{{1,0},{1,1},{0,1},{0,0}},{{0,0,-1},{0,0,-1},{0,0,-1},{0,0,-1}}}
for k,v in ipairs(pp[1]) do
	v[3]=v[3]*127/128
end
local function rot1(x,y,z)
	return -z,y,x
end
local function rot2(x,y,z)
	return x,z,-y
end
local function rot3(x,y,z)
	return x,-z,y
end
local function rott(x,y)
	return x,-y
end
local function rp(f,n)
	return function(x,y,z)
		for i=1,n do
			x,y,z=f(x,y,z)
		end
		return x,y,z
	end
end
local vi,vti,vni=1,1,1
local function pushf(nm,rot,rott)
	table.insert(obj2,string.format("g Le_NodePaint_Face_%s\ns off",nm))
	local fel={}
	for n=1,4 do
		fel[n]={}
	end
	local fvi,fvti,fvni=1,1,1
	for k,v in ipairs(pp[1]) do
		table.insert(obj1,string.format("v %s %s %s",rot(unpack(v))))
		table.insert(fel[fvi],vi)
		vi=vi+1
		fvi=fvi+1
	end
	for k,v in ipairs(pp[2]) do
		local x,y=unpack(v)
		if rott then
			x,y=rott(x,y)
		end
		table.insert(obj1,string.format("vt %s %s",x,y))
		table.insert(fel[fvti],vti)
		vti=vti+1
		fvti=fvti+1
	end
	for k,v in ipairs(pp[3]) do
		table.insert(obj1,string.format("vn %s %s %s",rot(unpack(v))))
		table.insert(fel[fvni],vni)
		vni=vni+1
		fvni=fvni+1
	end
	for k,v in ipairs(fel) do
		fel[k]=table.concat(v,"/")
	end
	table.insert(obj2,string.format("f %s",table.concat(fel," ")))
end
pushf("PZ",rp(rot1,0))
pushf("PX",rp(rot1,1))
pushf("MZ",rp(rot1,2))
pushf("MX",rp(rot1,3))
pushf("PY",rp(rot2,1))
pushf("MY",rp(rot3,1),rott)
local file=io.open("models/nc_paint.obj","w")
file:write(table.concat({table.concat(obj1,"\n"),table.concat(obj2,"\n")},"\n"))
file:close()
