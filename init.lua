local function get_hopper_formspec(pos)
	local spos = pos.x .. "," .. pos.y .. "," ..pos.z
	local formspec =
		"size[8,9]"
		.. default.gui_bg
		.. default.gui_bg_img
		.. default.gui_slots
		.. "list[nodemeta:" .. spos .. ";main;0,0.3;8,4;]"
		.. "list[current_player;main;0,4.85;8,1;]"
		.. "list[current_player;main;0,6.08;8,3;8]"
		.. "listring[nodemeta:" .. spos .. ";main]"
		.. "listring[current_player;main]"
	return formspec
end

-- hopper
minetest.register_node("hopper:hopper", {
	description = "Hopper",
	groups = {cracky = 3},
	drawtype = "nodebox",
	paramtype = "light",
	tiles = {"default_coal_block.png"},
	node_box = {
		type = "fixed",
		fixed = {
			--funnel walls
			{-0.5, 0.0, 0.4, 0.5, 0.5, 0.5},
			{0.4, 0.0, -0.5, 0.5, 0.5, 0.5},
			{-0.5, 0.0, -0.5, -0.4, 0.5, 0.5},
			{-0.5, 0.0, -0.5, 0.5, 0.5, -0.4},
			--funnel base
			{-0.5, 0.0, -0.5, 0.5, 0.1, 0.5},
			--spout
			{-0.3, -0.3, -0.3, 0.3, 0.0, 0.3},
			{-0.15, -0.3, -0.15, 0.15, -0.5, 0.15},
		},
	},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Hopper")
		local inv = meta:get_inventory()
		inv:set_size("main", 4*4) -- was 8*4
	end,

	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("main")
	end,

	on_rightclick = function(pos, node, clicker, itemstack)
		minetest.show_formspec(
			clicker:get_player_name(),
			"hopper:hopper",
			get_hopper_formspec(pos)
		)
	end,

	on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		minetest.log("action", player:get_player_name()
			.." moves stuff in hopper at "
			..minetest.pos_to_string(pos))
	end,

	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		minetest.log("action", player:get_player_name()
			.." moves stuff to hopper at "
			..minetest.pos_to_string(pos))
	end,

	on_metadata_inventory_take = function(pos, listname, index, stack, player)
		minetest.log("action", player:get_player_name()
			.." takes stuff from hopper at "
			..minetest.pos_to_string(pos))
	end,

	on_rotate = screwdriver.disallow,
})

-- side hopper
minetest.register_node("hopper:hopper_side", {
	description = "Side Hopper",
	groups = {cracky = 3},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	tiles = {"default_coal_block.png"},
	node_box = {
		type = "fixed",
		fixed = {
			--funnel walls
			{-0.5, 0.0, 0.4, 0.5, 0.5, 0.5},
			{0.4, 0.0, -0.5, 0.5, 0.5, 0.5},
			{-0.5, 0.0, -0.5, -0.4, 0.5, 0.5},
			{-0.5, 0.0, -0.5, 0.5, 0.5, -0.4},
			--funnel base
			{-0.5, 0.0, -0.5, 0.5, 0.1, 0.5},
			--spout
			{-0.3, -0.3, -0.3, 0.3, 0.0, 0.3},
			{-0.7, -0.3, -0.15, 0.15, 0.0, 0.15},
		},
	},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Side Hopper")
		local inv = meta:get_inventory()
		inv:set_size("main", 4*4) -- was 8*4
	end,

	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("main")
	end,

	on_rightclick = function(pos, node, clicker, itemstack)
		minetest.show_formspec(
			clicker:get_player_name(),
			"hopper:hopper_side",
			get_hopper_formspec(pos)
		)
	end,

	on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		minetest.log("action", player:get_player_name()
			.." moves stuff in hopper at "
			..minetest.pos_to_string(pos))
	end,

	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		minetest.log("action", player:get_player_name()
			.." moves stuff to hopper at "
			..minetest.pos_to_string(pos))
	end,

	on_metadata_inventory_take = function(pos, listname, index, stack, player)
		minetest.log("action", player:get_player_name()
			.." takes stuff from hopper at "
			..minetest.pos_to_string(pos))
	end,

	on_rotate = screwdriver.rotate_simple,
})

-- suck in items on top of hopper
minetest.register_abm({

	nodenames = {"hopper:hopper", "hopper:hopper_side"},
	interval = 1.0,
	chance = 1,

	action = function(pos, node)

		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		local posob

		for _,object in ipairs(minetest.get_objects_inside_radius(pos, 1)) do

			if not object:is_player()
			and object:get_luaentity()
			and object:get_luaentity().name == "__builtin:item"
			and inv
			and inv:room_for_item("main", ItemStack(object:get_luaentity().itemstring)) then

				posob = object:getpos()

				if math.abs(posob.x - pos.x) <= 0.5
				and posob.y - pos.y <= 0.85
				and posob.y - pos.y >= 0.3 then

					inv:add_item("main", ItemStack(object:get_luaentity().itemstring))
					object:get_luaentity().itemstring = ""
					object:remove()
				end
			end
		end
	end,
})

-- transfer function
local transfer = function(src, srcpos, dst, dstpos)

	-- source inventory
	local meta = minetest.get_meta(srcpos)
	local inv = meta:get_inventory()
	local invsize = inv:get_size(src)

	-- check for empty source
	if inv:is_empty(src) == true then
		return
	end

	-- destination inventory
	local meta2 = minetest.get_meta(dstpos)
	local inv2 = meta2:get_inventory()
	local invsize2 = inv2:get_size(dst)

	local stack, item

	-- transfer item
	for i = 1, invsize do

		stack = inv:get_stack(src, i)
		item = stack:get_name()

		-- if slot not empty
		if item ~= "" then

			-- room in destination?
			if inv2:room_for_item(dst, item) == false then
				return
			end

			-- is item a tool
			if stack:get_wear() > 0 then
				inv2:add_item(dst, stack:take_item(stack:get_count()))
				inv:set_stack(src, i, nil)
			else -- not a tool
				stack:take_item(1)
				inv2:add_item(dst, item)
				inv:set_stack(src, i, stack)
			end

			return

		end
	end

