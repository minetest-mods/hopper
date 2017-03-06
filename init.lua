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

local eject_button_enabled = minetest.setting_getbool("hopper_eject_button")
if eject_button_enabled == nil then
	eject_button_enabled = true
end

-------------------------------------------------------------------------------------------
-- API

local containers = {}
local groups = {}
local neighbors = {}

-- global function to add new containers
function hopper:add_container(list)
	for _, entry in pairs(list) do
	
		local target_node = entry[2]
		local neighbor_node
		
		if string.sub(target_node, 1, 6) == "group:" then
			local group_identifier, group_number
			local equals_index = string.find(target_node, "=")
			if equals_index ~= nil then
				group_identifier = string.sub(target_node, 7, equals_index-1)
				-- it's possible that the string was of the form "group:blah = 1", in which case we want to trim spaces off the end of the group identifier
				local space_index = string.find(group_identifier, " ") 
				if space_index ~= nil then
					group_identifier = string.sub(group_identifier, 1, space_index-1)
				end
				group_number = tonumber(string.sub(target_node, equals_index+1, -1))
			else
				group_identifier = string.sub(target_node, 7, -1)
				group_number = "all" -- special value to indicate no number was provided
			end
			
			local group_info = groups[group_identifier]
			if group_info == nil then
				group_info = {}
			end
			if group_info[group_number] == nil then
				group_info[group_number] = {}
			end
			group_info[group_number][entry[1]] = entry[3]
			groups[group_identifier] = group_info
			neighbor_node = "group:"..group_identifier
			-- result is a table of the form groups[group_identifier][group_number][relative_position][inventory_name]
		else
			local node_info = containers[target_node]
			if node_info == nil then
				node_info = {}
			end
			node_info[entry[1]] = entry[3]
			containers[target_node] = node_info
			neighbor_node = target_node
			-- result is a table of the form containers[target_node_name][relative_position][inventory_name]
		end
		
		local already_in_neighbors = false
		for _, value in pairs(neighbors) do
			if value == neighbor_node then
				already_in_neighbors = true
				break
			end
		end
		if not already_in_neighbors then
			table.insert(neighbors, neighbor_node)
		end
	end
end

-- "top" indicates what inventory the hopper will take items from if this node is located at the hopper's wide end
-- "side" indicates what inventory the hopper will put items into if this node is located at the hopper's narrow end and at the same height as the hopper
-- "bottom" indicates what inventory the hopper will put items into if this node is located at the hopper's narrow end and either above or below the hopper.

hopper:add_container({
	{"top", "hopper:hopper", "main"},
	{"bottom", "hopper:hopper", "main"},
	{"side", "hopper:hopper", "main"},
	{"side", "hopper:hopper_side", "main"},
	
	{"bottom", "hopper:chute", "main"},
	{"side", "hopper:chute", "main"},
})

