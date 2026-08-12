//@settings dtype=float32 format=rgba
#define AA 2
#define NH 4
#define NV 12
#define PI 3.14159265

float prm(float a, float b, float x) {
    return clamp((x - a) / (b - a) , 0.0, 1.0);
}

float par(float x) {
    return 1.0 - pow(2.0 * x - 1.0, 2.0);
}

float length_sq(vec2 x) {
    return dot(x, x);
}

float segment_df(vec2 uv, vec2 p0, vec2 p1) {
  float l2 = length_sq(p1 - p0);
  float t = clamp(dot(uv - p0, p1 - p0) / l2, 0.0, 1.0);
  vec2 projection = p0 + t * (p1 - p0);
  return distance(uv, projection);
}

// https://stackoverflow.com/a/2049593/8259873
float segment_side(vec2 p0, vec2 p1, vec2 p2)
{
    return (p0.x - p2.x) * (p1.y - p2.y) - (p1.x - p2.x) * (p0.y - p2.y);
}

bool triangle_in(vec2 uv, vec2 p0, vec2 p1, vec2 p2)
{
    float d0 = segment_side(uv, p0, p1);
    float d1 = segment_side(uv, p1, p2);
    float d2 = segment_side(uv, p2, p0);

    bool has_neg = (d0 < 0.0) || (d1 < 0.0) || (d2 < 0.0);
    bool has_pos = (d0 > 0.0) || (d1 > 0.0) || (d2 > 0.0);

    return !(has_neg && has_pos);
}

float triangle_sdf(vec2 uv, vec2 p0, vec2 p1, vec2 p2) {
    float p0p1 = segment_df(uv, p0, p1);
    float p1p2 = segment_df(uv, p1, p2);
    float p2p0 = segment_df(uv, p2, p0);
    float abs_diff = min(p0p1, min(p1p2, p2p0));
    return triangle_in(uv, p0, p1, p2) ? -abs_diff : abs_diff;
}

float sun_sdf(vec2 uv) {
    bool is_in = true;
    float t = mod(iTime, 4.0) / 4.0;
    float lo[7] = float[7](0.2, 0.03, -0.14, -0.31, -0.48, -0.65, -0.8);
    float hi[7] = float[7](0.2, 0.05, -0.1, -0.25, -0.4, -0.55, -0.7);
    float bands_sdf = 10.0;
    for(int i = 0; i < 6; i++) {
        float low = mix(lo[i+1], lo[i], t);
        float high = mix(hi[i+1], hi[i], t);
        float band_sdf = max(uv.y-high, low-uv.y);
        bands_sdf = min(bands_sdf, band_sdf);
    }
    float circle_sdf = length(uv) - 0.7;
    return max(circle_sdf, -bands_sdf);
}

float sq(float x) {
    return x * x;
}

bool palm_in(vec2 uv) {
    const float ah[NH] = float[NH](0.1, 0.25, 1.5, 2.5);
    const float bh[NH] = float[NH](0.2, 0.75, -0.37, -0.17);
    const float ch[NH] = float[NH](-0.17, 0.07, -0.147, 0.255);
    const float dh[NH] = float[NH](-0.8, -0.8, 0.3, 0.1);
    const float eh[NH] = float[NH](0.3, 0.1, 0.57, 0.37);
    const float fh[NH] = float[NH](-1.7, -1.7, 0.3, 0.1);
    const float gh[NH] = float[NH](0.3, 0.1, 0.57, 0.37);
    const float th0[NH] = float[NH](0.01, 0.01, 0.005, 0.005);
    const float th1[NH] = float[NH](0.03, 0.03, 0.03, 0.03);

    bool h_in = false;
    for(int i = 0; i < NH; i++) {
        float h_dist = abs(uv.x - (ah[i] * sq(uv.y + bh[i]) + ch[i]));
        h_in = h_in || h_dist < mix(th0[i], th1[i], par(prm(fh[i], gh[i], uv.y)))
            && uv.y > dh[i] && uv.y < eh[i];
    }
    
    const float av[NV] = float[NV](-2.7, -1.6, -3.5, -3.5, -2.0, -2.5,
                                   -2.0, -1.6, -3.0, -3.5, -2.5, -3.0);
    const float bv[NV] = float[NV](0.17, 0.3, 0.35, -0.095, -0.02, 0.2,
                                   -0.225, -0.095, -0.045, -0.495, -0.4, -0.248);
    const float cv[NV] = float[NV](0.3, 0.35, 0.46, 0.5, 0.35, 0.31,
                                   0.1, 0.15, 0.25, 0.3, 0.15, 0.1);
    const float dv[NV] = float[NV](-0.5, -0.65, -0.5, -0.15, -0.15, -0.15,
                                   -0.155, -0.255, -0.1, 0.26, 0.26, 0.25);
    const float ev[NV] = float[NV](-0.14, -0.14, -0.14, 0.15, 0.25, 0.15,
                                   0.255, 0.255, 0.255, 0.57, 0.645, 0.545);

    bool v_in = false;
    for(int i = 0; i < NV; i++) {
        float v_dist = abs(uv.y - (av[i] * sq(uv.x + bv[i]) + cv[i]));
        v_in = v_in || v_dist < mix(0.005, 0.04, par(prm(dv[i], ev[i], uv.x)))
            && uv.x > dv[i] && uv.x < ev[i];
    }

    return h_in || v_in;
}

