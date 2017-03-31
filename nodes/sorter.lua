-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

-------------------------------------------------------------------------------------------
-- Sorter by Burli

local sorter_output_pos = {}
sorter_output_pos[0] = {x = 1, y = 0, z = 0}
sorter_output_pos[1] = {x = 0, y = 0, z = -1}
sorter_output_pos[2] = {x = -1, y = 0, z = 0}
sorter_output_pos[3] = {x = 0, y = 0, z = 1}

local function get_sorter_formspec(pos)
	local spos = hopper.get_string_pos(pos)
	local formspec =
		"size[8,7.4]" ..
		hopper.formspec_bg ..
--		.. hopper.get_eject_button_texts(pos, 7, 1)
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