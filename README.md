## Hoppers, chutes and sorters

![Hoppers, chutes and sorters](screenshot.png "Hoppers, chutes and sorters")

Based on jordan4ibanez's original hoppers mod, optimized by TenPlus1 and FaceDeer, with chutes and sorters by FaceDeer

### Functionality description

#### Hopper node

Hoppers are nodes that can transfer items to and from the inventories of adjacent nodes. The transfer direction depends on the orientation of the hopper.

The wide end of a hopper is its "input" end, if there is a compatible container (e.g. a chest), one item per second is taken into its own internal inventory. The hopper will also draw in dropped items.

The narrow end of the hopper is its "output" end. It can be either straight or 90° bent, relative to the input. It will attempt to inject items into a compatible container connected to it. On failure, the item is either held back in the hopper inventory or ejected, depending on its configuration.

#### Chute node

The "chute" node acts as a pipe for items injected by a hopper or sorter. Use a screwdriver tool to achieve the desired rotation.

#### Sorter node

Item stacks placed into the "filter" grid of the sorter node inventory define how to distribute the incoming items into the two outputs.

 * Matching items are sent into the direction of the large arrow (`V`).
 * Other items are sent to the 90° side output.

Special case: The "filter all" option will cause the sorter to attempt to send *all* items in the direction of the large arrow. On failure, they're sent in the direction of the smaller arrow. Use-cases:

 * Protection against overflowing containers
 * Protection against unaccepted items in the destination slot(s), such as the furnace fuel slot

#### Built-in mod compatibility

The following nodes are supported out-of-the-box. "above"/"below"/"side" describe the location of the hopper.

 * `default:furnace`
     * Above: routed to the input slot
     * Below: routed to the output slots
     * Sides: routed to the fuel slot
 * `default:chest(_locked)`, `protector:chest`
     * All sides: routed to the main slot
 * `wine:wine_barrel`
     * Above: routed to the destination slots
     * Below: routed to the source slot
     * Sides: routed to the source slot

### Advanced settings

This mod has several configurable settings. See settings menu or [settingtypes.txt](settingtypes.txt) for details.

* Hopper texture size: 16x16 pixels (default) or 32x32 pixels
* Single craftable item: output is straight or rotated by 90° to the side based on how you place it (default). When disabled, straight and bent hoppers must be crafted separately.
* Eject items button: option to remove the "eject items" button from hoppers

### Change log

- 0.1 - Initial release from jordan4ibanez
- 0.2 - Fixed tool glitch (wear restored by accident)
- 0.3 - transfer function added
- 0.4 - Supports locked chest and protected chest
- 0.5 - Works with 0.4.13's new shift+click for newly placed Hoppers
- 0.6 - Remove formspec from hopper nodes to improve speed for servers
- 0.7 - Halved hopper capacity, can be dug by wooden pick
- 0.8 - Added Napiophelios' new textures and tweaked code
- 0.9 - Added support for Wine mod's wine barrels
- 1.0 - New furances do not work properly with hoppers so old reverted to abm furnaces
- 1.1 - Hoppers now work with new node timer Furnaces.  Reduced Abm's and tidied code.
- 1.2 - Added simple API so that hoppers can work with other containers.
- 1.3 - Hoppers now call on_metadata_inventory_put and on_metadata_inventory_take, triggering furnace timers via their standard callbacks. Updated side hopper rotation handling to allow it to function in any orientation. Added settings options to use 16-pixel or 32-pixel textures. Added settings option to allow explicit crafting of standard/side hoppers or to allow crafting of a single item that selects which type to use on place. Added in-game documentation via optional "doc" mod dependency
- 1.4 - Added intllib support
- 1.5 - Added chutes
- 1.6 - Added "eject items" button to formspecs, "group" support to the API
- 1.7 - Added sorter block to allow for more sophisticated item transfer arrangements

Lucky Blocks: 2
