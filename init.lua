hopper = {}
hopper.targets = {}
hopper.neighbors = {}

local texture_resolution = minetest.setting_get("hopper_texture_size")
if texture_resolution == nil then
	texture_resolution = "16"
end

local single_craftable_item = minetest.setting_getbool("hopper_single_craftable_item")
if single_craftable_item == nil then
	single_craftable_item = true
end

local function add_inventory(hopper_name, source_or_destination, target_node, target_inventory)
	if hopper.targets[hopper_name] == nil then
		hopper.targets[hopper_name] = {[source_or_destination] = {[target_node] = target_inventory}}
	elseif hopper.targets[hopper_name][source_or_destination] == nil then
		hopper.targets[hopper_name][source_or_destination] = {[target_node] = target_inventory}
	else
		hopper.targets[hopper_name][source_or_destination][target_node] = target_inventory
	end
	
	for _, value in pairs(hopper.neighbors) do
		if value == target_node then
			return
		end
	end
	table.insert(hopper.neighbors, target_node)
end

-- These two following methods are available for other mods to hook their nodes up to hoppers.

-- Adds a node type that hoppers will take items from when it's located in the hopper's source loication, and defines what inventory name the hopper takes items from
hopper.add_source = function(hopper_name, source_node, source_inventory)
	add_inventory(hopper_name, "source", source_node, source_inventory)
end

-- Adds a node type that hoppers will put items into when it's located in the hopper's destination loication, and defines what inventory name the hopper puts items into
hopper.add_destination = function(hopper_name, destination_node, destination_inventory)
	add_inventory(hopper_name, "destination", destination_node, destination_inventory)
end

-- Build the default sources and destinations
hopper.add_source("hopper:hopper", "default:chest", "main")
hopper.add_source("hopper:hopper", "hopper:hopper", "main")
hopper.add_source("hopper:hopper", "hopper:hopper_side", "main")
hopper.add_source("hopper:hopper", "default:furnace", "dst")
hopper.add_source("hopper:hopper", "default:furnace_active", "dst")
hopper.add_destination("hopper:hopper", "default:chest", "main")
hopper.add_destination("hopper:hopper", "hopper:hopper", "main")
hopper.add_destination("hopper:hopper", "hopper:hopper_side", "main")
hopper.add_destination("hopper:hopper", "default:furnace", "src")
hopper.add_destination("hopper:hopper", "default:furnace_active", "src")
hopper.add_source("hopper:hopper_side", "default:chest", "main")
hopper.add_source("hopper:hopper_side", "hopper:hopper", "main")
hopper.add_source("hopper:hopper_side", "hopper:hopper_side", "main")
hopper.add_source("hopper:hopper_side", "default:furnace", "dst")
hopper.add_source("hopper:hopper_side", "default:furnace_active", "dst")
hopper.add_destination("hopper:hopper_side", "default:chest", "main")
hopper.add_destination("hopper:hopper_side", "hopper:hopper", "main")
hopper.add_destination("hopper:hopper_side", "hopper:hopper_side", "main")
hopper.add_destination("hopper:hopper_side", "default:furnace", "fuel")
hopper.add_destination("hopper:hopper_side", "default:furnace_active", "fuel")

-- Support wine mod.
hopper.add_source("hopper:hopper", "wine:wine_barrel", "dst")
hopper.add_destination("hopper:hopper", "wine:wine_barrel", "src")
hopper.add_source("hopper:hopper_side", "wine:wine_barrel", "dst")
hopper.add_destination("hopper:hopper_side", "wine:wine_barrel", "src")

local hopper_long_desc = "Hopper to transfer items between neighboring blocks' inventories"
local hopper_usage = "Items are transfered from the block at the wide end of the hopper to the block at the narrow end of the hopper at a rate of one per second. Items can also be placed directly into the hopper's inventory, or they can be dropped into the space above a hopper and will be sucked into the hopper's inventory automatically.\n\n"
if single_craftable_item then
	hopper_usage = hopper_usage .. "Hopper blocks come in both 'vertical' and 'side' forms, but when in a player's inventory both are represented by a single generic item. The type of hopper block that will be placed when the player uses this item depends on what is pointed at - when the hopper item is pointed at the top or bottom face of a block a vertical hopper is placed, when aimed at the side of a block a side hopper is produced that connects to the clicked-on side.\n\n"
else
	hopper_usage = hopper_usage .. "Hopper blocks come in both 'vertical' and 'side' forms. They can be interconverted between the two forms via the crafting grid.\n\n"
end
hopper_usage = hopper_usage .. "When used with furnaces, vertical hoppers inject items into the furnace's \"raw material\" inventory slot and side hoppers inject items into the furnace's \"fuel\" inventory slot.\n\nItems that cannot be placed in a target block's inventory will remain in the hopper."

