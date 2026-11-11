//@settings dtype=float32 format=rgba

// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: common ----
const float TAU = 6.28318530717959;

// ---- shader-skills library: color ----
// Relative luminance of linear Rec.709 / sRGB color.
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// ---- shader ----
// --- Relief: the input as a surface lit by a moving light (the Emboss / Normal Map TOPs of TouchDesigner) ---
// The brightness of the input is taken as height. Its slope gives a normal per pixel, which a point light shades
// with diffuse light and a highlight. Output Lit puts the shading on the input colours, Emboss is grey relief, Normal
// map shows the normals as colours (for other shaders: x in red, y in green, up in blue), Height the height alone.
// Light spin moves the light around the middle, in turns per 4 beats.

// The picture that becomes a surface
uniform sampler2D input;

//@enum options=(Lit, Emboss, Normal map, Height) value=0
uniform int output_mode;
//@enum options=(Luma, Red, Green, Blue, Alpha) value=0
uniform int height_source;
//@slider min=0.0 max=20.0 value=4.0
uniform float bump;                 // how steep the surface is
//@slider min=0.5 max=6.0 value=1.5
uniform float sample_distance;      // in pixels: bigger = smoother, wider slopes
//@button
uniform bool invert_height;         // dark parts stand out instead of bright ones
//@slider min=0.0 max=360.0 value=135.0
uniform float light_angle;          // degrees, 0 = from the right
//@slider min=0.0 max=0.7 value=0.35
uniform float light_distance;       // how far the light is from the middle
//@slider min=0.05 max=2.0 value=0.5
uniform float light_height;         // low lights make long shadows on the slopes
//@slider min=-1.0 max=1.0 value=0.0
uniform float light_spin;           // turns per 4 beats
//@rgb value=(1.0, 0.95, 0.85)
uniform vec3 light_color;
//@slider min=0.0 max=1.0 value=0.25
uniform float ambient;
//@slider min=0.0 max=2.0 value=0.6
uniform float specular;
//@slider min=2.0 max=128.0 value=32.0
uniform float shininess;
//@slider min=0.0 max=1.0 value=1.0
uniform float amount;               // 0 = the input unchanged

float heightAt(vec2 uv) {
    vec4 c = texture(input, uv);
    float h;
    if (height_source == 1) h = c.r;
    else if (height_source == 2) h = c.g;
    else if (height_source == 3) h = c.b;
    else if (height_source == 4) h = c.a;
    else h = luminance(clamp(c.rgb, 0.0, 1.0));
    return invert_height ? 1.0 - h : h;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 src = texture(input, uv);
    vec2 px = sample_distance / iResolution.xy;

    float h = heightAt(uv);
    // Sobel slope: smoother than two plain differences
    float tl = heightAt(uv + vec2(-px.x, px.y)), t = heightAt(uv + vec2(0.0, px.y)), tr = heightAt(uv + px);
    float l = heightAt(uv - vec2(px.x, 0.0)), r = heightAt(uv + vec2(px.x, 0.0));
    float bl = heightAt(uv - px), b = heightAt(uv - vec2(0.0, px.y)), br = heightAt(uv + vec2(px.x, -px.y));
    float dx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
    float dy = (tl + 2.0 * t + tr) - (bl + 2.0 * b + br);
    vec3 n = normalize(vec3(-dx * bump, -dy * bump, sample_distance * 2.0));

    vec3 res;
    if (output_mode == 2) {
        res = n * 0.5 + 0.5;
    }
    else if (output_mode == 3) {
        res = vec3(h);
    }
    else {
        // The light in square units over the picture, the surface at height h * 0.1
        float a = radians(light_angle) + iTime * light_spin * TAU * 0.25;
        vec2 aspect = vec2(iResolution.z, 1.0);
        vec3 lightPos = vec3(vec2(0.5) * aspect + light_distance * vec2(cos(a), sin(a)), light_height);
        vec3 pos = vec3(uv * aspect, h * 0.1);
        vec3 L = normalize(lightPos - pos);
        vec3 V = vec3(0.0, 0.0, 1.0);
        float diff = max(dot(n, L), 0.0);
        float spec = pow(max(dot(n, normalize(L + V)), 0.0), shininess) * specular;
        if (output_mode == 1) {
            res = vec3(0.5 + 0.5 * (diff - dot(vec3(0.0, 0.0, 1.0), L))) + spec * 0.5;
        }
        else {
            vec3 albedo = clamp(src.rgb, 0.0, 1.0);
            res = albedo * (ambient + diff * light_color) + spec * light_color;
        }
    }

    fragColor = vec4(mix(src.rgb, clamp(res, 0.0, 1.0), amount), src.a);
}
