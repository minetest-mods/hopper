-- define global
hopper = {}

-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

-- settings
local texture_resolution = minetest.setting_get("hopper_texture_size")
if texture_resolution == nil then
	texture_resolution = "16"
end

local single_craftable_item = minetest.setting_getbool("hopper_single_craftable_item")
if single_craftable_item == nil then
	single_craftable_item = true
end

-- Documentation
local hopper_long_desc = S("Hopper to transfer items between neighboring blocks' inventories")
local hopper_usage = S("Items are transfered from the block at the wide end of the hopper to the block at the narrow end of the hopper at a rate of one per second. Items can also be placed directly into the hopper's inventory, or they can be dropped into the space above a hopper and will be sucked into the hopper's inventory automatically.\n\n")
if single_craftable_item then
	hopper_usage = hopper_usage .. S("Hopper blocks come in both 'vertical' and 'side' forms, but when in a player's inventory both are represented by a single generic item. The type of hopper block that will be placed when the player uses this item depends on what is pointed at - when the hopper item is pointed at the top or bottom face of a block a vertical hopper is placed, when aimed at the side of a block a side hopper is produced that connects to the clicked-on side.\n\n")
else
	hopper_usage = hopper_usage .. S("Hopper blocks come in both 'vertical' and 'side' forms. They can be interconverted between the two forms via the crafting grid.\n\n")
end
hopper_usage = hopper_usage .. S("When used with furnaces, vertical hoppers inject items into the furnace's \"raw material\" inventory slot and side hoppers inject items into the furnace's \"fuel\" inventory slot.\n\nItems that cannot be placed in a target block's inventory will remain in the hopper.\n\nHoppers have the same permissions as the player that placed them. Hoppers placed by you are allowed to take items from or put items into locked chests that you own, but hoppers placed by other players will be unable to do so. A hopper's own inventory is not not owner-locked, though, so you can use this as a way to allow other players to deposit items into your locked chests.")

local containers = {}
local neighbors = {}

-- global function to add new containers
function hopper:add_container(list)
	for _, entry in pairs(list) do
		local node_info = containers[entry[2]]
		if node_info == nil then
			node_info = {}
		end
		node_info[entry[1]] = entry[3]
		containers[entry[2]] = node_info
		
		-- result is a table of the form containers[target_node_name][relative_position][inventory_name]
		
		local already_in_neighbors = false
		for _, value in pairs(neighbors) do
			if value == entry[2] then
				already_in_neighbors = true
				break
			end
		end
		if not already_in_neighbors then
			table.insert(neighbors, entry[2])
		end
	end
end

-- default containers ( relative position, target node, node inventory affected )
hopper:add_container({
	{"top", "hopper:hopper", "main"},
	{"bottom", "hopper:hopper", "main"},
	{"side", "hopper:hopper", "main"},
	{"side", "hopper:hopper_side", "main"},

	{"top", "default:chest", "main"},
	{"bottom", "default:chest", "main"},
	{"side", "default:chest", "main"},

	{"top", "default:furnace", "dst"},
	{"bottom", "default:furnace", "src"},
	{"side", "default:furnace", "fuel"},

	{"top", "default:furnace_active", "dst"},
	{"bottom", "default:furnace_active", "src"},
	{"side", "default:furnace_active", "fuel"},

	{"top", "default:chest_locked", "main"},
	{"bottom", "default:chest_locked", "main"},
	{"side", "default:chest_locked", "main"},
})

-- protector redo mod support
if minetest.get_modpath("protector") then
	hopper:add_container({
		{"top", "protector:chest", "main"},
		{"bottom", "protector:chest", "main"},
		{"side", "protector:chest", "main"},
	})
end

-- wine mod support
if minetest.get_modpath("wine") then
	hopper:add_container({
		{"top", "wine:wine_barrel", "dst"},
		{"bottom", "wine:wine_barrel", "src"},
		{"side", "wine:wine_barrel", "src"},
	})
