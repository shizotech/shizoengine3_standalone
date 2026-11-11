//@settings dtype=float32 format=rgba
// --- EdgeBlend (#586, projection mapping building blocks) ---
// Soft edges for projectors whose pictures overlap: put it on the output of each projector (the effects of a MapLab
// output, or the last effect before an output shader). Each side fades over its overlap with the curve of Paul
// Bourke's edge blending (centre and power), corrected for the gamma of the projector, so the two halves add up to an
// even brightness on the wall. Black level lift brightens the black outside the overlaps to match the doubled black
// inside them. Test shows the ramps on a flat grey. One pass, one read a pixel.

uniform sampler2D input;

//@slider min=0.0 max=1000.0 value=200.0
uniform float blend_left;       // pixels of the overlap on this side (0: no overlap)
//@slider min=0.0 max=1000.0 value=0.0
uniform float blend_right;
//@slider min=0.0 max=1000.0 value=0.0
uniform float blend_top;
//@slider min=0.0 max=1000.0 value=0.0
uniform float blend_bottom;
//@slider min=0.1 max=0.9 value=0.5
uniform float blend_center;     // the brightness of each projector in the middle of the overlap (before gamma)
//@slider min=1.0 max=5.0 value=2.0
uniform float blend_power;      // 1 a straight ramp, more an S curve
//@slider min=1.0 max=3.0 value=2.2
uniform float gamma;            // of the projector: the ramp is made in light and encoded with it
//@slider min=0.0 max=0.2 value=0.0
uniform float black_lift;       // lifts black outside the overlaps to the black of two projectors
//@enum options=(Blend, Ramps only, Test grey) value=0
uniform int view;

// Paul Bourke: f(x) = c (2x)^p for x < 0.5, 1 - (1 - c) (2 (1 - x))^p above; x from the outer edge (0) inwards (1)
float bourke(float x) {
    x = clamp(x, 0.0, 1.0);
    float c = clamp(blend_center, 0.01, 0.99);
    float p = max(blend_power, 0.01);
    return x < 0.5 ? c * pow(2.0 * x, p) : 1.0 - (1.0 - c) * pow(2.0 * (1.0 - x), p);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;
    float w = 1.0;
    float inside = 1.0;   // 1 where no overlap is
    if (blend_left > 0.0) { float x = fragCoord.x / blend_left; w *= bourke(x); inside *= step(1.0, x); }
    if (blend_right > 0.0) { float x = (res.x - fragCoord.x) / blend_right; w *= bourke(x); inside *= step(1.0, x); }
    if (blend_bottom > 0.0) { float x = fragCoord.y / blend_bottom; w *= bourke(x); inside *= step(1.0, x); }
    if (blend_top > 0.0) { float x = (res.y - fragCoord.y) / blend_top; w *= bourke(x); inside *= step(1.0, x); }
    float ramp = pow(w, 1.0 / max(gamma, 0.1));

    vec4 src = texture(input, uv);
    if (view == 1) src = vec4(1.0);
    else if (view == 2) src = vec4(vec3(0.5), 1.0);
    vec3 rgb = src.rgb * ramp;
    rgb += vec3(black_lift) * inside * (1.0 - src.rgb);
    fragColor = vec4(rgb, src.a);
}
