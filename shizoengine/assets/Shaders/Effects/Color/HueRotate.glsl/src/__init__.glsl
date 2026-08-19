//@settings dtype=float32 format=rgba

//@rgb value=(1.0,0.0,0.0)
uniform vec3 hue_color;

// 'in' is a reserved GLSL keyword, so map the documented special
// input name 'in' to a valid internal identifier for the compiler.
#define in in_tex
uniform sampler2D in;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, 1.0/3.0, 2.0/3.0, -1.0/3.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(c.r, p.xyw), vec4(p.xyw, c.r), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void mainImage(out vec4 fragColor, vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 color = texture(in, uv);

    // Hue of the RGB uniform = rotation amount (red=0, green=1/3)
    vec3 uniform_hsv = rgb2hsv(hue_color);
    float rotation = uniform_hsv.x;

    // Convert pixel RGB -> HSV, rotate hue with wrap, convert back
    vec3 hsv = rgb2hsv(color.rgb);
    hsv.x = fract(hsv.x + rotation);

    vec3 output = hsv2rgb(hsv);

    fragColor = vec4(output, color.a);
}