end

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

local hopper_on_place = function(itemstack, placer, pointed_thing, node_name)
	local pos  = pointed_thing.under
	local pos2 = pointed_thing.above
	local x = pos.x - pos2.x
	local z = pos.z - pos2.z

	local returned_stack, success
	-- unfortunately param2 overrides are needed for side hoppers even in the non-single-craftable-item case
	-- because they are literally *side* hoppers - their spouts point to the side rather than to the front, so
	-- the default item_place_node orientation code will not orient them pointing toward the selected surface.
	if x == -1 and (single_craftable_item or node_name == "hopper:hopper_side") then
		returned_stack, success = minetest.item_place_node(ItemStack("hopper:hopper_side"), placer, pointed_thing, 0)
	elseif x == 1 and (single_craftable_item or node_name == "hopper:hopper_side") then
		returned_stack, success = minetest.item_place_node(ItemStack("hopper:hopper_side"), placer, pointed_thing, 2)
	elseif z == -1 and (single_craftable_item or node_name == "hopper:hopper_side")  then
		returned_stack, success = minetest.item_place_node(ItemStack("hopper:hopper_side"), placer, pointed_thing, 3)
	elseif z == 1 and (single_craftable_item or node_name == "hopper:hopper_side") then
		returned_stack, success = minetest.item_place_node(ItemStack("hopper:hopper_side"), placer, pointed_thing, 1)
	else
		if single_craftable_item then
			node_name = "hopper:hopper" -- For cases where single_craftable_item was set on an existing world and there are still side hoppers in player inventories
		end
		returned_stack, success = minetest.item_place_node(ItemStack(node_name), placer, pointed_thing)
	end
	
	if success then
		local meta = minetest.get_meta(pos2)
		meta:set_string("placer", placer:get_player_name())
		if not minetest.setting_getbool("creative_mode") then
			itemstack:take_item()
		end
	end
	return itemstack
end

-- hopper
minetest.register_node("hopper:hopper", {
	drop = "hopper:hopper",
	description = S("Hopper"),
	_doc_items_longdesc = hopper_long_desc,
    _doc_items_usagehelp = hopper_usage,
	groups = {cracky = 3},
	drawtype = "nodebox",
	paramtype = "light",
	tiles = {
		"hopper_top_" .. texture_resolution .. ".png",
		"hopper_top_" .. texture_resolution .. ".png",
		"hopper_front_" .. texture_resolution .. ".png"
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
			{-0.15, -0.3, -0.15, 0.15, -0.5, 0.15},
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {
			--funnel
			{-0.5, 0.0, -0.5, 0.5, 0.5, 0.5},
			--spout
			{-0.3, -0.3, -0.3, 0.3, 0.0, 0.3},
			{-0.15, -0.3, -0.15, 0.15, -0.5, 0.15},
		},
	},

	on_construct = function(pos)
		local inv = minetest.get_meta(pos):get_inventory()
		inv:set_size("main", 4*4)
	end,

	on_place = function(itemstack, placer, pointed_thing)
		return hopper_on_place(itemstack, placer, pointed_thing, "hopper:hopper")
	end,

	can_dig = function(pos, player)
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
		minetest.log("action", S("@1 moves stuff in hopper at @2",
			player:get_player_name(), minetest.pos_to_string(pos)))
	end,

	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		minetest.log("action", S("@1 moves stuff to hopper at @2",
			player:get_player_name(), minetest.pos_to_string(pos)))
	end,

	on_metadata_inventory_take = function(pos, listname, index, stack, player)
		minetest.log("action", S("@1 moves stuff from hopper at @2",
			player:get_player_name(), minetest.pos_to_string(pos)))
	end,
})

local hopper_side_drop
local hopper_groups
if single_craftable_item then
	hopper_side_drop = "hopper:hopper"
	hopper_groups = {cracky=3, not_in_creative_inventory = 1}
