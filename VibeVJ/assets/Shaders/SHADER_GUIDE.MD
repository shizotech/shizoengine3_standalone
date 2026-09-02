# Shader Format Documentation

This documentation covers the shader format used in the engine, based on the implementation in `engine/generators/extensions/glsl/shader_loader.shio`.

---

## 1. Directory Structure

Shaders are organized as directories with the `.glsl` extension.

All shaders which produce output WITHOUT any input, are located in `assets/Shaders/Sources`.
Shaders which need an input to work (=effects) are located in `assets/Shaders/Effects`.

ALWAYS put new shaders in the right directory!
Organize new shaders in logical subdirectories to keep it clean.

### Basic Structure

```
MyShader.glsl/
└── src/
    ├── __init__.glsl      # Entry point (MANDATORY)
    ├── A.glsl             # Optional: additional render pass
    ├── B.glsl             # Optional: additional render pass
    └── subdirectory/      # NOT rendered, only accessible via #include (OPTIONAL)
        └── helper.glsl
```

### Key Rules

1. **Entry Point**: `src/__init__.glsl` is **mandatory** and must exist
2. **Render Passes**: All `.glsl` files directly in `src/` (except `__init__.glsl`) become additional render passes
3. **Subdirectories**: Files in `src/subdir/` are **NOT rendered**, only accessible via `#include`
4. **Single File Fallback**: A single `.glsl` file (without directory structure) can also be used
5. **Rich Controls**: Each shader should have uniform controls so every aspect of the shader can be modified, be really expressive on controls for the shader

---

## 2. Shader Inputs

Shader inputs are declared as `uniform sampler2D` uniforms:

```glsl
uniform sampler2D input;
uniform sampler2D input1;
uniform sampler2D input2;
uniform sampler2D mask;
```

### Auto-Binding Behavior

If a shader input has the **same name** as another pass within the shader node, it is **automatically bound** (and not shown in the UI).

**Example:**
```glsl
// In __init__.glsl
uniform sampler2D A;  // Will bind to src/A.glsl automatically
```

### Special Input Names

| Name | Behavior |
|------|----------|
| `input` | Defines the DEFAULT input which should be used in shader chains |
| `main_image` | Automatically binds to the `__init__` pass (first shader) |
| `feedback` | Binds to itself (the current shader), use this for feedback effects |
| `RenderMaskInput` | Binds to the render mask input |

Each effect shader needs exactly one primary "input" input.

---

## 3. Annotation System

Annotations allow setting shader properties and creating UI controls using special comment directives.

### 3.1 Settings Annotation

The `//@settings` directive sets shader default properties:

```glsl
//@settings dtype=float32 format=rgba rendersize=(1920,1080)
```

**Supported Parameters:**

| Parameter | Description | Values |
|-----------|-------------|--------|
| `dtype` or `type` | Component format | `uint8`, `int8`, `uint16`, `int16`, `uint32`, `int32`, `uint64`, `int64`, `float16`, `float32`, `float64` |
| `format` | Pixel format | `r`, `ra`, `rgb`, `rgba`, `bgr`, `bgra`, `depth`, `depthstencil` |
| `rendersize` | Fixed render size | `rendersize=(width,height)` |

**Notes:**
- `rendersize` fixes the render size for this shader
- Component and pixel formats can be fixed per shader

---

### 3.2 Uniform Controls

Annotations create UI controls for uniforms. The annotation is placed **above** the uniform declaration.

#### Scalar Controls

**Slider:**
```glsl
//@slider min=0.0 max=1.0 value=0.5
uniform float cycle;
```
- UI: Slider with number input
- Parameters: `min`, `max`, `value`

**Float:**
```glsl
//@float min=0.0 max=16.0 value=0.0
uniform float offset;
```
- UI: Float number input
- Parameters: `min`, `max`, `value`

**Integer:**
```glsl
//@int min=0 max=10 value=0
uniform int index;
```
- UI: Integer number input
- Parameters: `min`, `max`, `value`

#### Vector Controls

**Floating-Point Vector:**

**vec2:**
```glsl
//@vec2 min=(0,0) max=(1,1) value=(0.5,0.5)
uniform vec2 offset;
```
- UI: Vector with X, Y float inputs
- Supports: `vec2`, `vec3`, `vec4`

**Integer Vector:**

