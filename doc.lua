hopper.doc = {}

hopper.doc.hopper_long_desc = S("Hopper to transfer items between neighboring blocks' inventories.")
hopper.doc.hopper_usage = S("Items are transfered from the block at the wide end of the hopper to the block at the narrow end of the hopper at a rate of one per second. Items can also be placed directly into the hopper's inventory, or they can be dropped into the space above a hopper and will be sucked into the hopper's inventory automatically.\n\n")
if hopper.config.single_craftable_item then
	hopper.doc.hopper_usage = hopper.doc.hopper_usage .. S("Hopper blocks come in both 'vertical' and 'side' forms, but when in a player's inventory both are represented by a single generic item. The type of hopper block that will be placed when the player uses this item depends on what is pointed at - when the hopper item is pointed at the top or bottom face of a block a vertical hopper is placed, when aimed at the side of a block a side hopper is produced that connects to the clicked-on side.\n\n")
else
	hopper.doc.hopper_usage = hopper.doc.hopper_usage .. S("Hopper blocks come in both 'vertical' and 'side' forms. They can be interconverted between the two forms via the crafting grid.\n\n")
end
hopper.doc.hopper_usage = hopper.doc.hopper_usage .. S("When used with furnaces, hoppers inject items into the furnace's \"raw material\" inventory slot when the narrow end is attached to the top or bottom and inject items into the furnace's \"fuel\" inventory slot when attached to the furnace's side.\n\nItems that cannot be placed in a target block's inventory will remain in the hopper.\n\nHoppers have the same permissions as the player that placed them. Hoppers placed by you are allowed to take items from or put items into locked chests that you own, but hoppers placed by other players will be unable to do so. A hopper's own inventory is not not owner-locked, though, so you can use this as a way to allow other players to deposit items into your locked chests.")

local hopper.doc.chute_long_desc = S("A chute to transfer items over longer distances.")
local hopper.doc.chute_usage = S("Chutes operate much like hoppers but do not have their own intake capability. Items can only be inserted into a chute manually or by a hopper connected to a chute. They transfer items in the direction indicated by the arrow on their narrow segment at a rate of one item per second. They have a small buffer capacity, and any items that can't be placed into the target block's inventory will remain lodged in the chute's buffer until manually removed or their destination becomes available.")

