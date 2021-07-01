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
local function waitdraw(pos,below,pid,x,y,ur,ug,ub,sh)
	if not nodecore.writing_writable(below) or minetest.get_node(pos).name~=modname..":painting" then return end
	local pb=database[minetest.pos_to_string(pos)]
	if not pb then
		minetest.after(0,waitdraw,pos,below,pid,x,y,ur,ug,ub,sh)
		return
	end
	local buf=pb.bufs[pid]
	buf.dirty=true
	print("BUFSET",x,y,ur,ug,ub)
	local x1,y1,x2,y2=x,y,x,y
	if sh then
		x1,y1=x1-1,y1-1
		x2,y2=x2+1,y2+1
	end
	local rx,ry=x,y
	for x=x1,x2 do for y=y1,y2 do
		if x==rx and y==ry then
			buf:set(x,y,ur,ug,ub)
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
			print("chachacha",x,y,x-mx*w,y-my*w)
			if nodecore.writing_writable(below) and nodecore.buildable_to(pos) then
				if minetest.get_node_or_nil(pos) and minetest.get_node(pos).name~=modname..":painting" then
					minetest.set_node(pos,{name=modname..":painting"})
					spawnent(pos)
				end
				waitdraw(pos,below,pid,x-mx*w,y-my*w,ur,ug,ub,false)
			end
		end
	end end
end
local function draw(p,ur,ug,ub,sh)
	print(minetest.get_node(p.above).name,minetest.get_node(p.under).name)
	if not (nodecore.writing_writable(p.under) and nodecore.buildable_to(p.above)) then print("BAD") return end
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
	if minetest.get_node_or_nil(pos) and minetest.get_node(pos).name~=modname..":painting" then
		minetest.set_node(pos,{name=modname..":painting"})
		spawnent(pos)
	end
	x,y=math.floor((x+0.5)*(w)+1),math.floor((y+0.5)*(w)+1)
	print(string.format("painting %s-%s-%s at %s %s",ur,ug,ub,x,y))
	waitdraw(pos,p.under,pid,x,y,ur,ug,ub,sh)
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
local function to_cstr(c,m,y)
	local r,g,b=5-c,5-m,5-y
	return minetest.rgba(r*(255/5),g*(255/5),b*(255/5))
end
local function gendesc(c,m,y)
	return string.format("(TECHNICAL COLORNAME (HUMAN NAMES TODO): CYAN-MAGENTA-YELLOW (0-5): %s-%s-%s)",c,m,y)
end
for c=0,5 do for m=0,5 do for y=0,5 do
	local nn=modname..":paint_"..string.format("%s%s%s",c,m,y)
	print(nn)
	local cstr=to_cstr(c,m,y)
	print(cstr)
	minetest.register_craftitem(nn,{
		description="Paint",
		inventory_image="nc_concrete_etched.png^[mask:nc_fire_lump.png^[multiply:"..cstr,
		sounds=nodecore.sounds("nc_terrain_crunchy"),
		nc_paint_color={c,m,y},
		groups={nc_paint=1},
		on_place=function()
		end
	})
end end end
local pldb={}
minetest.register_globalstep(function(dt)
	for k,pl in ipairs(minetest.get_connected_players()) do
		local wi=pl:get_wielded_item()
		local name=pl:get_player_name()
		local def=minetest.registered_items[wi:get_name()]
		if def.groups.nc_paint==1 then
			local cc=pl:get_player_control()
			if cc.place then
				local ll=pldb[name] or {}
				local props=pl:get_properties()
				local ff=vector.add(pl:get_eye_offset(),{x=0,y=props.eye_height,z=0})
				local rcp=vector.add(pl:get_pos(),ff)
				local vd=vector.multiply(pl:get_look_dir(),5)
				local rcp1,vd1=ll.rcp or rcp,ll.vd or vd
				local step=1/4
				for n=step,1,step do
					local rcpa=vector.add(vector.multiply(rcp,1-n),vector.multiply(rcp1,n))
					local vda=vector.add(vector.multiply(vd,1-n),vector.multiply(vd1,n))
					local rc=minetest.raycast(rcpa,vector.add(rcpa,vda),false,false)
					local cn=rc:next()
					if cn then
						local a,b,c=unpack(def.nc_paint_color)
						draw(cn,a,b,c,not cc.sneak)
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