else
	hopper_side_drop = "hopper:hopper_side"
	hopper_groups = {cracky=3}
end

minetest.register_node("hopper:hopper_side", {
	description = S("Side Hopper"),
	_doc_items_longdesc = hopper_long_desc,
    _doc_items_usagehelp = hopper_usage,
	drop = hopper_side_drop,
	groups = hopper_groups,
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	tiles = {
		"hopper_top_" .. texture_resolution .. ".png",
		"hopper_bottom_" .. texture_resolution .. ".png",
		"hopper_back_" .. texture_resolution .. ".png",
		"hopper_side_" .. texture_resolution .. ".png",
		"hopper_back_" .. texture_resolution .. ".png",
		"hopper_back_" .. texture_resolution .. ".png"
	},
	drop = hopper_side_drop,
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
	selection_box = {
		type = "fixed",
		fixed = {
			--funnel
			{-0.5, 0.0, -0.5, 0.5, 0.5, 0.5},
			--spout
			{-0.3, -0.3, -0.3, 0.3, 0.0, 0.3},
			{-0.7, -0.3, -0.15, 0.15, 0.0, 0.15},
		},
	},
	
	on_construct = function(pos)
		local inv = minetest.get_meta(pos):get_inventory()
		inv:set_size("main", 4*4)
	end,

	on_place = function(itemstack, placer, pointed_thing)
		return hopper_on_place(itemstack, placer, pointed_thing, "hopper:hopper_side")
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
		minetest.log("action", S("@1 moves stuff in hopper at @2",
			player:get_player_name(), minetest.pos_to_string(pos)))
	end,

	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		minetest.log("action", S("@1 moves stuff to hopper at @2",
			player:get_player_name(), minetest.pos_to_string(pos)))
	end,

	on_metadata_inventory_take = function(pos, listname, index, stack, player)
		minetest.log("action", S("@1 moves stuff from hopper at @2",
			player:get_player_name(), minetest.pos_to_string(pos)))
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

-- Used to remove items from the target block and put it into the hopper's inventory
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

-- Used to put items from the hopper inventory into the target block
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
					--add to target node
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

-- Used to convert side hopper facing into source and destination relative coordinates
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

-- hopper workings
minetest.register_abm({
	label = "Hopper suction and transfer",
	nodenames = {"hopper:hopper", "hopper:hopper_side"},
	neighbors = neighbors,
	interval = 1.0,
	chance = 1,
	catch_up = false,

	action = function(pos, node, active_object_count, active_object_count_wider)
		local source_pos, destination_pos
		if node.name == "hopper:hopper_side" then
			source_pos = vector.add(pos, directions[node.param2].src)
			destination_pos = vector.add(pos, directions[node.param2].dst)
		else
			source_pos = {x=pos.x, y=pos.y+1, z=pos.z}
			destination_pos = {x=pos.x, y=pos.y-1, z=pos.z}
		end
		
		local source_node = minetest.get_node(source_pos)
		local destination_node = minetest.get_node(destination_pos)
				
		if containers[source_node.name] ~= nil then
			take_item_from(pos, source_pos, source_node, containers[source_node.name]["top"])
		end
		
		if containers[destination_node.name] ~= nil then
			if node.name == "hopper:hopper_side" then
				send_item_to(pos, destination_pos, destination_node, containers[destination_node.name]["side"])
			else
				send_item_to(pos, destination_pos, destination_node, containers[destination_node.name]["bottom"])
			end
		end
	end,
})

minetest.register_craft({
	output = "hopper:hopper",
	recipe = {
		{"default:steel_ingot","default:chest","default:steel_ingot"},
		{"","default:steel_ingot",""},
	}
})

if not single_craftable_item then
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
	lucky_block:add_blocks({
		{"dro", {"hopper:hopper"}, 3},
		{"nod", "default:lava_source", 1},
	})
end

print (S("[MOD] Hopper loaded"))
