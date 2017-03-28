-- define global
hopper = {}

-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

dofile(MP.."/config.lua")
dofile(MP.."/api.lua")
dofile(MP.."/utility.lua")
dofile(MP.."/doc.lua")

-------------------------------------------------------------------------------------------
-- Nodes

local function get_eject_button_texts(pos, loc_X, loc_Y)
	if not hopper.config.eject_button_enabled then return "" end

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
	if x == -1 and (hopper.config.single_craftable_item or node_name == "hopper:hopper_side") then
		returned_stack, success = minetest.item_place_node(ItemStack("hopper:hopper_side"), placer, pointed_thing, 0)
	elseif x == 1 and (hopper.config.single_craftable_item or node_name == "hopper:hopper_side") then
		returned_stack, success = minetest.item_place_node(ItemStack("hopper:hopper_side"), placer, pointed_thing, 2)
	elseif z == -1 and (hopper.config.single_craftable_item or node_name == "hopper:hopper_side")  then
		returned_stack, success = minetest.item_place_node(ItemStack("hopper:hopper_side"), placer, pointed_thing, 3)
	elseif z == 1 and (hopper.config.single_craftable_item or node_name == "hopper:hopper_side") then
		returned_stack, success = minetest.item_place_node(ItemStack("hopper:hopper_side"), placer, pointed_thing, 1)
	else
		if hopper.config.single_craftable_item then
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
	_doc_items_longdesc = hopper.doc.hopper_long_desc,
    _doc_items_usagehelp = hopper.doc.hopper_usage,
	groups = {cracky = 3},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	tiles = {
		"hopper_top_" .. hopper.config.texture_resolution .. ".png",
		"hopper_top_" .. hopper.config.texture_resolution .. ".png",
		"hopper_front_" .. hopper.config.texture_resolution .. ".png"
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
if hopper.config.single_craftable_item then
	hopper_side_drop = "hopper:hopper"
	hopper_groups = {cracky=3, not_in_creative_inventory = 1}
else
	hopper_side_drop = "hopper:hopper_side"
	hopper_groups = {cracky=3}
end

minetest.register_node("hopper:hopper_side", {
	description = S("Side Hopper"),
	_doc_items_longdesc = hopper.doc.hopper_long_desc,
    _doc_items_usagehelp = hopper.doc.hopper_usage,
	drop = hopper_side_drop,
	groups = hopper_groups,
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	tiles = {
		"hopper_top_" .. hopper.config.texture_resolution .. ".png",
		"hopper_bottom_" .. hopper.config.texture_resolution .. ".png",
		"hopper_back_" .. hopper.config.texture_resolution .. ".png",
		"hopper_side_" .. hopper.config.texture_resolution .. ".png",
		"hopper_back_" .. hopper.config.texture_resolution .. ".png",
		"hopper_back_" .. hopper.config.texture_resolution .. ".png"
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

-------------------------------------------------------------------------------------------
-- Chute

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

minetest.register_node("hopper:chute", {
	description = S("Hopper Chute"),
	_doc_items_longdesc = hopper.doc.chute_long_desc,
    _doc_items_usagehelp = hopper.doc.chute_usage,
	drop = "hopper:chute",
	groups = {cracky = 3},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	tiles = {
		"hopper_bottom_" .. hopper.config.texture_resolution .. ".png^hopper_chute_arrow_" .. hopper.config.texture_resolution .. ".png",
		"hopper_bottom_" .. hopper.config.texture_resolution .. ".png^(hopper_chute_arrow_" .. hopper.config.texture_resolution .. ".png^[transformR180)",
		"hopper_bottom_" .. hopper.config.texture_resolution .. ".png^(hopper_chute_arrow_" .. hopper.config.texture_resolution .. ".png^[transformR270)",
		"hopper_bottom_" .. hopper.config.texture_resolution .. ".png^(hopper_chute_arrow_" .. hopper.config.texture_resolution .. ".png^[transformR90)",
		"hopper_top_" .. hopper.config.texture_resolution .. ".png",
		"hopper_bottom_" .. hopper.config.texture_resolution .. ".png"
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
		local registered_inventories = hopper.get_registered_inventories_for(destination_node.name)
		if registered_inventories ~= nil then
			if output_direction == "horizontal" then
				hopper.send_item_to(pos, destination_pos, destination_node, registered_inventories["side"])
			else
				hopper.send_item_to(pos, destination_pos, destination_node, registered_inventories["bottom"])
			end
		else
			hopper.send_item_to(pos, destination_pos, destination_node)
		end
		
		if not inv:is_empty("main") then
			minetest.get_node_timer(pos):start(1)
		end
	end,
})

-------------------------------------------------------------------------------------------
-- Sorter by Burli

local sorter_output_pos = {}
sorter_output_pos[0] = {x = 1, y = 0, z = 0}
sorter_output_pos[1] = {x = 0, y = 0, z = -1}
sorter_output_pos[2] = {x = -1, y = 0, z = 0}
sorter_output_pos[3] = {x = 0, y = 0, z = 1}

local function get_sorter_formspec(pos)
	local spos = pos.x .. "," .. pos.y .. "," ..pos.z
	local formspec =
		"size[8,7.4]" ..
		formspec_bg ..
--		.. get_eject_button_texts(pos, 7, 1)
		"label[3.6,0;"..S("Filter").."]"..
		"list[nodemeta:" .. spos .. ";filter;0,0.5;8,1;]"..
		"label[1.6,1.5;"..S("Input").."]"..
		"list[nodemeta:" .. spos .. ";main;4.5,2.1;3,1;]"..
		"label[5.5,1.5;"..S("Output").."]"..
		"list[nodemeta:" .. spos .. ";out;0.5,2.1;3,1;]"..
		"list[current_player;main;0,3.5;8,1;]"..
		"list[current_player;main;0,4.7;8,3;8]"..
		"listring[nodemeta:" .. spos .. ";main]" ..
		"listring[current_player;main]" ..
		"listring[nodemeta:" .. spos .. ";out]" ..
		"listring[current_player;main]"
--		default.get_hotbar_bg(0,4.85)
	return formspec
end


minetest.register_node("hopper:sorter", {
	description = S("Sorter"),
	groups = {cracky = 1, level = 2},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	tiles = {"hopper_top_" .. hopper.config.texture_resolution .. ".png",
			"hopper_back_" .. hopper.config.texture_resolution .. ".png",
			"hopper_back_" .. hopper.config.texture_resolution .. ".png",
			"hopper_back_" .. hopper.config.texture_resolution .. ".png",
			"hopper_back_" .. hopper.config.texture_resolution .. ".png^sorter_direction_" .. hopper.config.texture_resolution .. ".png^[transformFX",
			"hopper_back_" .. hopper.config.texture_resolution .. ".png^sorter_direction_" .. hopper.config.texture_resolution .. ".png"},
	selection_box = {type="regular"},
	node_box = {
			type = "fixed",
			fixed = {
			{-0.3, 0.0, -0.4, 0.3, 0.5, 0.4},
			{-0.3, -0.3, -0.3, 0.3, 0.0, 0.3},
			{-0.15, -0.3, -0.15, 0.15, -0.5, 0.15},
			{0.5, -0.3, 0.15, -0.15, 0.0, -0.15},
			{-0.5, -0.3, -0.15, 0.15, 0.0, 0.15},
		},
	},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("out", 3)
		inv:set_size("main", 3)
		inv:set_size("filter", 8)
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
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		return inv:is_empty("main") and inv:is_empty("out") and inv:is_empty("filter")
	end,
	
	on_rightclick = function(pos, node, clicker, itemstack)
		if minetest.is_protected(pos, clicker:get_player_name()) and not minetest.check_player_privs(clicker, "protection_bypass") then
			return
		end
		minetest.show_formspec(clicker:get_player_name(),
			"hopper_formspec:"..minetest.pos_to_string(pos), get_sorter_formspec(pos))
	end,
	
	
	on_timer = function(pos, elapsed)
		local param2 = minetest.get_node(pos).param2
		local ninvname = ""
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		local invsize = inv:get_size("main")
		local npos = vector.add(pos, sorter_output_pos[param2])

		if minetest.get_node(npos).name == "hopper:sorter" then
			ninvname = "out"
		elseif minetest.get_node(npos).name == "hopper:hopper_side" then
			ninvname = "main"
		elseif minetest.get_node(
				{x = pos.x, y = pos.y + 1, z = pos.z}).name == "hopper:hopper" then
			npos = {x = pos.x, y = pos.y + 1, z = pos.z}
			ninvname = "main"
		else
			return true
		end

		local meta2 = minetest.get_meta(npos);
		local inv2 = meta2:get_inventory()
		local invsize2 = inv2:get_size(ninvname)
		if inv2:is_empty(ninvname) == false then
			for i = 1,invsize2 do
				local stack = inv2:get_stack(ninvname, i)
				local item = stack:get_name()
				if item ~= "" then
					if inv:contains_item("filter", item) or inv:is_empty("filter") then
						if inv:room_for_item("main", item) == false then
							if inv:room_for_item("out", item) == false then
								return true
							end
							stack:take_item(1)
							inv2:set_stack(ninvname, i, stack)
							inv:add_item("out", item)
							return true
						end
						stack:take_item(1)
						inv2:set_stack(ninvname, i, stack)
						inv:add_item("main", item)
					else
						if inv:room_for_item("out", item) == false then
							return true
						end
						stack:take_item(1)
						inv2:set_stack(ninvname, i, stack)
						inv:add_item("out", item)
					end
					break
				end
			end
		end
		return true
	end,
})

minetest.register_craft({
	output = "hopper:sorter",
	recipe = {
		{"default:steel_ingot","default:mese_crystal","default:steel_ingot"},
		{"default:steel_ingot","default:chest","default:steel_ingot"},
		{"default:steel_ingot","","default:steel_ingot"},
	}
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
	neighbors = hopper.neighbors,
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

		local registered_source_inventories = hopper.get_registered_inventories_for(source_node.name)
		if registered_source_inventories ~= nil then
			hopper.take_item_from(pos, source_pos, source_node, registered_source_inventories["top"])
		end
		
		local registered_destination_inventories = hopper.get_registered_inventories_for(destination_node.name)
		if registered_destination_inventories ~= nil then
			if output_direction == "horizontal" then
				hopper.send_item_to(pos, destination_pos, destination_node, registered_destination_inventories["side"])
			else
				hopper.send_item_to(pos, destination_pos, destination_node, registered_destination_inventories["bottom"])
			end
		else
			hopper.send_item_to(pos, destination_pos, destination_node) -- for handling ejection
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
	
	if not hopper.config.single_craftable_item then
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