**ivec2:**
```glsl
//@ivec2 min=(0,0) max=(10,10) value=(5,5)
uniform ivec2 offset;
```
- UI: Vector with X, Y integer inputs
- Supports: `ivec2`, `ivec3`, `ivec4`

**Slider Vector:**

**slidervec2:**
```glsl
//@slidervec2 min=(0,0) max=(1,1) value=(0.5,0.5)
uniform vec2 offset;
```
- UI: Vector with X, Y sliders (more precise for ranges)
- Supports: `slidervec2`, `slidervec3`, `slidervec4`

#### Color Controls

**RGB:**
```glsl
//@rgb
uniform vec3 base_color;
```
- UI: RGB sliders (R, G, B)

**RGBA:**
```glsl
//@rgba
uniform vec4 base_color;
```
- UI: RGBA sliders (R, G, B, A)

#### Enum Control

```glsl
//@enum options=(Option 1, Option 2, Option 3)
uniform int test_enum;
```
- UI: Dropdown combo
- Parameter: `options=(val1, val2, ...)`

#### Button Controls

**Button:**
```glsl
//@button
uniform bool active;
```
- UI: Toggle button
- Default value: `false`

**Push Button:**
```glsl
//@pushbutton
uniform int trigger;
```
- UI: Push button (non-toggle)
- Default value: `1` (pressed)

---

### 3.3 Multi-line Annotation Accumulation

Annotations can span multiple lines. The engine accumulates all `//` comment lines after a `//@` directive:

```glsl
//@slider 
// min=0.0
// max=1.0
// value=0.5
uniform float cycle;
```

This is equivalent to:
```glsl
//@slider min=0.0 max=1.0 value=0.5
uniform float cycle;
```

---

## 4. Shadertoy Compatibility

The engine automatically detects and supports Shadertoy-style shaders.

### Auto-Detection

A shader is detected as Shadertoy if it contains the `mainImage` function:

```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord)
```

### Added Uniforms

When Shadertoy is detected, the engine automatically adds:

```glsl
uniform vec3 iResolution;    // (width, height, aspect_ratio)
uniform float iTime;
uniform float iTimeDelta;
uniform int iFrame;          // Auto-increments each frame
//@slidervec4
uniform vec4 iMouse;
uniform vec4 iDate;
uniform float iSampleRate;
uniform sampler2D iChannel0;
uniform sampler2D iChannel1;
uniform sampler2D iChannel2;
uniform sampler2D iChannel3;
uniform int RenderMaskActive;
uniform sampler2D RenderMaskInput;
```

**Note:** `iResolution` third component is the aspect ratio (`width / height`). `iFrame` auto-increments starting from 0 on the first frame.

Do NOT add these uniforms into your shader code yourself!

### Wrapper Code

The engine wraps the shader with:

```glsl
void main() {
    vec4 new_color = vec4(0,0,0,0);
    vec2 n_coord = v_uv * iResolution.xy;
    if(RenderMaskActive == 1) {
        vec4 mask_color = texture(RenderMaskInput, v_uv);
        if(mask_color.rgb == vec3(0.0)) {
            fragColor = new_color;
            return;
        }
    }
    mainImage(new_color, n_coord);
    fragColor = new_color;
}
```

### Example Shadertoy Shader

```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    float d = length(uv - vec2(0.5, 0.5));
    
    vec3 col;
    col.r = texture(iChannel0, vec2(uv.x + 0.01, uv.y)).r;
    col.g = texture(iChannel0, uv).g;
    col.b = texture(iChannel0, vec2(uv.x - 0.01, uv.y)).b;
    
    fragColor = vec4(col, 1.0);
}
```

---

## 5. Include System

The `#include` directive allows modular shader code organization.

### Syntax

```glsl
#include path.glsl
```

### Path Resolution

- Paths are **relative to `src/`**
- Resolved recursively
- Files in subdirectories are accessible

### Example

Given this structure:
```
MyShader.glsl/
└── src/
    ├── __init__.glsl
    ├── helper/
    │   ├── math.glsl
    │   └── noise.glsl
    └── A.glsl
```

Usage in `__init__.glsl`:
```glsl
#include helper/math.glsl
#include helper/noise.glsl
```

### Important Notes

- Files in subdirectories are **NOT rendered** as passes
- They are **only accessible via `#include`**
- This enables modular code organization without creating additional passes

---

## 6. Complete Example

Here's a complete example shader structure:

### File Structure

```
ColorShift.glsl/
└── src/
    ├── __init__.glsl
    └── effects/
        └── helpers.glsl
```

