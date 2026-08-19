// ==== Custom Uniform Controls ====

//@float min=0.0 max=5.0 value=1.0
uniform float edge_strength;

//@float min=0.5 max=5.0 value=1.0
uniform float line_thickness;

//@rgb value=(0.0,0.0,0.0)
uniform vec3 edge_color;

//@float min=0.0 max=1.0 value=1.0
uniform float background_fade;

//@enum options=(Luma,Red Channel,Green Channel,Blue Channel)
uniform int edge_mode;

//@int min=0 max=1 value=0
uniform int invert_edges;

//@int min=0 max=1 value=0
uniform int soft_blend;

//@float min=0.0 max=1.0 value=1.0
uniform float image_opacity;

// ==== Helper Function ====

float toIntensity(vec3 col) {
    if (edge_mode == 0) return dot(col, vec3(0.299, 0.587, 0.114)); // Luma
    else if (edge_mode == 1) return col.r;
    else if (edge_mode == 2) return col.g;
    else return col.b;
}

// ==== Main Shader ====

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pixel = 1.0 / iResolution.xy * line_thickness;

    // Sample the 3x3 surrounding pixels
    vec3 tc[9];
    int i = 0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y)) * pixel;
            tc[i++] = texture(iChannel0, uv + offset).rgb;
        }
    }

    float gray[9];
    for (int j = 0; j < 9; j++) {
        gray[j] = toIntensity(tc[j]);
    }

    // Sobel kernel
    float gx = -gray[0] - 2.0 * gray[3] - gray[6] + gray[2] + 2.0 * gray[5] + gray[8];
    float gy = -gray[0] - 2.0 * gray[1] - gray[2] + gray[6] + 2.0 * gray[7] + gray[8];

    float edge = length(vec2(gx, gy)) * edge_strength;
    edge = clamp(edge, 0.0, 1.0);
    if (soft_blend == 0) edge = step(0.2, edge);
    if (invert_edges == 1) edge = 1.0 - edge;

    // Base color
    vec3 base = texture(iChannel0, uv).rgb;

    // Edge color output
    vec3 edgeOnly = edge * edge_color;

    // Composite background where there is no edge
    vec3 withBackground = mix(edgeOnly, base, (1.0 - edge) * background_fade);

    // Final blend between only lines and full output
    vec3 finalColor = mix(edgeOnly, withBackground, image_opacity);

    fragColor = vec4(finalColor, 1.0);
}
