local modname=minetest.get_current_modname()
local texgen=dofile(minetest.get_modpath(modname).."/texgen.lua")
local fngen=dofile(minetest.get_modpath(modname).."/fngen.lua")
local w=8
function gtt(r,g,b)
	local buf=texgen.buf_new(w,w)
	for x=1,w do
		for y=1,w do
			buf:set(x,y,5-r,5-g,5-b)
		end
	end
	buf:set(1,1,0,0,0)
	return texgen.render(buf)
end
function ge()
	return texgen.render(texgen.buf_new(w,w))
end
local database={}
minetest.register_node(modname..":test",{
	drawtype = "mesh",
	mesh="nc_paint.obj",
	walkable=false,
	paramtype = "light",
	sunlight_propagates=true,
	tiles={gtt(0,0,5),gtt(5,0,0),gtt(5,5,0),gtt(0,5,5),gtt(0,5,0),gtt(5,0,5)}
})
minetest.register_node(modname..":painting",{
	drawtype="airlike",
	walkable=false,
	pointable=false,
	paramtype="light",
	buildable_to=true,
	floodable=true,
	sunlight_propagates=true,
})
local function spawnent(pos)
	if not database[minetest.pos_to_string(pos)] then
		minetest.add_entity(pos,modname..":paintent",minetest.pos_to_string(pos))
	end
end
local facets={{0,0,1},{1,0,0},{0,0,-1},{-1,0,0},{0,1,0},{0,-1,0}}
for k,v in ipairs(facets) do
	facets[k]={x=v[1],y=v[2],z=v[3]}
end
local function update_tent(self)
	local node=minetest.get_node_or_nil(self.pos)
	local meta=minetest.get_meta(self.pos)
	if not node or node.name~=modname..":painting" then
		self.object:remove()
		return
	end
	local props=self.object:get_properties()
	local dirty=false
	local alldead=true
	for k,v in ipairs(database[self.spos].bufs) do
		local dir=facets[k]
		local cpos=vector.add(self.pos,dir)
		local sad=false
		if not minetest.get_node_or_nil(cpos) then
			sad=true
			alldead=false
		end
		if not nodecore.writing_writable(cpos) and not sad then
			v:clear()
			props.textures[k]=texgen.render(v)
			dirty=true
			meta:set_string("nc_paint_buf_"..k,texgen.buf_to_string(v))
		else
			if v.dirty or not v.empty then
				alldead=false
			end
			if v.dirty then
				dirty=true
				v.dirty=false
				props.textures[k]=texgen.render(v)
				meta:set_string("nc_paint_buf_"..k,texgen.buf_to_string(v))
			end
		end
	end
	if alldead then
		minetest.set_node(self.pos,{name="air"})
		self.object:remove()
		return
	end
	if dirty then
		self.object:set_properties(props)
	end
	self.steps=5
end
minetest.register_entity(modname..":paintent",{ -- PAIN TENT
	initial_properties = {
		visual="mesh",
		mesh="nc_paint.obj",
		physical=false,
		visual_size={x=10,y=10,z=10},
		collide_with_objects=false,
		pointable=false,
		static_save=false,
		textures={gtt(0,0,5),gtt(5,0,0),gtt(5,5,0),gtt(0,5,5),gtt(0,5,0),gtt(5,0,5)},
		--textures={ge(),ge(),ge(),ge(),ge(),ge()}
	},
	on_activate = function(self,staticdata)
		self.pos=minetest.string_to_pos(staticdata)
		self.spos=staticdata
		if database[self.spos] then
			self.object:remove()
			return
		end
		local tt={}
		database[self.spos]=tt
		tt.bufs={}
		local node=minetest.get_node(self.pos)
		local meta=minetest.get_meta(self.pos)
		if node.name~=modname..":painting" then
			self.object:remove()
			return
		end
		for n=1,6 do
			local str=meta:get_string("nc_paint_buf_"..n)
			local buf=#str>0 and texgen.string_to_buf(str) or texgen.buf_new(w,w)
			buf.dirty=true
			tt.bufs[n]=buf
		end
		update_tent(self)
	end,
	on_deactivate = function(self)
		database[self.spos]=nil
	end,
	on_step = function(self)
		self.steps=math.max(0,(self.steps or 0)-1)
		if self.steps==0 then
			update_tent(self)
		end
	end,
	get_staticdata = function(self)
		return spos
	end
})
local function postoid(x,y,z)
	return string.format("%s_%s_%s",x,y,z)
