hopper.config = {}

-- settings
hopper.config.texture_resolution = minetest.setting_get("hopper_texture_size")
if hopper.config.texture_resolution == nil then
	hopper.config.texture_resolution = "16"
end

hopper.config.single_craftable_item = minetest.setting_getbool("hopper_single_craftable_item")
if hopper.config.single_craftable_item == nil then
	hopper.config.single_craftable_item = true
end

hopper.config.eject_button_enabled = minetest.setting_getbool("hopper_eject_button")
if hopper.config.eject_button_enabled == nil then
	hopper.config.eject_button_enabled = true
end
