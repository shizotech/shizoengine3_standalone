// MFX2 OrbitClone - Rotate input around center + clone & self-rotate
// Shadertoy format (effect: needs input)
// Inspired by FireCircles. The input image (iChannel0) is rotated around a
// center point; optionally it is cloned into N orbiting copies that each
// self-rotate.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Rotation of the main (center) input around the center point (0..1 = 0..360deg)
//@slider min=-1.0 max=1.0 value=0.0
uniform float rotation;

// Continuous rotation speed of the main image
//@slider min=-4.0 max=4.0 value=0.3
uniform float rot_speed;

// Zoom of the main image
//@slider min=0.2 max=3.0 value=1.0
uniform float zoom;

// Enable the clone/orbit mode
//@slider min=0.0 max=1.0 value=1.0
uniform float clone_amount;

// Number of clones orbiting the center
//@int min=1 max=12 value=4
uniform int clone_count;

// Orbit radius of the clones (fraction of the frame)
//@slider min=0.0 max=1.0 value=0.4
uniform float orbit_radius;

// Orbit speed
//@slider min=-4.0 max=4.0 value=0.5
uniform float orbit_speed;

// Self-rotation speed of each clone
//@slider min=-4.0 max=4.0 value=0.8
uniform float self_rot_speed;

// Scale of the cloned copies
//@slider min=0.1 max=2.0 value=0.5
uniform float clone_scale;

// Background fill for out-of-bounds
//@rgb value=(0.02,0.02,0.05)
uniform vec3 background;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = uv - 0.5;
    p.x *= iResolution.x / iResolution.y;

    // ---- Main image: rotate around center + zoom ----
    float mainRot = rotation * 6.2831853 + iTime * rot_speed;
    float cm = cos(mainRot);
    float sm = sin(mainRot);
    vec2 mp = vec2(p.x * cm - p.y * sm, p.x * sm + p.y * cm);
    vec2 main_uv = mp / max(zoom, 0.001) * 0.5 + 0.5;

    vec3 mainCol = texture(iChannel0, clamp(main_uv, vec2(0.0), vec2(1.0))).rgb;
    // Fallback for out-of-bounds
    vec3 bg = background;
    mainCol = mix(bg, mainCol,
        step(0.0, main_uv.x) * step(main_uv.x, 1.0) * step(0.0, main_uv.y) * step(main_uv.y, 1.0));

    // ---- Clones: orbiting, each self-rotating (FireCircles-style) ----
    vec3 col = mainCol;
    if (clone_amount > 0.001) {
        for (int i = 0; i < 12; i++) {
            if (i >= clone_count) break;
            float fi = float(i);
            // orbit angle for this clone
            float oAng = 6.2831853 * fi / float(max(clone_count, 1)) + iTime * orbit_speed;
            vec2 center = vec2(cos(oAng), sin(oAng)) * orbit_radius;

            // self-rotate the input copy around its own center
            float sRot = iTime * self_rot_speed + fi * 0.6;
            float cs = cos(sRot);
            float ss = sin(sRot);

            // sample the input at this clone's position
            // offset the sampling uv by the clone center (in aspect-corrected space)
            vec2 sp = p - center;
            vec2 rsp = vec2(sp.x * cs - sp.y * ss, sp.x * ss + sp.y * cs);
            vec2 cuv = rsp / max(clone_scale, 0.001) * 0.5 + 0.5;
            vec3 ccol = texture(iChannel0, clamp(cuv, vec2(0.0), vec2(1.0))).rgb;
            ccol = mix(bg, ccol,
                step(0.0, cuv.x) * step(cuv.x, 1.0) * step(0.0, cuv.y) * step(cuv.y, 1.0));

            // only draw the clone inside its own disk (so copies don't overlap the whole frame)
            float d = length(p - center);
            float cover = 1.0 - smoothstep(0.5 * clone_scale - 0.05, 0.5 * clone_scale + 0.05, d);
            // blend the clone on top with clone_amount
            col = mix(col, ccol, clone_amount * cover);
        }
    }

    col = max(bg, col);
    fragColor = vec4(col, 1.0);
}