end
faces={}
faces[postoid(0,0,-1)]=1
faces[postoid(-1,0,0)]=2
faces[postoid(0,0,1)]=3
faces[postoid(1,0,0)]=4
faces[postoid(0,-1,0)]=5
faces[postoid(0,1,0)]=6
local function waitdraw(pl,pos,below,pid,x,y,ur,ug,ub,sh)
	if not nodecore.writing_writable(below) or minetest.get_node(pos).name~=modname..":painting" then return end
	local pb=database[minetest.pos_to_string(pos)]
	if not pb then
		minetest.after(0,waitdraw,pl,pos,below,pid,x,y,ur,ug,ub,sh)
		return
	end
	local buf=pb.bufs[pid]
	buf.dirty=true
	--print("BUFSET",x,y,ur,ug,ub)
	local x1,y1,x2,y2=x,y,x,y
	if sh then
		x1,y1=x1-1,y1-1
		x2,y2=x2+1,y2+1
	end
	local rx,ry=x,y
	for x=x1,x2 do for y=y1,y2 do
		if x==rx and y==ry then
			local our,oug,oub=buf:get(x,y)
			if our~=ur or oug~=ug or oub~=ub then
				local wi=pl:get_wielded_item()
				local def=minetest.registered_items[wi:get_name()] or {}
				if def.groups and def.groups.nc_paint and def.groups.nc_paint>0 then
					local aur,aug,aub=unpack(def.nc_paint_color or {})
					if aur==ur and aug==ug and aub==ub then
						--print("WEAR")
						local ss=math.floor(65535/768)
						local wear=wi:get_wear()+ss
						local do_set=math.random()>wi:get_meta():get_float("paint_dry")
						if wear>=65535 then
							wi=ItemStack()
						else
							wi:set_wear(wear)
						end
						pl:set_wielded_item(wi)
						if do_set then
							buf:set(x,y,ur,ug,ub)
						end
					else
						--print("BBBBBBBB")
					end
				else
					--print("AAAAAAAA",minetest.get_item_group(wi,"nc_paint"),wi:get_name(),wi:get_count())
				end
			end
		else
			assert(sh,string.format("range: (%s %s; %s %s); xy: (%s %s); rxy: (%s %s)",x1,y1,x2,y2,x,y,rx,ry,x==rx and y==ry))
			local mx,my=math.floor((x-1)/w),math.floor((y-1)/w)
			local ox,oy,oz=0,0,0
			if pid==1 or pid==3 then
				ox,oy,oz=mx,-my,0 -- x=rp.x y=-rp.y
				if pid==3 then
					ox=-ox
				end
			elseif pid==2 or pid==4 then
				ox,oy,oz=0,-my,-mx -- -x=rp.z -y=rp.y
				if pid==4 then
					oz=-oz
				end
			elseif pid==5 or pid==6 then
				ox,oy,oz=mx,0,my
			end
			local op={x=ox,y=oy,z=oz}
			local pos=vector.add(pos,op)
			local below=vector.add(below,op)
			--print("chachacha",x,y,x-mx*w,y-my*w)
			local abname=minetest.get_node(pos).name
			if nodecore.writing_writable(below) and (abname=="air" or abname==modname..":painting") then
				if minetest.get_node_or_nil(pos) and minetest.get_node(pos).name~=modname..":painting" then
					minetest.set_node(pos,{name=modname..":painting"})
					spawnent(pos)
				end
				waitdraw(pl,pos,below,pid,x-mx*w,y-my*w,ur,ug,ub,false)
			end
		end
	end end
