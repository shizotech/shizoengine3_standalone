
# VibeVJ Live

You can interact with the live VibeVJ program by using the 'vibevj_*' tools.

First, determine the target by utilizing 'vibevj_get_focus' to get the currently focused item.

Then use vibevj_query() to interact with the generator (get & set)

If no generator is focused currently, hint the user to click on an item to make it visible to you.

The whole program is build around dynamically placeable UI containers ("Views") which hold different kinds of generator assets.
You can find both views and all asset types under "assets/".

When adding shaders or any generator:

ALWAYS use the ASSET_ROOT as only valid path to add new generators.
NEVER try to instantiate assets or shaders from raw `.glsl` or `.shio` files directly.

The ASSET_ROOT is basically the MyAsset.extension directory.

# vibevj_query()

vibevj_query() takes two arguments:

- name
The name of the action to execute on the generator (you need to choose a valid action as returned by 'vibevj_get_focus'.

- args
The JSON arguments for the query
Arguments are provided for each action returned by 'vibevj_get_focus'.
This should be a ***VALID JSON*** object, ***NOT*** a string!

# live_path

A 'live_path' is NOT a real filesystem path!
Instead, 'live_path' can be used to focus on active generator instances currently within the running instance of the vibevj software.

# each turn

Each new user message resets the current focus path and sets it to the last user focused generator again.

# asset generator controls

The '@' in a controls name is their respective group.

For example

uniforms@x
uniforms@y
uniforms@size

All belong to the same group.

---

Controls which have a '#' in their name are attribute controls.
Attribute controls means that they belong to a parent control (the one with the same prefix but without '#')

For example:

node/control_1 <--- PARENT CONTROL
node/control_1#Min <--- Attribute control
node/control_1#Max <--- Attribute control
node/control_1#Trigger <--- Attribute control

Change attribute controls only when you want to change the attributes of their respective parent control.
Attribute controls do not belong to the generator directly, only their parent control.
You can get and set attribute controls just like any other regular control.

---

# fixtures

## The fixture setup (the lamps of the rig)

Use the tool 'vibevj_fixture_setup(action, args)' for the lamps, groups and Art-Net nodes. You do not need a focus for it.

- 'list_queries' lists every action with its arguments.
- Lamps and groups are named by their id or their name, nodes by MAC, IP or name, fixture types by path or name.
- 'list_fixtures' / 'list_fixture_types' / 'list_fixture_groups' / 'list_artnet_nodes' show what is there.
- 'add_fixtures' adds lamps at the next free DMX addresses (or at 'address'), optionally into a group.
- 'set_fixture' changes one lamp; 'address_fixtures' addresses lamps one after the other; 'arrange_fixtures' places them
  on the stage plan (row, grid, circle); 'remove_fixtures' removes them.
- 'add_fixture_group' / 'set_fixture_group' / 'remove_fixture_group': groups are ordered, the order is the order of a
  Phaser.
- 'get_dmx_universe' shows what uses the 512 channels of a universe of a node; 'get_dmx_conflicts' lists every place where
  two senders (lamps, LEDMapper segments) write the same channels. Check it after you changed addresses and tell the user
  about conflicts.
- 'highlight_fixtures' lights lamps at full so the user finds them in the rig (empty list: off).

## Fixture types

Fixture definitions are located in assets/Fixtures using a simple json scheme
To get an overview of the exact format and possible channel definitions, look at assets/Fixtures/example.json which showcases all possibilities
You can create new fixtures there using regular file operation tools
You can also look up specific fixture definitions there