mat2 rotation_mat(float alpha) {
    float c = cos(alpha);
    float s = sin(alpha);
    return mat2(c, s, -s, c);
}

vec4 sampleColor(in vec2 sampleCoord)
{
    // uv is centered and such that the vertical values are between -1
    // and 1 while preserving the aspect ratio.
    vec2 uv = 2.0* (sampleCoord - iResolution.xy / 2.0) / iResolution.y;

    const vec3 BG = vec3(0.1, 0.1, 0.2);
    vec3 cyan = vec3(0.3, 0.85, 1);
    vec3 magenta = vec3(1, 0.1, 1);
    float t = sin(0.3 * cos(0.2 * iTime) * uv.x + uv.y + 1.0 + 0.15 * cos(0.3 * iTime));
    vec3 cm = mix(cyan, magenta, t*t);
    vec3 mc = mix(magenta, cyan, t*t);
    
    vec2 a = vec2(0, -0.9);
    vec2 b = vec2(-1.0, 0.4);
    vec2 c = vec2(1.1, 0.6);
    
    float alpha = 0.25 * cos(0.5 * iTime);
    float gamma = -0.1 + 0.2 * cos(PI + 0.5 * iTime);
    float beta = (alpha + gamma) / 2.0;
    mat2 alpha_mat = rotation_mat(alpha);
    mat2 beta_mat = rotation_mat(beta);
    mat2 gamma_mat = rotation_mat(gamma);

    vec2 t0a = alpha_mat * a;
    vec2 t0b = alpha_mat * b;
    vec2 t0c = alpha_mat * c;
    vec2 t1b = mix(t0a, t0b, 3.0);
    vec2 t1c = mix(t0a, t0c, 3.0);
    vec2 t2a = beta_mat * a;
    vec2 t2b = beta_mat * b;
    vec2 t2c = beta_mat * c;
    vec2 t3a = gamma_mat * a;
    vec2 t3b = gamma_mat * b;
    vec2 t3c = gamma_mat * c;
    
    float sun = sun_sdf(uv);
    bool palm = palm_in(uv);
    float tri0_sdf = triangle_sdf(uv, t0a, t0b, t0c);
    float tri1_sdf = triangle_sdf(uv, t0a, t1b, t1c);
    float tri2_sdf = triangle_sdf(uv, t2a, t2b, t2c);
    float tri3_sdf = triangle_sdf(uv, t3a, t3b, t3c);
    
    vec3 col = BG;
    
    if(tri3_sdf < 0.0) col = vec3(0);
    else if(tri3_sdf < 0.01) col = mc;
    if(tri2_sdf < 0.0) col = mc;
    if(tri0_sdf < 0.0) col = vec3(0);
    else if(tri0_sdf < 0.01) col = mc;
    if(tri1_sdf < 0.0) col = mix(cm, col, smoothstep(0.0, 0.01, sun));
    if(tri1_sdf < 0.0 && palm) col = vec3(0);

    return vec4(col, 1.0);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    vec4 colSum = vec4(0);
    for(int i = 0; i < AA; i++) {
        for(int j = 0; j < AA; j++) {
            colSum += sampleColor(fragCoord + vec2(float(i) / float(AA), float(j) / float(AA)));
        }
    }
    fragColor = colSum / colSum.w;
}