-- formspec
local function get_hopper_formspec(pos)

	local spos = pos.x .. "," .. pos.y .. "," ..pos.z
	local formspec =
		"size[8,9]"
		.. default.gui_bg
		.. default.gui_bg_img
		.. default.gui_slots
		.. "list[nodemeta:" .. spos .. ";main;2,0.3;4,4;]"
		.. "list[current_player;main;0,4.85;8,1;]"
		.. "list[current_player;main;0,6.08;8,3;8]"
		.. "listring[nodemeta:" .. spos .. ";main]"
		.. "listring[current_player;main]"

	return formspec
end

local hopper_drop
local hopper_groups
if single_craftable_item then
	hopper_drop = "hopper:hopper_item"
	hopper_groups = {cracky=3, not_in_creative_inventory = 1}
else
	hopper_drop = "hopper:hopper"
	hopper_groups = {cracky=3}
end

minetest.register_node("hopper:hopper", {
	drop = hopper_drop,
	description = "Hopper",
	_doc_items_longdesc = hopper_long_desc,
    _doc_items_usagehelp = hopper_usage,
	groups = hopper_groups,
	drawtype = "nodebox",
	paramtype = "light",
	tiles = {"hopper_top_" .. texture_resolution .. ".png", "hopper_top_" .. texture_resolution .. ".png", "hopper_front_" .. texture_resolution .. ".png"},
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
		local inv = minetest.get_meta(pos):get_inventory()
		inv:set_size("main", 4*4)
	end,

	can_dig = function(pos,player)
		local inv = minetest.get_meta(pos):get_inventory()
		return inv:is_empty("main")
	end,

	on_rightclick = function(pos, node, clicker, itemstack)
		if minetest.is_protected(pos, clicker:get_player_name()) then
			return
		end
		minetest.show_formspec(clicker:get_player_name(),
			"hopper:hopper", get_hopper_formspec(pos))
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
})

local hopper_side_drop
if single_craftable_item then
	hopper_side_drop = "hopper:hopper_item"
else
	hopper_side_drop = "hopper:hopper_side"
end

minetest.register_node("hopper:hopper_side", {
	description = "Side Hopper",
	_doc_items_longdesc = hopper_long_desc,
    _doc_items_usagehelp = hopper_usage,
	drop = hopper_side_drop,
	groups = hopper_groups,
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	tiles = {
		"hopper_top_" .. texture_resolution .. ".png", "hopper_bottom_" .. texture_resolution .. ".png", "hopper_back_" .. texture_resolution .. ".png",
		"hopper_side_" .. texture_resolution .. ".png", "hopper_back_" .. texture_resolution .. ".png", "hopper_back_" .. texture_resolution .. ".png"
	},
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
		local inv = minetest.get_meta(pos):get_inventory()
		inv:set_size("main", 4*4)
	end,

	can_dig = function(pos,player)
		local inv = minetest.get_meta(pos):get_inventory()
		return inv:is_empty("main")
	end,

	on_rightclick = function(pos, node, clicker, itemstack)
		if minetest.is_protected(pos, clicker:get_player_name()) then
			return
		end
		minetest.show_formspec(clicker:get_player_name(),
			"hopper:hopper_side", get_hopper_formspec(pos))
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
})

-- suck in items on top of hopper
minetest.register_abm({
	label = "Hopper suction",
	nodenames = {"hopper:hopper", "hopper:hopper_side"},
	interval = 1.0,
	chance = 1,
	action = function(pos, node)
		local inv = minetest.get_meta(pos):get_inventory()
		local posob

		for _,object in pairs(minetest.get_objects_inside_radius(pos, 1)) do
			if not object:is_player()
			and object:get_luaentity()
			and object:get_luaentity().name == "__builtin:item"
			and inv
			and inv:room_for_item("main",
				ItemStack(object:get_luaentity().itemstring)) then

				posob = object:getpos()

				if math.abs(posob.x - pos.x) <= 0.5
				and posob.y - pos.y <= 0.85
				and posob.y - pos.y >= 0.3 then

					inv:add_item("main",
						ItemStack(object:get_luaentity().itemstring))

					object:get_luaentity().itemstring = ""
					object:remove()
				end
			end
		end
	end,
})

