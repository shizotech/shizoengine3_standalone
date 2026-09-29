# TASK SELECTION

Based on the instruction, choose one of the following execution paths:

## DIRECT OPERATION

If the request suggests actions within the currently running program or the currently open project, use DIRECT OPERATION.

In this mode, you operate VibeVJ through the available VibeVJ tools.

- Use the VibeVJ tools to perform the requested actions.
- Do NOT operate on the filesystem level when the requested action can be performed through the running program.
- Do NOT directly modify source files.
- Do NOT read files from the current directory unless absolutely necessary.
- You may list files from the asset directory (`assets/`) to get a grip on what assets are available to the program.
- Do NOT read or inspect asset source/content unless you actually need to understand it to complete the request.
- Prefer using your intuition and the available tools over researching how the program works.
- Choose the fastest reasonable path to the requested result.
- Only investigate or inspect additional information when something does not work as expected or when the information is genuinely required.
- Operate confidently and intuitively, like an experienced pro-user of the software rather than a researcher trying to understand the software from scratch.

Examples that trigger DIRECT OPERATION:

- When the user asks to edit settings
- When the user asks to build a show
- When the user asks to edit the current show
- When the user asks to configure or operate something in the running program
- When the user asks to change parameters or program state
- When the user asks to perform an action that the VibeVJ tools can directly accomplish

WHAT TO DO:

-> Load the `vibevj_live` skill.
-> Do NOT do file operations, unless absolutely necessary to understand.

## EDIT MODE

If the request suggests changes to the engine source code or requires creating/modifying assets, use EDIT MODE.

In this mode, follow your normal implementation routines to make the requested changes to the actual program source or assets.

Load the shizoscript and shizoscript_nanogui skill to work on script files.

Examples:

- When the user asks to create a new asset
- When the user asks to edit an existing asset
- When the user explicitly asks to change functionality of the engine
- When the user explicitly asks to fix or modify engine source code
- When the requested change cannot be performed through the running VibeVJ program and requires source-level changes

Be careful when making changes to engine core files.

Ask for confirmation before modifying engine core files.

Do not modify engine source code merely because doing so would be an alternative way of accomplishing a DIRECT OPERATION request.

WHAT TO DO:

-> Load the `vibevj_build_debug` skill.
-> Load the `vibevj_live` skill (required for debugging later).
-> Implement, Debug.

## MODE SELECTION

Choose the execution path based on what the user is asking you to accomplish.

The important distinction is:

- If the user wants something done in the currently running VibeVJ program, use DIRECT OPERATION.
- If the user wants to change how VibeVJ itself works, use EDIT MODE.
- If the user wants to create or modify an asset, use EDIT MODE.
- If the user wants to configure, manipulate, or operate the current program state, use DIRECT OPERATION.

Do not interpret a request as EDIT MODE simply because source code could potentially be used to accomplish it.

Prefer DIRECT OPERATION whenever the requested result can be achieved through the running program.

## NOT SURE

If you are unsure which execution path applies, assume DIRECT OPERATION.

Load the `vibevj` skill and attempt to accomplish the request using the VibeVJ tools.

Only use EDIT MODE when it is clear that source-level or asset-level changes are actually required.

## RESTRICTED

Do NOT try to escape the current programs enviromnent.
Do NOT issue risky or dangerous console commands.

Generally, try to avoid command line, unless its for debugging shizoscript.

---

# Program File Structure

`assets/` -> The place for you.
`engine/` -> Generally dont touch unless changes to the engine are EXPLICITLY requested.
`src/` -> Same as engine, generally dont touch.

Other directories are generally not if interest for you.

## Asset Directories

The default usable asset directory is `assets/`

With the majority of the usable stuff in `assets/Generators` organized in categories.

Some special more complex generator modules are also in `assets/Mapping`.

Some internally used engine assets can be found in 'engine/assets', you generally dont add or touch these yourself.

### Views

Views are a special kind of generator, specifically ones that can hold other generators (used to build custom UI's and layouts within the program)

Views are in `assets/Views`

### Shaders

Shader assets are located in `assets/Shaders`.
There are two type of shaders:

`sources` -> Any shader that takes NO input and produces visual output on its own

`effects` -> Shaders that need an input to work with, anything that transforms other shaders.

DO NOT confuse `sources` and `effects`!
An `effect` CANNOT produce visuals on its own and WILL BE black without a `source` input!

## Asset format

### Basic Asset Structure

```
MyAsset.asset/ <--- ASSET_ROOT
└── src/
    ├── __init__.shio      # Entry point (MANDATORY)
    ├── A.shio             # Optional: additional script file
    ├── B.shio             # Optional: additional script file
    └── subdirectory/      # Optional: subdirectories to keep things clean
        └── helper.shio
```

### Shader Structure

```
MyShader.glsl/  <--- ASSET_ROOT
└── src/
    ├── __init__.glsl      # Entry point (MANDATORY)
    ├── A.glsl             # Optional: additional render pass
    ├── B.glsl             # Optional: additional render pass
    └── subdirectory/      # NOT rendered, only accessible via #include (OPTIONAL)
        └── helper.glsl
```
