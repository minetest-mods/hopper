std = "lua51c"

ignore = {
	"21[23]", -- unused argument
}

max_line_length = 250

read_globals = {
	"core",
	"ItemStack",
	"minetest",
	"vector",
	-- (Soft) sependencies
	"default",
	"lucky_block",
	"mcl_formspec",
	"mcl_sounds",
}

globals = {"hopper"}

files["doc.lua"] = {
	max_line_length = 9999,
}
