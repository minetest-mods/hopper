
-- Default values
hopper.formspec_bg = "bgcolor[#080808BB;true]" .. "listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]"
hopper.metal_sounds = nil
hopper.node_fire_flame = nil

local formspec_list_template = "list[%s;%s;%f,%f;%f,%f;%s]"
hopper.formspec_add_list = function(location, listname, x, y, w, h, offset)
	return formspec_list_template:format(location, listname, x, y, w, h, tostring(offset) or "")
end

-- Minetest Game
if core.get_modpath("default") then
	hopper.formspec_bg = "" -- Use formspec prepend
	hopper.metal_sounds = default.node_sound_metal_defaults()

	if core.get_modpath("fire") then
		hopper.node_fire_flame = "fire:basic_flame"
	end
end

-- VoxeLibre, Mineclonia
if core.get_modpath("mcl_init") then
	hopper.formspec_bg = "" -- Use formspec prepend

	if core.get_modpath("mcl_sounds") then
		hopper.metal_sounds = mcl_sounds.node_sound_metal_defaults()
	end
	if core.get_modpath("mcl_fire") then
		hopper.node_fire_flame = "mcl_fire:fire"
	end
	if core.get_modpath("mcl_formspec") then
		hopper.formspec_add_list = function(location, listname, x, y, w, h, offset)
			return mcl_formspec.get_itemslot_bg_v4(x, y, w, h) ..
				formspec_list_template:format(location, listname, x, y, w, h, tostring(offset) or "")
		end
	end
end
