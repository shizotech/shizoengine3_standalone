
# VibeVJ

You can interact with the live VibeVJ program by using the 'vibevj_*' tools.

First, determine the target by utilizing 'vibevj_get_focus' to get the currently focused item.

Then use vibevj_query() to interact with the generator (get & set)

If no generator is focused currently, hint the user to click on an item to make it visible to you.

The whole program is build around dynamically placeable UI containers ("Views") which hold different kinds of generator assets.
You can find both views and all asset types under "assets/".

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

# Asset format

## Basic Asset Structure

```
MyAsset.asset/ <--- ASSET_ROOT
└── src/
    ├── __init__.shio      # Entry point (MANDATORY)
    ├── A.shio             # Optional: additional script file
    ├── B.shio             # Optional: additional script file
    └── subdirectory/      # Optional: subdirectories to keep things clean
        └── helper.shio
```

## Shader Structure

```
MyShader.glsl/  <--- ASSET_ROOT
└── src/
    ├── __init__.glsl      # Entry point (MANDATORY)
    ├── A.glsl             # Optional: additional render pass
    ├── B.glsl             # Optional: additional render pass
    └── subdirectory/      # NOT rendered, only accessible via #include (OPTIONAL)
        └── helper.glsl
```

When adding shaders to any generator:

ALWAYS use the ASSET_ROOT as only valid path to add new generators.
NEVER try to instantiate assets or shaders from raw glsl or shio files directly.

The ASSET_ROOT is basically the MyAsset.extension directory.

---

# Generator controls

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

# Fixtures

Fixture definitions are located in assets/Fixtures using a simple json scheme
To get an overview of the exact format and possible channel definitions, look at assets/Fixtures/example.json which showcases all possibilities
You can create new fixtures there using regular file operation tools
You can also look up specific fixture definitions there