//@settings dtype=float32 format=rgba

//@slider min=0.01 max=1.0 value=0.5
uniform float stripe_width;

//@slider min=0.01 max=1.0 value=0.1
uniform float stripe_spacing;

//@slider min=0.0 max=0.5 value=0.05
uniform float stripe_softness;

//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 fg_color;

//@rgb value=(1.0, 1.0, 1.0)
uniform vec3 bg_color;

//@slider min=0.0 max=1.0 value=0.0
uniform float gradient_strength;

//@enum options=(Horizontal, Vertical) value=0
uniform int orientation;

//@slider min=0.0 max=2.0 value=0.0
uniform float warp_amount;

//@slider min=0.0 max=10.0 value=0.0
uniform float twist_amount;

//@slider min=-5.0 max=5.0 value=1.0
uniform float scroll_speed;

//@slider min=0.0 max=1.0 value=0.0
uniform float scroll_offset;

//@int min=0 max=1 value=1
uniform int animate_warp;

//@int min=0 max=1 value=1
uniform int animate_twist;

//@slider min=-10.0 max=10.0 value=1.0
uniform float warp_anim_speed;

//@slider min=-10.0 max=10.0 value=1.0
uniform float twist_anim_speed;

//@int min=0 max=1 value=0
uniform int enable_grid;

//@int min=0 max=1 value=0
uniform int enable_radial;

//@int min=0 max=1 value=0
uniform int enable_dotted;

//@slider min=-180.0 max=180.0 value=0.0
uniform float pattern_rotation;

//@slider min=0.1 max=10.0 value=1.0
uniform float zoom;

//@vec2 min=(-2.0,-2.0) max=(2.0,2.0) value=(0.0,0.0)
uniform vec2 pan;

//@vec2 min=(0.01,0.01) max=(1.0,1.0) value=(0.1,0.1)
uniform vec2 grid_spacing;

//@int min=0 max=1 value=1
uniform int enable_distortion;

//@slider min=0.0 max=1.0 value=0.2
uniform float distortion_amount;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv -= 0.5;
    uv.x *= iResolution.x / iResolution.y;

    // Apply zoom and pan
    uv *= zoom;
    uv += pan;

    float beatTime = iTime;
    float animated_scroll = scroll_speed * beatTime;
    float offset_scroll = scroll_offset * stripe_spacing;
    float total_scroll = animated_scroll + offset_scroll;

    float animated_twist = twist_amount;
    if (animate_twist == 1)
        animated_twist *= sin(beatTime * twist_anim_speed * 6.283185);

    float animated_warp = warp_amount;
    if (animate_warp == 1)
        animated_warp *= sin(beatTime * warp_anim_speed * 6.283185);

    // Apply rotation
    float rot = radians(pattern_rotation);
    float s = sin(rot);
    float c = cos(rot);
    mat2 rotationMatrix = mat2(c, -s, s, c);
    uv = rotationMatrix * uv;

    // Apply twist
    float angle = animated_twist * uv.y;
    mat2 twist = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
    uv = twist * uv;

    // Apply warping based on orientation
    if (orientation == 0)
        uv.y += sin(uv.x * 10.0 + beatTime * warp_anim_speed * 6.283185) * 0.1 * animated_warp;
    else
        uv.x += sin(uv.y * 10.0 + beatTime * warp_anim_speed * 6.283185) * 0.1 * animated_warp;

    // Apply distortion
    if (enable_distortion == 1)
    {
        float dx = sin(uv.y * 20.0) * distortion_amount * 0.05;
        float dy = cos(uv.x * 20.0) * distortion_amount * 0.05;
        uv += vec2(dx, dy);
    }

    float coord = (orientation == 0) ? uv.y : uv.x;
    coord += total_scroll;

    float spacing = stripe_spacing;
    float pattern = mod(coord + 0.5, spacing);
    float base_stripe = step(pattern, spacing * stripe_width);

    // Dotted effect
    if (enable_dotted == 1)
    {
        float dot = sin((uv.y + uv.x) * 100.0) * 0.5 + 0.5;
        base_stripe *= step(0.5, dot);
    }

    // Radial stripes
    if (enable_radial == 1)
    {
        float angle = atan(uv.y, uv.x);
        float radial = mod(angle + 3.1415926, stripe_spacing * 6.283185);
        base_stripe = step(radial, stripe_spacing * stripe_width);
    }

    // Grid mode overrides base stripe logic
    if (enable_grid == 1)
    {
        float gx = mod(uv.x + 0.5, grid_spacing.x);
        float gy = mod(uv.y + 0.5, grid_spacing.y);
        float sx = step(gx, grid_spacing.x * stripe_width);
        float sy = step(gy, grid_spacing.y * stripe_width);
        base_stripe = max(sx, sy);
    }

    float grad = smoothstep(0.0, stripe_spacing * stripe_softness, pattern) *
                 smoothstep(0.0, stripe_spacing * stripe_softness, stripe_spacing - pattern);

    float blend = mix(base_stripe, grad, gradient_strength);
    vec3 color = mix(bg_color, fg_color, blend);

    fragColor = vec4(color, 1.0);
}