end
	local function draw(pl,p,ur,ug,ub,sh,ll)
	--print(minetest.get_node(p.above).name,minetest.get_node(p.under).name)
	local abname=minetest.get_node(p.above).name
	if not (nodecore.writing_writable(p.under) and (abname=="air" or abname==modname..":painting")) then --[[print("BAD")]] return end
	local paint_to=p.above
	local pp=p.intersection_normal
	pp=vector.round(vector.normalize(pp))
	local pid=faces[postoid(pp.x,pp.y,pp.z)]
	assert(pid)
	local rp=vector.subtract(p.intersection_point,p.above)
	local x,y
	if pid==1 or pid==3 then
		x,y=rp.x,-rp.y
		if pid==3 then
			x=-x
		end
	elseif pid==2 or pid==4 then
		x,y=-rp.z,-rp.y
		if pid==4 then
			x=-x
		end
	elseif pid==5 or pid==6 then
		x,y=rp.x,rp.z
	end
	local pos=p.above
	x,y=math.floor((x+0.5)*(w)+1),math.floor((y+0.5)*(w)+1)
	local phash = vector.to_string(p.under).."_("..x..","..y..")"
	if phash==ll.phash then return end
	ll.phash=phash
	if minetest.get_node_or_nil(pos) and minetest.get_node(pos).name~=modname..":painting" then
		minetest.set_node(pos,{name=modname..":painting"})
		spawnent(pos)
	end
	--print(string.format("painting %s-%s-%s at %s %s",ur,ug,ub,x,y))
	waitdraw(pl,pos,p.under,pid,x,y,ur,ug,ub,sh)
end
minetest.register_abm({
	label="painting aaa",
	nodenames={modname..":painting"},
	interval=1,
	chance=1,
	action=function(pos,node)
		spawnent(pos)
	end
})
local shwaba=1/16
local function cbaba(x)
	return math.floor(shwaba*255+x*(1-shwaba)+0.5)
end
local function to_mrgb(c,m,y)
	local r,g,b=5-c,5-m,5-y
	return cbaba(r*(255/5)),cbaba(g*(255/5)),cbaba(b*(255/5))
end
local function gendesc(c,m,y)
	return string.format("(TECHNICAL COLORNAME (HUMAN NAMES TODO): CYAN-MAGENTA-YELLOW (0-5): %s-%s-%s)",c,m,y)
