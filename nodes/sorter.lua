-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

local facedir_to_bottomdir = {
	[0]={x=0, y=-1, z=0},
	{x=0, y=0, z=-1},
	{x=0, y=0, z=1},
	{x=-1, y=0, z=0},
	{x=1, y=0, z=0},
	{x=0, y=1, z=0},
}

local bottomdir = function(facedir)
	return facedir_to_bottomdir[math.floor(facedir/4)]
end

local function get_sorter_formspec(pos)
	local spos = hopper.get_string_pos(pos)
	local formspec =
		"size[8,8.4]"
		.. hopper.formspec_bg
		.. "label[3.7,0;"..S("Filter").."]"
		.. "list[nodemeta:" .. spos .. ";filter;0,0.5;8,1;]"
		.. "list[nodemeta:" .. spos .. ";main;3,2.1;2,2;]"
		.. hopper.get_eject_button_texts(pos, 7, 3)
		.. "list[current_player;main;0,4.5;8,1;]"
		.. "list[current_player;main;0,5.7;8,3;8]"
		.. "listring[nodemeta:" .. spos .. ";main]"
		.. "listring[current_player;main]"
	return formspec
end


minetest.register_node("hopper:sorter", {
	description = S("Sorter"),
	_doc_items_longdesc = hopper.doc.sorter_long_desc,
	_doc_items_usagehelp = hopper.doc.sorter_usage,
	groups = {cracky = 1, level = 2},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	tiles = {
			"hopper_bottom_" .. hopper.config.texture_resolution .. ".png",
			"hopper_top_" .. hopper.config.texture_resolution .. ".png",
			"hopper_bottom_" .. hopper.config.texture_resolution .. ".png^hopper_sorter_arrow_" .. hopper.config.texture_resolution .. ".png^[transformFX",
			"hopper_bottom_" .. hopper.config.texture_resolution .. ".png^hopper_sorter_arrow_" .. hopper.config.texture_resolution .. ".png",
			"hopper_top_" .. hopper.config.texture_resolution .. ".png",
			"hopper_bottom_" .. hopper.config.texture_resolution .. ".png^hopper_sorter_arrow_" .. hopper.config.texture_resolution .. ".png",
		},
	node_box = {
		type = "fixed",
		fixed = {
			{-0.3, -0.3, -0.4, 0.3, 0.4, 0.4},
			{-0.2, -0.2, 0.4, 0.2, 0.2, 0.7},
			{-0.2, -0.3, -0.2, 0.2, -0.7, 0.2},
		},
	},
	
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("main", 2*2)
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
		return inv:is_empty("main")
	end,
	
	on_rightclick = function(pos, node, clicker, itemstack)
		if minetest.is_protected(pos, clicker:get_player_name()) and not minetest.check_player_privs(clicker, "protection_bypass") then
			return
		end
		minetest.show_formspec(clicker:get_player_name(),
			"hopper_formspec:"..minetest.pos_to_string(pos), get_sorter_formspec(pos))
	end,
	
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname == "filter" then
			local inv = minetest.get_inventory({type="node", pos=pos})
			inv:set_stack(listname, index, stack:take_item(1))
			return 0
		end
		return stack:get_count()
	end,
	
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		if listname == "filter" then
			local inv = minetest.get_inventory({type="node", pos=pos})
			inv:set_stack(listname, index, ItemStack(""))
			return 0
		end
		return stack:get_count()
	end,
	
	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		minetest.log("action", S("@1 moves stuff to sorter at @2",
			player:get_player_name(), minetest.pos_to_string(pos)))

		local timer = minetest.get_node_timer(pos)
		if not timer:is_started() then
			timer:start(1)
		end		
	end,
	
	on_timer = function(pos, elapsed)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()

		-- build a filter list
		local filter_items = {}
		local filter_inv_size = inv:get_size("filter")
		for i = 1, filter_inv_size do
			local stack = inv:get_stack("filter", i)
			local item = stack:get_name()
			if item ~= "" then
				filter_items[item] = true
			end
		end
		
		local node = minetest.get_node(pos)
		local dir = minetest.facedir_to_dir(node.param2)
		local default_destination_pos = vector.add(pos, dir)
		local default_output_direction
		if dir.y == 0 then
			default_output_direction = "horizontal"
		end

		dir = bottomdir(node.param2)
		local filter_destination_pos = vector.add(pos, dir)
		local filter_output_direction
		if dir.y == 0 then
			filter_output_direction = "horizontal"
		end

		local success = false
		
		local filter_destination_node = minetest.get_node(filter_destination_pos)
		local registered_inventories = hopper.get_registered_inventories_for(filter_destination_node.name)
		if registered_inventories ~= nil then
			if filter_output_direction == "horizontal" then
				success = hopper.send_item_to(pos, filter_destination_pos, filter_destination_node, registered_inventories["side"], filter_items)
			else
				success = hopper.send_item_to(pos, filter_destination_pos, filter_destination_node, registered_inventories["bottom"], filter_items)
			end
		else
			success = hopper.send_item_to(pos, filter_destination_pos, filter_destination_node, nil, filter_items)
		end
		
		if not success then -- weren't able to put something in the filter destination, for whatever reason. Now we can start moving stuff forward to the default.
			local default_destination_node = minetest.get_node(default_destination_pos)
			local registered_inventories = hopper.get_registered_inventories_for(default_destination_node.name)
			if registered_inventories ~= nil then
				if default_output_direction == "horizontal" then
					hopper.send_item_to(pos, default_destination_pos, default_destination_node, registered_inventories["side"])
				else
					hopper.send_item_to(pos, default_destination_pos, default_destination_node, registered_inventories["bottom"])
				end
			else
				hopper.send_item_to(pos, default_destination_pos, default_destination_node)
			end
		end
		
		if not inv:is_empty("main") then
			minetest.get_node_timer(pos):start(1)
		end
	end,
})