local function take_item_from(hopper_pos, target_pos, target_node, target_inventory_name)
	if target_inventory_name == nil then
		return
	end

	--hopper inventory
	local hopper_meta = minetest.get_meta(hopper_pos);
	local hopper_inv = hopper_meta:get_inventory()
	local placer = minetest.get_player_by_name(hopper_meta:get_string("placer"))

	--source inventory
	local target_inv = minetest.get_meta(target_pos):get_inventory()
	local target_inv_size = target_inv:get_size(target_inventory_name)
	local target_def = minetest.registered_nodes[target_node.name]
	if target_inv:is_empty(target_inventory_name) == false then
		for i = 1,target_inv_size do
			local stack = target_inv:get_stack(target_inventory_name, i)
			local item = stack:get_name()
			if item ~= "" then
				if hopper_inv:room_for_item("main", item) then
					local stack_to_take = stack:take_item(1)
					if target_def.allow_metadata_inventory_take == nil
					  or placer == nil -- backwards compatibility, older versions of this mod didn't record who placed the hopper
					  or target_def.allow_metadata_inventory_take(target_pos, target_inventory_name, i, stack_to_take, placer) > 0 then		
						target_inv:set_stack(target_inventory_name, i, stack)
						--add to hopper
						hopper_inv:add_item("main", item)
						if target_def.on_metadata_inventory_take ~= nil and placer ~= nil then
							target_def.on_metadata_inventory_take(target_pos, target_inventory_name, i, stack_to_take, placer)
						end
						break
					end
				end
			end
		end
	end
end

local function send_item_to(hopper_pos, target_pos, target_node, target_inventory_name)
	if target_inventory_name == nil then
		return
	end

	--hopper inventory
	local hopper_meta = minetest.get_meta(hopper_pos);
	local hopper_inv = hopper_meta:get_inventory()
	if hopper_inv:is_empty("main") == true then
		return
	end
	local hopper_inv_size = hopper_inv:get_size("main")
	local placer = minetest.get_player_by_name(hopper_meta:get_string("placer"))
	
	--target inventory
	local target_inv = minetest.get_meta(target_pos):get_inventory()
	local target_def = minetest.registered_nodes[target_node.name]

	for i = 1,hopper_inv_size do
		local stack = hopper_inv:get_stack("main", i)
		local item = stack:get_name()
		if item ~= "" then
			if target_inv:room_for_item(target_inventory_name, item) then
				local stack_to_put = stack:take_item(1)
				if target_def.allow_metadata_inventory_put == nil
				  or placer == nil -- backwards compatibility, older versions of this mod didn't record who placed the hopper
				  or target_def.allow_metadata_inventory_put(target_pos, target_inventory_name, i, stack_to_put, placer) > 0 then
					hopper_inv:set_stack("main", i, stack)
					--add to hopper or chest
					target_inv:add_item(target_inventory_name, item)
					if target_def.on_metadata_inventory_put ~= nil and placer ~= nil then
						target_def.on_metadata_inventory_put(target_pos, target_inventory_name, i, stack_to_put, placer)
					end
					break
				end
			end
		end
	end
end

-- This was tedious to populate and test
local directions = {
	[0]={["src"]={x=0, y=1, z=0},["dst"]={x=-1, y=0, z=0}},
	[1]={["src"]={x=0, y=1, z=0},["dst"]={x=0, y=0, z=1}},
	[2]={["src"]={x=0, y=1, z=0},["dst"]={x=1, y=0, z=0}},
	[3]={["src"]={x=0, y=1, z=0},["dst"]={x=0, y=0, z=-1}},
	[4]={["src"]={x=0, y=0, z=1},["dst"]={x=-1, y=0, z=0}},
	[5]={["src"]={x=0, y=0, z=1},["dst"]={x=0, y=-1, z=0}},
	[6]={["src"]={x=0, y=0, z=1},["dst"]={x=1, y=0, z=0}},
	[7]={["src"]={x=0, y=0, z=1},["dst"]={x=0, y=1, z=0}},
	[8]={["src"]={x=0, y=0, z=-1},["dst"]={x=-1, y=0, z=0}},
	[9]={["src"]={x=0, y=0, z=-1},["dst"]={x=0, y=1, z=0}},
	[10]={["src"]={x=0, y=0, z=-1},["dst"]={x=1, y=0, z=0}},
	[11]={["src"]={x=0, y=0, z=-1},["dst"]={x=0, y=-1, z=0}},
	[12]={["src"]={x=1, y=0, z=0},["dst"]={x=0, y=1, z=0}},
	[13]={["src"]={x=1, y=0, z=0},["dst"]={x=0, y=0, z=1}},
	[14]={["src"]={x=1, y=0, z=0},["dst"]={x=0, y=-1, z=0}},
	[15]={["src"]={x=1, y=0, z=0},["dst"]={x=0, y=0, z=-1}},
	[16]={["src"]={x=-1, y=0, z=0},["dst"]={x=0, y=-1, z=0}},
	[17]={["src"]={x=-1, y=0, z=0},["dst"]={x=0, y=0, z=1}},
	[18]={["src"]={x=-1, y=0, z=0},["dst"]={x=0, y=1, z=0}},
	[19]={["src"]={x=-1, y=0, z=0},["dst"]={x=0, y=0, z=-1}},
	[20]={["src"]={x=0, y=-1, z=0},["dst"]={x=1, y=0, z=0}},
	[21]={["src"]={x=0, y=-1, z=0},["dst"]={x=0, y=0, z=1}},
	[22]={["src"]={x=0, y=-1, z=0},["dst"]={x=-1, y=0, z=0}},
	[23]={["src"]={x=0, y=-1, z=0},["dst"]={x=0, y=0, z=-1}},
}

