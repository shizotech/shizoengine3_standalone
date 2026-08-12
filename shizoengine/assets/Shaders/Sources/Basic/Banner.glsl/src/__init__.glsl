// ShaderToy: Perspective X banners that shrink & fade into center
// iChannel0 = input text image (PNG with alpha recommended)

#ifdef GL_ES
precision mediump float;
#endif


#define PI 3.14159265359

// --- Tweakable parameters ---
//@slider min=0.0 max=1.0 value=0.28
uniform float BAND_WIDTH_NEAR;
//@slider min=0.0 max=0.1 value=0.01
uniform float BAND_WIDTH_FAR;
//@slider min=0.0 max=2.0 value=1.05
uniform float PERSPECTIVE_LEN;
//@slider min=0.0 max=1.0 value=0.44
uniform float ANGLE;
//@slider min=0.0 max=0.1 value=0.006
uniform float EDGE_SMOOTH;
//@slider min=0.0 max=2.0 value=0.45
uniform float SCROLL_SPEED;
//@slider min=0.0 max=4.0 value=2.2
uniform float TEXT_SCALE_NEAR;
//@slider min=0.0 max=1.0 value=0.6
uniform float TEXT_SCALE_FAR;
//@slider min=0.0 max=4.0 value=2.0
uniform float TILES;
//@slider min=0.0 max=4.0 value=2.2
uniform float FADE_POW;
//@slider min=0.0 max=0.1 value=0.02
uniform float CENTER_CULL_T;

mat2 rot(float a){
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// sample the ribbon for a given ribbon angle
vec4 ribbonSample(vec2 fragN, float angle){
    // aspect-corrected coordinates centered at 0
    float aspect = iResolution.x / iResolution.y;
    vec2 pos = (fragN - 0.5) * vec2(aspect, 1.0);

    // rotate into ribbon-local space: r.x = along axis, r.y = across axis
    vec2 r = rot(angle) * pos;

    // distance from vanishing point along ribbon (abs so both sides behave same)
    float distAlong = abs(r.x);
    
	float side = sign(r.x);   // -1 on left, +1 on right

    // t = 0 => at center (vanishing), t => 1 at/near screen edge (or beyond PERSPECTIVE_LEN)
    float t = clamp(distAlong / PERSPECTIVE_LEN, 0.0, 1.0);

    // width increases with t (wide at edges, narrow near center)
    float bandW = mix(BAND_WIDTH_FAR, BAND_WIDTH_NEAR, t);

    // across-axis mask
    float across = abs(r.y);
    float mask = smoothstep(bandW + EDGE_SMOOTH, bandW - EDGE_SMOOTH, across);

    // fade into distance (toward center) -> alpha decreases as t -> 0
    float fade = pow(t, FADE_POW);

    // optionally cull tiny center region so it 'disappears' cleanly
    if(t <= CENTER_CULL_T || mask <= 1e-4) {
        return vec4(0.0);
    }

    // vertical v coordinate across ribbon (0..1)
    float v = (r.y + bandW) / (2.0 * bandW);
    v = clamp(v, 0.0, 1.0);

    // text scaling: bigger at edges (t~1), smaller at center (t~0)
    float textScale = mix(TEXT_SCALE_FAR, TEXT_SCALE_NEAR, t);

    // scroll direction: top half scrolls one way, bottom half the other
    float dir = fragN.y > 0.5 ? 1.0 : -1.0;

    // u coordinate: use normalized along-distance (t) times textScale and repeat it
    float uRaw = (t * textScale * TILES * side)
           + iTime * SCROLL_SPEED * dir;
	float uFr  = fract(uRaw);

    vec2 texUV = vec2(uFr, v); 
    vec4 tx = texture(iChannel0, texUV);

    // fallback alpha if texture has no alpha channel (use luminance)
    float texA = tx.a;
    if(texA < 0.01){
        float lum = max(max(tx.r, tx.g), tx.b);
        texA = smoothstep(0.00, 0.6, lum);
    }

    float finalA = texA * mask * fade;
    return vec4(tx.rgb, finalA);
}

float ribbonGlowMask(vec2 fragN, float angle){
    float aspect = iResolution.x / iResolution.y;
    vec2 pos = (fragN - 0.5) * vec2(aspect, 1.0);
    vec2 r = rot(angle) * pos;

    float distAlong = abs(r.x);
    float t = clamp(distAlong / PERSPECTIVE_LEN, 0.0, 1.0);
    if(t <= CENTER_CULL_T) return 0.0;

    float bandW = mix(BAND_WIDTH_FAR, BAND_WIDTH_NEAR, t);
    float across = abs(r.y);
    float mask = smoothstep(bandW + EDGE_SMOOTH, bandW - EDGE_SMOOTH, across);

    float fade = pow(t, FADE_POW);
    return mask * fade;
}


void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 fragN = fragCoord.xy / iResolution.xy;

    // simple dark background (tweak colors if you like)
    vec3 bg = vec3(0.00, 0.00, 0.00);

    // sample two diagonal ribbons (X-cross)
    vec4 s1 = ribbonSample(fragN,  ANGLE);
    vec4 s2 = ribbonSample(fragN, -ANGLE);

	float ribbonAlpha = clamp(s1.a + s2.a, 0.0, 1.0);

    // Over-composite: out = bg overlaid by s1 then s2 (standard "over" blending)
    vec3 outCol = bg;
    // s1
    float a1 = s1.a;
    outCol = outCol * (1.0 - a1) + s1.rgb * a1;
    // s2
    float a2 = s2.a;
    outCol = outCol * (1.0 - a2) + s2.rgb * a2;

    // subtle glow near vanishing point (center)
    float g1 = ribbonGlowMask(fragN,  ANGLE);
	float g2 = ribbonGlowMask(fragN, -ANGLE);
	float glow = clamp(g1 + g2, 0.0, 1.0);

	// strong center emphasis, zero lateral spread
	glow = pow(glow, 2.8) * 0.25;

	vec3 glowColor = vec3(0.08, 0.05, 0.02);
	outCol += glowColor * glow * ribbonAlpha;

    // final gamma-ish clamp
    outCol = pow(clamp(outCol, 0.0, 1.0), vec3(0.95));
    fragColor = vec4(outCol, 1.0);
}