end

-- hopper transfer
minetest.register_abm({

	nodenames = {"hopper:hopper"},
	neighbors = {
		"default:chest", "default:chest_locked", "protector:chest",
		"hopper:hopper", "hopper:hopper_side", "default:furnace",
		"default:furnace_active"
	},
	interval = 1.0,
	chance = 1,

	action = function(pos, node)

		local min = {x = pos.x, y = pos.y - 1, z = pos.z}
		local max = {x = pos.x, y = pos.y + 1, z = pos.z}
		local vm = minetest.get_voxel_manip()
		local emin, emax = vm:read_from_map(min, max)
		local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
		local data = vm:get_data()
		local a = vm:get_node_at({x = pos.x, y = pos.y + 1, z = pos.z}).name
		local b = vm:get_node_at({x = pos.x, y = pos.y - 1, z = pos.z}).name

		--local a = minetest.get_node({x = pos.x, y = pos.y + 1, z = pos.z}).name
		--local b = minetest.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name

		-- input (from above)

		if a == "default:chest"
		or a == "default:chest_locked"
		or a == "protector:chest"
		or a == "hopper:hopper"
		or a == "hopper:hopper_side" then

			-- chest/hopper above to hopper below
			transfer("main", {
				x = pos.x,
				y = pos.y + 1,
				z = pos.z
			}, "main", pos)

		elseif a == "default:furnace"
		or a == "default:furnace_active" then

			-- furnace output above to hopper below
			transfer("dst", {
				x = pos.x,
				y = pos.y + 1,
				z = pos.z
			}, "main", pos)

		end

		-- output (to below)

		if b == "default:chest"
		or b == "default:chest_locked"
		or b == "protector:chest" then

			-- hopper above to chest below
			transfer("main", pos, "main", {
				x = pos.x,
				y = pos.y - 1,
				z = pos.z
			})

		elseif b == "default:furnace"
		or b == "default:furnace_active" then

			-- hopper above to furnace source below
			transfer("main", pos, "src", {
				x = pos.x,
				y = pos.y - 1,
				z = pos.z
			})
		end
	
	end,
})

-- hopper side
minetest.register_abm({

	nodenames = {"hopper:hopper_side"},
	neighbors = {
		"default:chest","default:chest_locked","protector:chest",
		"hopper:hopper","hopper:hopper_side","default:furnace","default:furnace_active"
	},
	interval = 1.0,
	chance = 1,

	action = function(pos, node)

		local min = {x = pos.x - 1, y = pos.y, z = pos.z - 1}
		local max = {x = pos.x + 1, y = pos.y + 1, z = pos.z + 1}
		local vm = minetest.get_voxel_manip()
		local emin, emax = vm:read_from_map(min, max)
		local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
		local data = vm:get_data()
		local face = vm:get_node_at(pos).param2

		local front = {}
		--local face = minetest.get_node(pos).param2 ; print(face)

		if face == 0 then
			front = {x = pos.x - 1, y = pos.y, z = pos.z}
		elseif face == 1 then
			front = {x = pos.x, y = pos.y, z = pos.z + 1}
		elseif face == 2 then
			front = {x = pos.x + 1, y = pos.y, z = pos.z}
		elseif face == 3 then
			front = {x = pos.x, y = pos.y, z = pos.z - 1}
		else
			return
		end

		local a = vm:get_node_at({x = pos.x, y = pos.y + 1,z = pos.z}).name
		local b = vm:get_node_at(front).name

--		local a = minetest.get_node({x = pos.x, y = pos.y + 1, z = pos.z}).name
--		local b = minetest.get_node(front).name

		-- input (from above)

		if a == "default:chest"
		or a == "default:chest_locked"
		or a == "protector:chest"
		or a == "hopper:hopper"
		or a == "hopper:hopper_side" then

			-- chest/hopper above to hopper below
			transfer("main", {
				x = pos.x,
				y = pos.y + 1,
				z = pos.z
			}, "main", pos)

		elseif a == "default:furnace"
		or a == "default:furnace_active" then

			-- furnace output above to hopper below
			transfer("dst", {
				x = pos.x,
				y = pos.y + 1,
				z = pos.z
			}, "main", pos)

		end

		-- output (to side)

		if b == "default:chest"
		or b == "default:chest_locked"
		or b == "protector:chest"
		or b == "hopper:hopper"
		or b == "hopper:hopper_side" then

			-- hopper to chest beside
			transfer("main", pos, "main", front)
			
		elseif b == "default:furnace"
		or b == "default:furnace_active" then

			-- hopper to furnace fuel beside
			transfer("main", pos, "fuel", front)
		end
		
	end,
})

-- hopper recipe
minetest.register_craft({
	output = "hopper:hopper",
	recipe = {
		{"default:steel_ingot", "", "default:steel_ingot"},
		{"default:steel_ingot", "default:chest", "default:steel_ingot"},
		{"", "default:steel_ingot", ""},
	},
})

-- hopper to side hopper recipe
minetest.register_craft({
	output = "hopper:hopper",
	recipe = {
		{"hopper:hopper_side"},
	},
})

-- side hopper back to hopper recipe
minetest.register_craft({
	output = "hopper:hopper_side",
	recipe = {
		{"hopper:hopper"},
	},
})
