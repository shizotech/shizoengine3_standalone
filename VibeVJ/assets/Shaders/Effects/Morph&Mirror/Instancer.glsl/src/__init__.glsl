//@settings dtype=float32 format=rgba
// --- Instancer: a picture as copies of a shape - a grid, a circle, a ball or a scatter of dots, squares, stars...
// whose size, colour, turn and depth follow the picture (TouchDesigner instancing) ---
// Pass I draws the copies (lib/common.glsl says how), this pass puts them over the background.

uniform sampler2D I;
uniform sampler2D input;

//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;
//@slider min=0.0 max=1.0 value=0.0
uniform float picture_behind;       // the input picture under the copies

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 copies = texture(I, uv);                            // premultiplied, alpha 0 where they add
    vec3 base = mix(background, texture(input, uv).rgb, picture_behind);
    vec3 col = base * (1.0 - clamp(copies.a, 0.0, 1.0)) + max(copies.rgb, vec3(0.0));
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
