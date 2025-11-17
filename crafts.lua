local item_steel_ingot
local item_chest
local item_mese_crystal


if core.get_modpath("default") then
	item_steel_ingot  = "default:steel_ingot"
	item_chest        = "default:chest"
	item_mese_crystal = "default:mese_crystal"
end

-- VoxeLibre, Mineclonia
if core.get_modpath("mcl_core") then
	item_steel_ingot = "mcl_core:iron_ingot"
	item_chest = "mcl_chests:chest"
	item_mese_crystal = "mcl_ocean:prismarine_crystals"
end

if not item_mese_crystal then
	core.log("warning", "[hopper] Unsupported game! There will be no craftable nodes.")
	return
end

if minetest.get_modpath("default") then
	minetest.register_craft({
		output = "hopper:hopper",
		recipe = {
			{item_steel_ingot, item_chest, item_steel_ingot},
			{"", item_steel_ingot, ""},
		}
	})

	minetest.register_craft({
		output = "hopper:chute",
		recipe = {
			{item_steel_ingot, item_chest, item_steel_ingot},
		}
	})

	minetest.register_craft({
		output = "hopper:sorter",
		recipe = {
			{"", item_mese_crystal, ""},
			{item_steel_ingot, item_chest, item_steel_ingot},
			{"", item_steel_ingot ,""},
		}
	})

end

if not hopper.config.single_craftable_item then
	minetest.register_craft({
		output = "hopper:hopper_side",
		recipe = {
			{item_steel_ingot, item_chest, item_steel_ingot},
			{"", "", item_steel_ingot},
		}
	})

	minetest.register_craft({
		output = "hopper:hopper_side",
		type = "shapeless",
		recipe = {"hopper:hopper"},
	})

	minetest.register_craft({
		output = "hopper:hopper",
		type = "shapeless",
		recipe = {"hopper:hopper_side"},
	})
end
