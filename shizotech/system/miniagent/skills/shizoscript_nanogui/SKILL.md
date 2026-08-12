# REQUIRED

(!) This script file requires the `shizoscript` base skill to be loaded.
(!) Make sure you have read the `shizoscript` skill before proceeding with this file.

# Shizoscript Nanogui

Shizoscript Nanogui is a from ground up re-invented version of the original nanogui library, written for shizoscript.

(!) This version of nanogui has VERY LITTLE IN COMMON with the original nanogui library, DO NOT RELY ON INTERNAL KNOWLEDGE!
(!) Always use the shizoscript docs tools when working with shizoscript nanogui:

  1. Get all available nanogui widgets and classes in general:
  
  `shizoscript_docs("nanogui")`
  
  2. Checkout member functions for specific widget types:
  
  `shizoscript_docs("nanogui.widget")`
  

# General Setup

(!) Before you start implementing, ALWAYS use:

    `shizoscript_docs("nanogui")`
    
to get a list of all valid widget types.

Then use this to understand how the widget should be used:

    `shizoscript_docs("nanogui.widget")`
    
Do NOT assume widgets or widget functions without checking the docs!

A nanogui application usually looks like this:

```
// (1) SETUP
import nanogui;

//This is so we can use 'vec2f' as a type directly.
using eigen;

// (2) CONTEXT
ctx = nanogui.context(); 

// (3) WIDGETS
screen = ctx.screen("Hello world");

//Nanogui is heavily designed on chained function calls, where a function without parameters sets an attribute and returns the object itself.
//So for example

w = screen.widget() //Add a "nanogui.widget" object to "screen"
    .anchor_left(0) //Anchor on the left, returns "nanogui.widget" object again
    .anchor_right(0) //Anchor right
    .anchor_top(0)
    .anchor_bottom(0);

//w is now a nanogui.widget()

//Add a new widget to w
btn = w.button("hello").anchor(0).fixed_size([100,100]); //Add a button to 'w' and anchor all sites to '0'

//For vectors, both lists aswell as eigen.vec2x works:

btn.position([100, 100]); //Valid
btn.position(vec2f(100, 100)); //Valid

// (4) END

//IMPORTANT: nanogui's render-thread and input-polling runs in the background and there is no need to refresh the screen or start a loop.
//Instead, just sleep forever if there is no more work to do.
std.sleep(-1); //Sleep forever
```

You can also wrap your application within a class if you prefer object-oriented:

```
import nanogui;
using eigen;

class MyApp
{
    // 'managed' in this context means that the lifetime of these class members is tied to the lifetime of this class, even if there are still active refs.
    managed ctx = None;
    managed screen = None;
    
    __init__() {
        ctx = nanogui.context();
        screen = ctx.screen("ShizoEngineX");
        
        //More widgets etc...
    }
    
    __deinit__() {
        shutdown();
    }
    
    shutdown() {
        std.print("Shutting down engine...");
    }
}

app = MyApp();

std.sleep(-1);
```

# Function chaining

Shizoscript nanogui heavily relies on chained function calls for its script API.

The idea is that most member functions (even if not stated so in the docs):

- Return the object itself when a parameter is given.
- Return the respective value when no parameters are given.

So for example

`w = parent.widget().anchor(0);` <-- `w` is now a "nanogui.widget" because ".anchor(0)" returns the object itself again.

`std.print(widget.anchor_top());` <-- Returns the current anchor value for the top anchor.

# Donts and bad practice

Do not assume any name, function or class from the original public "nanogui" library exists, this is a complete overhaul.

This has nothing todo with the original nanogui except that its both based on nanoVG.


# STRICT DOC-DRIVEN EXECUTION PROTOCOL (MANDATORY)

You MUST follow this exact sequence. No exceptions.

STEP 1 — DISCOVERY  
You MUST call:
    `shizoscript_docs("nanogui")`

- Extract ALL valid widget types
- Store internally as: VALID_WIDGETS

You are NOT allowed to use any widget not present in VALID_WIDGETS.


STEP 2 — PER-WIDGET DOCUMENTATION  
For EVERY widget you intend to use:

    `shizoscript_docs("nanogui.<widget>")`

- Extract ALL valid member functions
- Store internally per widget

You are NOT allowed to call any function not explicitly listed in the widget docs.


STEP 3 — VALIDATION (HARD GATE)

Before generating ANY code, you MUST verify:

- Every widget exists in VALID_WIDGETS
- Every function exists in its corresponding widget documentation

If ANY item is not verified:
→ DO NOT GUESS  
→ DO NOT CONTINUE  
→ Output exactly: NEED_DOC_LOOKUP


STEP 4 — IMPLEMENTATION

Only after full validation, generate code.

Absolutely no assumptions are allowed.


# HARD RULE: NO PRIOR KNOWLEDGE

You are STRICTLY FORBIDDEN from using prior knowledge of:
- the original nanogui library
- common UI frameworks
- guessed widget/function names

If it was not retrieved via `shizoscript_docs`, it does NOT exist.


# ANTI-HALLUCINATION ENFORCEMENT

The following are considered HIGH-RISK hallucinations and MUST NOT be used unless explicitly confirmed via docs:

- label
- textbox
- slider
- window
- layout

If any of these are used without verification → INVALID OUTPUT


# REQUIRED OUTPUT FORMAT

You MUST structure every response as follows:

## Verified Widgets
- <widget_name>
  - source: shizoscript_docs("nanogui")

## Verified Functions
- <widget>.<function>
  - source: shizoscript_docs("nanogui.<widget>")

## Code
<implementation>


# FAILURE MODE

If you are uncertain about ANY widget or function:

→ Output exactly: NEED_DOC_LOOKUP

Do NOT produce partial or guessed code.


# CORE PRINCIPLE

No docs = does not exist  
No verification = do not proceed  
Guessing = failure