### __init__.glsl

```glsl
#include effects/helpers.glsl

//@settings dtype=float32 format=rgba
//@slider min=0.0 max=1.0 value=0.2
uniform float shift_amount;

//@rgb value=(1.0, 0.0, 0.0)
uniform vec3 shift_color;

//@rgb
uniform vec3 base_color;

uniform sampler2D input1;

void main() {
    vec2 uv = v_uv;
    
    vec4 color = texture(input1, uv);
    
    vec3 shifted;
    shifted.r = texture(input1, uv + vec2(shift_amount, 0.0)).r;
    shifted.g = color.g;
    shifted.b = texture(input1, uv - vec2(shift_amount, 0.0)).b;
    
    fragColor = vec4(mix(color.rgb, shifted, shift_color), 1.0);
}
```

### helpers.glsl

```glsl
vec3 remap(vec3 value, float min_val, float max_val) {
    return clamp((value - min_val) / (max_val - min_val), 0.0, 1.0);
}
```

---

## 7. Summary

| Feature | Description |
|---------|-------------|
| **Directory** | `.glsl` directory with `src/` subdirectory |
| **Sources** | Are shaders without inputs |
| **Effects** | Are shaders with require an input |
| **Entry Point** | `src/__init__.glsl` (mandatory) |
| **Passes** | Additional `.glsl` files in `src/` |
| **Includes** | `#include path.glsl` relative to `src/` |
| **Inputs** | `uniform sampler2D`, auto-binding by name |
| **Annotations** | `//@settings`, `//@slider`, `//@float`, `//@int`, `//@vec2/3/4`, `//@ivec2/3/4`, `//@slidervec2/3/4`, `//@rgb`, `//@rgba`, `//@enum`, `//@button`, `//@pushbutton` |
| **Shadertoy** | Auto-detected via `mainImage` function |

---

## 8. Tips and Best Practices

1. **Always use `__init__.glsl`** as the entry point
2. **Use subdirectories** for helper files to avoid them being rendered as passes
3. **Use auto-binding** by naming inputs to match other passes
4. **Prefer Shadertoy format** by using `mainImage` function name and iTime etc.
5. **Use annotations** for all user-controllable parameters
6. **Set reasonable defaults** in annotation parameters
7. **Organize complex shaders** with `#include` for modular code
8. **NEVER** write in 'assets/Shaders' directly. 
9. **Always** place shaders either in 'assets/Shaders/Sources/<category>' or 'assets/Shaders/Effects/<category>'.

*iTime and beat reactivity*
iTime is not the time in seconds, but rather the current beat (where 1.0 time unit equals one beat)
Use iTime for beat synced audio effects and make sure the animation loops correspond nicely to beats.

---

## 9. Common Failures and Errors

The engine injects header and footer code into the shader.
These injections include the standard 'u_*' uniforms, shadertoy uniforms, a separate "main" entry (if mainImage shadertoy format is detected), alongside other data.
Make sure to not include standard uniforms in your shader code to avoid duplicate definitions.

Do not try to fix the loader, make your code work with the loader instead.

*Prefer shadertoy format for the main function*

Use 'void mainImage(...)' instead of 'void main(...)'.

*Still prefer clear channel names over the classic shadertoy iChannelX notation*

Instead of enforcing iChannelX sampler2D uniforms, give them appropriate names to indicate what they are.
The first (or main) input for any effect shader should be named 'uniform sampler2D input'.
Make sure this doesnt conflict with other variables that might be named 'input'.

---

*Documentation based on implementation in `engine/generators/extensions/glsl/shader_loader.shio`*

## 10. Verification and shader compilation skill (VERY IMPORTANT!)

If you have the skill 'test_glsl_shader' available, ALWAYS use it to verify EACH '.glsl' file with an entry point in your new shader directory.
You do not need to test helper shader files as compiling the main shader files will automatically include them.
Do NOT try to compile the shader directory with the '.glsl' extension directly, instead check each individual '.glsl' file with an entry point within the shader's root directory.
ALWAYS fix all glsl errors, do NOT ship broken shaders!

A note on compile errors with line numbers:

- Do NOT get caught up in line numbers not matching your shader code!
- Always look at the returned 'final_shader_with_lines' to identify the actual offending line
- Identify the wrong code by looking at 'final_shader_with_lines' and then look for the wrong line's text in the actual shader files (identify by text, not line numbers)