minetest.register_abm({
	nodenames = {"hopper:hopper", "hopper:hopper_side"},
	neighbors = hopper.neighbors,
	interval = 1.0,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)

		local min = {x=pos.x-1,y=pos.y-1,z=pos.z-1}
		local max = {x=pos.x+1,y=pos.y+1,z=pos.z+1}
		local vm = minetest.get_voxel_manip()	
		local emin, emax = vm:read_from_map(min,max)
		local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
		local data = vm:get_data()	

		local destination_pos, source_pos, destination_node, source_node, source_inventory, destination_inventory
		
		if node.name == "hopper:hopper_side" then
			local direction = directions[vm:get_node_at(pos).param2]
			destination_pos = vector.add(direction["dst"], pos)
			source_pos = vector.add(direction["src"], pos)
			destination_node = vm:get_node_at(destination_pos)
			source_node = vm:get_node_at(source_pos)
			source_inventory = hopper.targets["hopper:hopper_side"]["source"][source_node.name]
			destination_inventory = hopper.targets["hopper:hopper_side"]["destination"][destination_node.name]
		else
			source_pos = {x=pos.x,y=pos.y+1,z=pos.z}
			destination_pos = {x=pos.x,y=pos.y-1,z=pos.z}
			destination_node = vm:get_node_at(destination_pos)
			source_node = vm:get_node_at(source_pos)
			source_inventory = hopper.targets["hopper:hopper"]["source"][source_node.name]
			destination_inventory = hopper.targets["hopper:hopper"]["destination"][destination_node.name]
		end
		
		take_item_from(pos, source_pos, source_node, source_inventory)
		send_item_to(pos, destination_pos, destination_node, destination_inventory)
	end,
})

minetest.register_craftitem("hopper:hopper_item", {
	description = "Hopper",
	_doc_items_longdesc = hopper_long_desc,
    _doc_items_usagehelp = hopper_usage,
	inventory_image = "hopper_item_" .. texture_resolution .. ".png",
	on_place = function(itemstack, placer, pointed_thing)
		local pos  = pointed_thing.under
		local pos2 = pointed_thing.above

		local x = pos.x - pos2.x
		local y = pos.y - pos2.y
		local z = pos.z - pos2.z
		
		local placed = false

		if x == -1 then
			minetest.set_node(pos2, {name="hopper:hopper_side", param2=0})
			placed = true
		elseif x == 1 then
			minetest.set_node(pos2, {name="hopper:hopper_side", param2=2})
			placed = true
		elseif z == -1 then
			minetest.set_node(pos2, {name="hopper:hopper_side", param2=3})
			placed = true
		elseif z == 1 then
			minetest.set_node(pos2, {name="hopper:hopper_side", param2=1})
			placed = true
		else
			minetest.set_node(pos2, {name="hopper:hopper"})
			placed = true
		end
		if placed == true then
			local meta = minetest.get_meta(pos2)
			meta:set_string("placer", placer:get_player_name())
			if not minetest.setting_getbool("creative_mode") then
				itemstack:take_item()
			end
			return itemstack
		end
	end,
})

if single_craftable_item then
	minetest.register_craft({
		output = "hopper:hopper_item",
		recipe = {
			{"default:steel_ingot","default:chest","default:steel_ingot"},
			{"","default:steel_ingot",""},
		}
	})
else
	minetest.register_craft({
		output = "hopper:hopper",
		recipe = {
			{"default:steel_ingot","default:chest","default:steel_ingot"},
			{"","default:steel_ingot",""},
		}
	})

	minetest.register_craft({
		output = "hopper:hopper_side",
		recipe = {
			{"default:steel_ingot","default:chest","default:steel_ingot"},
			{"","","default:steel_ingot"},
		}
	})
	
	minetest.register_craft({
		output = "hopper:hopper_side",
		type="shapeless",
		recipe = {"hopper:hopper"},
	})

	minetest.register_craft({
		output = "hopper:hopper",
		type="shapeless",
		recipe = {"hopper:hopper_side"},
	})
end

-- add lucky blocks
if minetest.get_modpath("lucky_block") then
	if single_craftable_item then
		lucky_block:add_blocks({
			{"dro", {"hopper:hopper_item"}, 3},
			{"nod", "default:lava_source", 1},
		})
	else
		lucky_block:add_blocks({
			{"dro", {"hopper:hopper"}, 3},
			{"nod", "default:lava_source", 1},
		})
	end	
end

print ("[MOD] Hopper loaded")