if minetest.get_modpath("default") then
	hopper:add_container({
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
end

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

-------------------------------------------------------------------------------------------
-- Documentation

local hopper_long_desc = S("Hopper to transfer items between neighboring blocks' inventories.")
local hopper_usage = S("Items are transfered from the block at the wide end of the hopper to the block at the narrow end of the hopper at a rate of one per second. Items can also be placed directly into the hopper's inventory, or they can be dropped into the space above a hopper and will be sucked into the hopper's inventory automatically.\n\n")
if single_craftable_item then
	hopper_usage = hopper_usage .. S("Hopper blocks come in both 'vertical' and 'side' forms, but when in a player's inventory both are represented by a single generic item. The type of hopper block that will be placed when the player uses this item depends on what is pointed at - when the hopper item is pointed at the top or bottom face of a block a vertical hopper is placed, when aimed at the side of a block a side hopper is produced that connects to the clicked-on side.\n\n")
else
	hopper_usage = hopper_usage .. S("Hopper blocks come in both 'vertical' and 'side' forms. They can be interconverted between the two forms via the crafting grid.\n\n")
end
hopper_usage = hopper_usage .. S("When used with furnaces, hoppers inject items into the furnace's \"raw material\" inventory slot when the narrow end is attached to the top or bottom and inject items into the furnace's \"fuel\" inventory slot when attached to the furnace's side.\n\nItems that cannot be placed in a target block's inventory will remain in the hopper.\n\nHoppers have the same permissions as the player that placed them. Hoppers placed by you are allowed to take items from or put items into locked chests that you own, but hoppers placed by other players will be unable to do so. A hopper's own inventory is not not owner-locked, though, so you can use this as a way to allow other players to deposit items into your locked chests.")

local chute_long_desc = S("A chute to transfer items over longer distances.")
local chute_usage = S("Chutes operate much like hoppers but do not have their own intake capability. Items can only be inserted into a chute manually or by a hopper connected to a chute. They transfer items in the direction indicated by the arrow on their narrow segment at a rate of one item per second. They have a small buffer capacity, and any items that can't be placed into the target block's inventory will remain lodged in the chute's buffer until manually removed or their destination becomes available.")

-------------------------------------------------------------------------------------------
-- Target inventory retrieval

-- looks first for a registration matching the specific node name, then for a registration
-- matching group and value, then for a registration matching a group and *any* value
local get_registered_inventories_for = function(target_node_name)
	local output = containers[target_node_name]
	if output ~= nil then return output end
	
	local target_def = minetest.registered_nodes[target_node_name]
	if target_def.groups == nil then return nil end
	
	for group, value in pairs(target_def.groups) do
		local registered_group = groups[group]
		if registered_group ~= nil then
			output = registered_group[value]
			if output ~= nil then return output end
			output = registered_group["all"]
			if output ~= nil then return output end			
		end	
	end
	
	return nil
end

-------------------------------------------------------------------------------------------
-- Inventory transfer functions

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
	local hopper_meta = minetest.get_meta(hopper_pos)
	local target_def = minetest.registered_nodes[target_node.name]
	local eject_item = eject_button_enabled and hopper_meta:get_string("eject") == "true" and target_def.buildable_to
	
	if not eject_item and not target_inventory_name then
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

	for i = 1,hopper_inv_size do
		local stack = hopper_inv:get_stack("main", i)
		local item = stack:get_name()
		if item ~= "" then
			if target_inventory_name then
				if target_inv:room_for_item(target_inventory_name, item) then
					local stack_to_put = stack:take_item(1)
					if target_def.allow_metadata_inventory_put == nil
					or placer == nil -- backwards compatibility, older versions of this mod didn't record who placed the hopper
					or target_def.allow_metadata_inventory_put(target_pos, target_inventory_name, i, stack_to_put, placer) > 0 then
						hopper_inv:set_stack("main", i, stack)
						--add to target node
						target_inv:add_item(target_inventory_name, stack_to_put)
						if target_def.on_metadata_inventory_put ~= nil and placer ~= nil then
							target_def.on_metadata_inventory_put(target_pos, target_inventory_name, i, stack_to_put, placer)
						end
						break
					end
				end
			elseif eject_item then
				local stack_to_put = stack:take_item(1)
				minetest.add_item(target_pos, stack_to_put)
				hopper_inv:set_stack("main", i, stack)
			end
		end
	end
end

-------------------------------------------------------------------------------------------
-- Nodes

local function get_eject_button_texts(pos, loc_X, loc_Y)
	if not eject_button_enabled then return "" end

	local eject_button_text, eject_button_tooltip
	if minetest.get_meta(pos):get_string("eject") == "true" then
		eject_button_text = S("Don't\nEject")
		eject_button_tooltip = S("This hopper is currently set to eject items from its output\neven if there isn't a compatible block positioned to receive it.\nClick this button to disable this feature.")
	else
		eject_button_text = S("Eject\nItems")
		eject_button_tooltip = S("This hopper is currently set to hold on to item if there\nisn't a compatible block positioned to receive it.\nClick this button to have it eject items instead.")
	end
	return string.format("button_exit[%i,%i;1,1;eject;%s]tooltip[eject;%s]", loc_X, loc_Y, eject_button_text, eject_button_tooltip)
end

local function get_string_pos(pos)
	return pos.x .. "," .. pos.y .. "," ..pos.z
end

local formspec_bg
if minetest.get_modpath("default") then
	formspec_bg = default.gui_bg .. default.gui_bg_img .. default.gui_slots
else
	formspec_bg = "bgcolor[#080808BB;true]" .. "listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]"
end

-- formspec
local function get_hopper_formspec(pos)
	local spos = get_string_pos(pos)
	local formspec =
		"size[8,9]"
		.. formspec_bg
		.. "list[nodemeta:" .. spos .. ";main;2,0.3;4,4;]"
		.. get_eject_button_texts(pos, 7, 2)
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

-------------------------------------------------------------------------------------------
-- Hoppers

minetest.register_node("hopper:hopper", {
	drop = "hopper:hopper",
	description = S("Hopper"),
	_doc_items_longdesc = hopper_long_desc,
    _doc_items_usagehelp = hopper_usage,
	groups = {cracky = 3},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
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
			{-0.15, -0.3, -0.15, 0.15, -0.7, 0.15},
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {
			--funnel
			{-0.5, 0.0, -0.5, 0.5, 0.5, 0.5},
			--spout
			{-0.3, -0.3, -0.3, 0.3, 0.0, 0.3},
			{-0.15, -0.3, -0.15, 0.15, -0.7, 0.15},
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
		if minetest.is_protected(pos, clicker:get_player_name()) and not minetest.check_player_privs(clicker, "protection_bypass") then
			return
		end
		minetest.show_formspec(clicker:get_player_name(),
			"hopper_formspec:"..minetest.pos_to_string(pos), get_hopper_formspec(pos))
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
		if minetest.is_protected(pos, clicker:get_player_name()) and not minetest.check_player_privs(clicker, "protection_bypass") then
			return
		end
		minetest.show_formspec(clicker:get_player_name(),
			"hopper_formspec:"..minetest.pos_to_string(pos), get_hopper_formspec(pos))
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

local function get_chute_formspec(pos)
	local spos = pos.x .. "," .. pos.y .. "," ..pos.z
	local formspec =
		"size[8,7]"
		.. formspec_bg
		.. "list[nodemeta:" .. spos .. ";main;3,0.3;2,2;]"
		.. get_eject_button_texts(pos, 7, 1)
		.. "list[current_player;main;0,2.85;8,1;]"
		.. "list[current_player;main;0,4.08;8,3;8]"
		.. "listring[nodemeta:" .. spos .. ";main]"
		.. "listring[current_player;main]"
	return formspec
end

-------------------------------------------------------------------------------------------
-- Chute

minetest.register_node("hopper:chute", {
	description = S("Hopper Chute"),
	_doc_items_longdesc = chute_long_desc,
    _doc_items_usagehelp = chute_usage,
	drop = "hopper:chute",
	groups = {cracky = 3},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	tiles = {
		"hopper_bottom_" .. texture_resolution .. ".png^hopper_chute_arrow_" .. texture_resolution .. ".png",
		"hopper_bottom_" .. texture_resolution .. ".png^(hopper_chute_arrow_" .. texture_resolution .. ".png^[transformR180)",
		"hopper_bottom_" .. texture_resolution .. ".png^(hopper_chute_arrow_" .. texture_resolution .. ".png^[transformR270)",
		"hopper_bottom_" .. texture_resolution .. ".png^(hopper_chute_arrow_" .. texture_resolution .. ".png^[transformR90)",
		"hopper_top_" .. texture_resolution .. ".png",
		"hopper_bottom_" .. texture_resolution .. ".png"
	},
	node_box = {
		type = "fixed",
		fixed = {
			{-0.3, -0.3, -0.3, 0.3, 0.3, 0.3},
			{-0.2, -0.2, 0.3, 0.2, 0.2, 0.7},
		},
	},
	
	on_construct = function(pos)
		local inv = minetest.get_meta(pos):get_inventory()
		inv:set_size("main", 2*2)
	end,

	on_place = function(itemstack, placer, pointed_thing, node_name)
		local pos  = pointed_thing.under
		local pos2 = pointed_thing.above
		local x = pos.x - pos2.x
		local z = pos.z - pos2.z

		local returned_stack, success = minetest.item_place_node(itemstack, placer, pointed_thing)
		if success then
			local meta = minetest.get_meta(pos2)
			meta:set_string("placer", placer:get_player_name())
		end
		return returned_stack
	end,
	
	can_dig = function(pos,player)
		local inv = minetest.get_meta(pos):get_inventory()
		return inv:is_empty("main")
	end,

	on_rightclick = function(pos, node, clicker, itemstack)
		if minetest.is_protected(pos, clicker:get_player_name()) and not minetest.check_player_privs(clicker, "protection_bypass") then
			return
		end
		minetest.show_formspec(clicker:get_player_name(),
			"hopper_formspec:"..minetest.pos_to_string(pos), get_chute_formspec(pos))
	end,

	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		minetest.log("action", S("@1 moves stuff to chute at @2",
			player:get_player_name(), minetest.pos_to_string(pos)))

		local timer = minetest.get_node_timer(pos)
		if not timer:is_started() then
			timer:start(1)
		end		
	end,

	on_timer = function(pos, elapsed)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		local eject_item = meta:get_string("eject") == "true"

		local node = minetest.get_node(pos)
		local dir = minetest.facedir_to_dir(node.param2)
		local destination_pos = vector.add(pos, dir)
		local output_direction
		if dir.y == 0 then
			output_direction = "horizontal"
		end
		
		local destination_node = minetest.get_node(destination_pos)
		local registered_inventories = get_registered_inventories_for(destination_node.name)
		if registered_inventories ~= nil then
			if output_direction == "horizontal" then
				send_item_to(pos, destination_pos, destination_node, registered_inventories["side"])
			else
				send_item_to(pos, destination_pos, destination_node, registered_inventories["bottom"])
			end
		else
			send_item_to(pos, destination_pos, destination_node)
		end
		
		if not inv:is_empty("main") then
			minetest.get_node_timer(pos):start(1)
		end
	end,
})

-------------------------------------------------------------------------------------------
-- Formspec handling

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if "hopper_formspec:" == string.sub(formname, 1, 16) then
		local pos = minetest.string_to_pos(string.sub(formname, 17, -1))
		local meta = minetest.get_meta(pos)
		local eject_setting = meta:get_string("eject") == "true"
		if fields.eject then
			if eject_setting then
				meta:set_string("eject", nil)
			else
				meta:set_string("eject", "true")
			end
		end
	end
end)


-------------------------------------------------------------------------------------------
-- ABMs

-- suck in items on top of hopper
minetest.register_abm({
	label = "Hopper suction",
	nodenames = {"hopper:hopper", "hopper:hopper_side"},
	interval = 1.0,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		if active_object_count_wider == 0 then
			return
		end
		
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

local bottomdir = function(facedir)
	return ({[0]={x=0, y=-1, z=0},
		{x=0, y=0, z=-1},
		{x=0, y=0, z=1},
		{x=-1, y=0, z=0},
		{x=1, y=0, z=0},
		{x=0, y=1, z=0}})[math.floor(facedir/4)]
end

-- hopper workings
minetest.register_abm({
	label = "Hopper transfer",
	nodenames = {"hopper:hopper", "hopper:hopper_side"},
	neighbors = neighbors,
	interval = 1.0,
	chance = 1,
	catch_up = false,

	action = function(pos, node, active_object_count, active_object_count_wider)
		local source_pos, destination_pos, destination_dir
		if node.name == "hopper:hopper_side" then
			source_pos = vector.add(pos, directions[node.param2].src)
			destination_dir = directions[node.param2].dst
			destination_pos = vector.add(pos, destination_dir)
		else
			destination_dir = bottomdir(node.param2)
			source_pos = vector.subtract(pos, destination_dir)
			destination_pos = vector.add(pos, destination_dir)
		end
		
		local output_direction
		if destination_dir.y == 0 then
			output_direction = "horizontal"
		end
		
		local source_node = minetest.get_node(source_pos)
		local destination_node = minetest.get_node(destination_pos)

		local registered_source_inventories = get_registered_inventories_for(source_node.name)
		if registered_source_inventories ~= nil then
			take_item_from(pos, source_pos, source_node, registered_source_inventories["top"])
		end
		
		local registered_destination_inventories = get_registered_inventories_for(destination_node.name)
		if registered_destination_inventories ~= nil then
			if output_direction == "horizontal" then
				send_item_to(pos, destination_pos, destination_node, registered_destination_inventories["side"])
			else
				send_item_to(pos, destination_pos, destination_node, registered_destination_inventories["bottom"])
			end
		else
			send_item_to(pos, destination_pos, destination_node) -- for handling ejection
		end
	end,
})

-------------------------------------------------------------------------------------------
-- Crafts

if minetest.get_modpath("default") then
	minetest.register_craft({
		output = "hopper:hopper",
		recipe = {
			{"default:steel_ingot","default:chest","default:steel_ingot"},
			{"","default:steel_ingot",""},
		}
	})
	
	minetest.register_craft({
		output = "hopper:chute",
		recipe = {
			{"default:steel_ingot","default:chest","default:steel_ingot"},
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
end

-- add lucky blocks
if minetest.get_modpath("lucky_block") then
	lucky_block:add_blocks({
		{"dro", {"hopper:hopper"}, 3},
		{"nod", "default:lava_source", 1},
	})
end

print (S("[MOD] Hopper loaded"))