end
local allpaints={}
for c=0,5 do for m=0,5 do for y=0,5 do
	local nn=modname..":paint_"..string.format("%s%s%s",c,m,y)
	print(nn)
	local r,g,b=to_mrgb(c,m,y)
	local cstr=minetest.rgba(r,g,b)
	print(cstr)
	allpaints[#allpaints+1]=nn
	local base_tex = "nc_concrete_etched.png^[mask:nc_fire_lump.png"
	local tex=base_tex.."^[multiply:"..cstr
	local overtex=tex.."^[mask:nc_paint_drymask_8.png"
	minetest.register_tool(nn,{
		description="Paint",
		inventory_rgb={r,g,b},
		inventory_base=tex,
		inventory_image=base_tex,
		inventory_overlay=overtex,
		color=minetest.rgba(r,g,b),
		sounds=nodecore.sounds("nc_terrain_crunchy"),
		nc_paint_color={c,m,y},
		groups={nc_paint=1,flammable=1},
		on_place=function()
		end
	})
end end end

nodecore.register_soaking_aism({
	label = "paint decomposing/composing",
	fieldname = "ncpaint",
	interval=3,
	chance=1,
	itemnames=allpaints,
	soakrate=function(stack,data)
		local pos = data.pos or data.player and data.player:get_pos()
		local qnch=nodecore.quenched(pos)
		if qnch then
			return -1*qnch
		end
		local moist=#nodecore.find_nodes_around(pos,"group:moist",2)
		local hot=#nodecore.find_nodes_around(pos,"group:radiant_heat",2)
		return 0.5*(1-math.min(1,moist/6)*1.6)+math.min(1,hot/2)*4
	end,
	soakcheck=function(data,stack)
		local meta = stack:get_meta()
		local off = data.total/8 * (3/5)
		local dry = math.max(0,math.min(0.95,meta:get_float("paint_dry")+off))
		meta:set_float("paint_dry",dry)
		local drynorm = dry*(1/0.95)
		local tex = "nc_paint_drymask_".. (1+math.floor(drynorm*7+0.5)) .. ".png"
		local def=minetest.registered_items[stack:get_name()]
		tex = def.inventory_base .. "^[mask:" .. tex
		local r,g,b = unpack(def.inventory_rgb)
		local function int(a,b,...)
			local o = math.floor(127*drynorm+a*(1-drynorm))
			if b then return o,int(b,...) end
			return o
		end
		meta:set_string("inventory_image", "^[opacity:0")
		meta:set_string("inventory_overlay", tex)
		meta:set_string("color",minetest.rgba(int(r,g,b)))
		return 0,stack
	end
})

local flcidtopain

local function randround(a,rr)
	local fl=math.floor(a)
	local fr=a-fl
	rr=rr or math.random()
	return (rr)>fr and fl or (fl+1)
end

do
	local shapes = {
		{name = "Bell", size = 1/4},
		{name = "Cup", size = 1/4},
		{name = "Rosette", size = 1/4},
		{name = "Cluster", param2 = 2, size = 3/8},
		{name = "Star", param2 = 4, size = 3/8},
	}

	local colors = {
		{name = "Pink", color = "ff0080"},
		{name = "Red", color = "ff0000"},
		{name = "Orange", color = "ff8000"},
		{name = "Yellow", color = "ffff00"},
		{name = "White", color = "ffffff"},
		{name = "Azure", color = "00ffff"},
		{name = "Blue", color = "0000ff"},
		{name = "Violet", color = "8000ff"},
		{name = "Black", color = "000000"},
	}

	local function hextorgb(hex)
		return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
	end

	local function rgbtomyrgb(r,g,b)
		r,g,b=255-r,255-g,255-b
		r,g,b=r/255*5,g/255*5,b/255*5
		return r,g,b
	end

	flcidtopain=function(flcid)
		local color=colors[flcid].color
		local r,g,b = rgbtomyrgb(hextorgb(color))
		local rr=math.random()
		return randround(r,rr),randround(g,rr),randround(b,rr)
	end
end

nodecore.register_craft({
	label = "paint synthesis",
	action = "pummel",
	toolgroups = {thumpy=1},
	nodes = {
		{match = {groups={flower_living=1}},replace="air"}
	},
	before = function(pos)
		local stack = nodecore.stack_get(pos)
		local def
		if (not stack) or stack:is_empty() then
			local node = minetest.get_node(pos)
			def = minetest.registered_nodes[node.name]
		else
			def = stack:get_definition()
		end
		local r,g,b = flcidtopain(def.nc_flower_color)
		local iname=modname..":paint_"..r..g..b
		nodecore.item_eject(pos,iname)
	end
})

local function rgb_to_hsv(r,g,b)
	local ma,mi = math.max(r,g,b),math.min(r,g,b)
	local h,s,v = ma,ma,ma
	local d = ma-mi
	s = ma==0 and 0 or d/ma
	if ma==mi then
		h=0
	else
		if ma==r then
			h=(g-b)/d+(g<b and 6 or 0)
		elseif ma==g then
			h=(b-r)/d+2
		elseif ma==b then
			h=(r-g)/d+4
		end
		h=h/6
	end
	return h,s,v
end

local function hsv_to_rgb(h,s,v)
	local r,g,b
	local i=math.floor(h*6)
	local f=h*6-i
	local p=v*(1-s)
	local q=v*(1-f*s)
	local t=v*(1-(1-f)*s)
	local i6=i%6
	if i6==0 then
		r,g,b=v,t,p
	elseif i6==1 then
		r,g,b=q,v,p
	elseif i6==2 then
		r,g,b=p,v,t
	elseif i6==3 then
		r,g,b=p,q,v
	elseif i6==4 then
		r,g,b=t,p,v
	elseif i6==5 then
		r,g,b=v,p,q
	end
	return r,g,b
end

local function hmix(h1,h2,w1,w2)
	h1,h2=h1%1,h2%1
	local hm1,hp1=h1-1,h1+1
	local dm,dp,dn=math.abs(hm1-h2),math.abs(hp1-h2),math.abs(h1-h2)
	local md=math.min(dm,dp,dn)
	if md==dm then
		return ((hm1*w1+h2*w2)/(w1+w2))%1
	elseif md==dp then
		return ((hp1*w1+h2*w2)/(w1+w2))%1
	elseif md==dn then
		return ((h1*w1+h2*w2)/(w1+w2))%1
	end
	return error("wat")
end

local function mix(c1,m1,y1,c2,m2,y2)
	local r1,g1,b1=1-c1/5,1-m1/5,1-y1/5
	local r2,g2,b2=1-c2/5,1-m2/5,1-y2/5
	local h1,s1,v1=rgb_to_hsv(r1,g1,b1)
	local h2,s2,v2=rgb_to_hsv(r2,g2,b2)
	local h,s,v=hmix(h1,h2,s1*v1,s2*v2),(s1+s2)/2,(v1+v2)/2
	local r,g,b=hsv_to_rgb(h,s,v)
	return (1-r)*5,(1-g)*5,(1-b)*5
end

local function paint_mixable(stack)
	if stack:get_meta():get_float("paint_dry") > 1/16 then return false end
	return true
end

nodecore.register_craft({
	label = "paint merge",
	action="pummel",
	toolgroups = {thumpy=1},
	nodes = {
		{match = {groups={nc_paint=1}},replace="air"},
		{match = {groups={nc_paint=1}},replace="air", y=-1}
	},
	check=function(pos)
		local posbot=vector.add(pos,vector.new(0,-1,0))
		local node=nodecore.stack_get(pos)
		local node1=nodecore.stack_get(posbot)
		return paint_mixable(node) and paint_mixable(node1)
	end,
	before = function(pos)
		local posbot=vector.add(pos,vector.new(0,-1,0))
		local node=nodecore.stack_get(pos)
		local node1=nodecore.stack_get(posbot)
		local def1 = minetest.registered_items[node:get_name()]
		local def2=minetest.registered_items[node1:get_name()]
		local r1,g1,b1=unpack(def1.nc_paint_color)
		local r2,g2,b2=unpack(def2.nc_paint_color)
		local r,g,b=mix(r1,g1,b1,r2,g2,b2)
		for n=1,2 do
			local rr=math.random()
			local r,g,b=randround(r,rr),randround(g,rr),randround(b,rr)
			local iname=modname..":paint_"..r..g..b
			iname = ItemStack(iname)
			iname:set_wear(math.round(node:get_wear()/2+node1:get_wear()/2))
			nodecore.item_eject(posbot,iname)
		end
	end
})

local function get_hand_range(pl)
	local handreal=minetest.registered_items[""] or {}
	local wieldplst=pl:get_wielded_item()
	local handplst=pl:get_inventory():get_stack("hand",1)
	local range
	if wieldplst:get_count()>0 then
		local w=minetest.registered_items[wieldplst:get_name()] or {}
		range=range or w.range
	end
	if handplst:get_count()>0 then
		local w=minetest.registered_items[handplst:get_name()] or {}
		range=range or w.range
	end
	range=range or handreal.range
	return range or 4
end

local pldb={}
minetest.register_globalstep(function(dt)
	for k,pl in ipairs(minetest.get_connected_players()) do
		local wi=pl:get_wielded_item()
		local name=pl:get_player_name()
		local def=minetest.registered_items[wi:get_name()]
		if def and def.groups.nc_paint==1 then
			local cc=pl:get_player_control()
			if cc.place then
				local ll=pldb[name] or {}
				local props=pl:get_properties()
				local ff=vector.add(pl:get_eye_offset(),{x=0,y=props.eye_height,z=0})
				local rcp=vector.add(pl:get_pos(),ff)
				--print(get_hand_range(pl))
				local vd=vector.multiply(pl:get_look_dir(),get_hand_range(pl))
				local rcp1,vd1=ll.rcp or rcp,ll.vd or vd
				local step=1/4
				for n=step,1,step do
					local rcpa=vector.add(vector.multiply(rcp,1-n),vector.multiply(rcp1,n))
					local vda=vector.add(vector.multiply(vd,1-n),vector.multiply(vd1,n))
					local rc=minetest.raycast(rcpa,vector.add(rcpa,vda),false,false)
					local cn=rc:next()
					if cn then
						local a,b,c=unpack(def.nc_paint_color)
						draw(pl,cn,a,b,c,not cc.sneak,ll)
					end
				end
				ll.rcp=rcp
				ll.vd=vd
				pldb[name]=ll
			else
				pldb[name]=nil
			end
		end
	end
end)
