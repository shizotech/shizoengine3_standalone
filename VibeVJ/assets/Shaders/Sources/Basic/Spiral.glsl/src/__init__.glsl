// ==== Custom Uniform Controls ====

//@int min=1 max=20 value=5
uniform int spiral_arms;

//@float min=0.01 max=0.5 value=0.1
uniform float spiral_thickness;

//@float min=0.0 max=0.5 value=0.05
uniform float spiral_softness;

//@rgb value=(0,0,0)
uniform vec3 fg_color;

//@rgb value=(1,1,1)
uniform vec3 bg_color;

//@float min=0.0 max=1.0 value=0.5
uniform float gradient_strength;

//@float min=-180.0 max=180.0 value=0.0
uniform float spiral_rotation;

//@float min=0.1 max=10.0 value=1.0
uniform float zoom;

//@vec2 min=(-2,-2) max=(2,2) value=(0,0)
uniform vec2 pan;

//@float min=0.01 max=5.0 value=0.5
uniform float spiral_spacing;

//@float min=-10.0 max=10.0 value=0.0
uniform float twist_amount;

//@float min=0.0 max=1.0 value=0.0
uniform float warp_amount;

//@int min=0 max=1 value=1
uniform int animate_rotation;

//@float min=-5.0 max=5.0 value=0.5
uniform float rotation_speed;

//@int min=0 max=1 value=1
uniform int animate_warp;

//@float min=-10.0 max=10.0 value=1.0
uniform float warp_anim_speed;

//@int min=0 max=1 value=0
uniform int enable_dotted;

//@int min=0 max=1 value=0
uniform int invert_colors;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord.xy / iResolution.xy) - 0.5;
    uv.x *= iResolution.x / iResolution.y;

    // Apply zoom and pan
    uv *= zoom;
    uv += pan;

    // Polar coordinates
    float r = length(uv);
    float angle = atan(uv.y, uv.x);

    // Spiral rotation animation
    float rot = radians(spiral_rotation);
    if (animate_rotation == 1)
    {
        rot += iTime * rotation_speed * 6.283185; // full rotation per beat
    }

    angle -= rot;

    // Apply twist
    angle += twist_amount * r;

    // Warp effect
    float warp = 0.0;
    if (animate_warp == 1)
    {
        warp = sin(iTime * warp_anim_speed * 6.283185 + r * 10.0) * warp_amount;
    }
    angle += warp;

    // Calculate spiral pattern
    float arms = float(spiral_arms);
    float spacing = spiral_spacing;
    
    // Modulate angle by spiral arms count and spacing
    float spiralValue = mod(angle * arms / (2.0 * 3.1415926) + r / spacing, 1.0);

    // Create soft edges for spiral arms
    float edgeDist = abs(spiralValue - 0.5);
    float edgeSmooth = smoothstep(spiral_thickness * 0.5 + spiral_softness, spiral_thickness * 0.5, edgeDist);

    // Gradient inside spiral arms
    float gradient = smoothstep(0.0, spiral_thickness, spiralValue) * smoothstep(spiral_thickness, 0.0, spiralValue);
    gradient = mix(1.0, gradient, gradient_strength);

    // Dotted effect
    float dotMask = 1.0;
    if (enable_dotted == 1)
    {
        float freq = 30.0;
        float dots = step(0.5, fract(r * freq));
        dotMask = dots;
    }

    // Final mask
    float mask = edgeSmooth * dotMask;

    // Invert colors if enabled
    vec3 color = mix(bg_color, fg_color, mask);
    if (invert_colors == 1)
        color = mix(fg_color, bg_color, mask);

    fragColor = vec4(color, 1.0);
}
