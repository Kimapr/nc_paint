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
local function update_tent(self)
	local node=minetest.get_node(self.pos)
	local meta=minetest.get_meta(self.pos)
	if node.name~=modname..":painting" then
		self.object:remove()
		return
	end
	local props=self.object:get_properties()
	local dirty=false
	for k,v in ipairs(database[self.spos].bufs) do
		if v.dirty then
			dirty=true
			v.dirty=false
			props.textures[k]=texgen.render(v)
			meta:set_string("nc_paint_buf_"..k,texgen.buf_to_string(v))
		end
	end
	if dirty then
		self.object:set_properties(props)
	end
end
local facets={{0,0,1},{1,0,0},{0,0,-1},{-1,0,0},{0,1,0},{0,-1,0}}
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
		update_tent(self)
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
local function waitdraw(pos,below,pid,x,y,ur,ug,ub)
	if not nodecore.writing_writable(below) or minetest.get_node(pos).name~=modname..":painting" then error() return end
	local pb=database[minetest.pos_to_string(pos)]
	if not pb then
		minetest.after(0,waitdraw,pos,below,pid,x,y,ur,ug,ub)
		return
	end
	local buf=pb.bufs[pid]
	buf.dirty=true
	print("BUFSET",x,y,ur,ug,ub)
	buf:set(x,y,ur,ug,ub)
end
local function draw(p,ur,ug,ub)
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
	if minetest.get_node(pos).name~=modname..":painting" then
		minetest.set_node(pos,{name=modname..":painting"})
		spawnent(pos)
	end
	x,y=math.floor((x+0.5)*(w)+1),math.floor((y+0.5)*(w)+1)
	print(string.format("painting %s-%s-%s at %s %s",ur,ug,ub,x,y))
	waitdraw(pos,p.under,pid,x,y,ur,ug,ub)
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
	return minetest.rgba(r,g,b)
end
local function gendesc(c,m,y)
	return string.format("(TECHNICAL COLORNAME (HUMAN NAMES TODO): CYAN-MAGENTA-YELLOW (0-5): %s-%s-%s)",c,m,y)
end
for c=0,5 do for m=0,5 do for y=0,5 do
	local nn=modname..":paint_"..fngen(c,m,y,true)
	print(nn)
	minetest.register_craftitem(nn,{
		description=gendesc(c,m,y).." Paint",
		inventory_image="nc_fire_ash.png^[mask:nc_fire_lump.png^[multiply:"..to_cstr(c,m,y),
		sounds=nodecore.sounds("nc_terrain_crunchy"),
		nc_paint_color={c,m,y},
		groups={nc_paint=1},
		on_place=function()
		end
	})
end end end
minetest.register_globalstep(function(dt)
	for k,pl in ipairs(minetest.get_connected_players()) do
		local wi=pl:get_wielded_item()
		local def=minetest.registered_items[wi:get_name()]
		if def.groups.nc_paint==1 then
			local cc=pl:get_player_control()
			if cc.place then
				local props=pl:get_properties()
				local ff=vector.add(pl:get_eye_offset(),{x=0,y=props.eye_height,z=0})
				print(dump(ff))
				local raycastp=vector.add(pl:get_pos(),ff)
				local vd=vector.multiply(pl:get_look_dir(),5)
				local rc=minetest.raycast(raycastp,vector.add(raycastp,vd),false,false)
				local cn=rc:next()
				if cn then
					draw(cn,unpack(def.nc_paint_color))
				end
			end
		end
	end
end)
