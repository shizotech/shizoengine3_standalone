//@settings dtype=float32 format=rgba

#define LAYER_0 // just circles
#define LAYER_1 // sdf
#define LAYER_2 // warp
#define LAYER_3 // normals
#define LAYER_4 // cube maps
//#define LAYER_5 // spikes
#define LAYER_6 // post fx

#define SCREEN_SHAKE_STRENGTH 0.4

#define M_PI 3.14159

float hash(float n)
{
    return fract(sin(n)*43758.5453);
}

float noise(in vec3 x)
{
    vec3 p = floor(x);
    vec3 f = fract(x);

    f = f * f * (3.0 - 2.0 * f);
  
    float n = p.x + p.y * 57.0 + 113.0 * p.z;

    float res = mix(mix(mix( hash(n+  0.0), hash(n+  1.0),f.x),
                        mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y),
                    mix(mix( hash(n+113.0), hash(n+114.0),f.x),
                        mix( hash(n+170.0), hash(n+171.0),f.x),f.y),f.z);
    return res;
}

float fbm( vec3 p )
{
    float f;
    f  = 0.5000*noise( p ); p = p*2.02;
    f += 0.2500*noise( p ); p = p*2.03;
    f += 0.1250*noise( p );
    return f;
}

float bad_random(float seed)
{
    return fract(sin(seed) * 136453.2432);
}

float poly_smin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float dist_squared_circle(vec2 test_pos, vec2 c_pos, float radius, float aspect_ratio)
{
    float a = (test_pos.x - c_pos.x) * aspect_ratio;
    float b = test_pos.y - c_pos.y;
    return a * a + b * b - radius * radius;
}

vec2 xyz_to_polar(vec2 P)
{
    float rho = length(P);
    float theta = atan(P.y,P.x);
    if( theta < 0.0 )
        theta = 2.0*M_PI+theta;
    return vec2(rho,theta);
}

float spikes(float strength, float phase, vec2 center, vec2 pos, float radius, float aspect)
{
    vec2 v = pos - center;
    float d2 = dist_squared_circle(pos, center, radius, aspect);
    if(d2 < 0.0) { return 0.0; }
    
    vec2 polar = xyz_to_polar(v);
    
    float f = 20.0;
    float a = sin(f * polar.y + phase);
    float b = 0.0;
    return strength * pow(0.5 * ((a + b + 1.0)), 9.0);
}

mat4 rotation_matrix(vec3 axis, float angle)
{
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return mat4(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
                0.0,                                0.0,                                0.0,                                1.0);
}

vec2 lava_bias(vec2 p, float t)
{
    vec2 c = vec2(0.5);

    vec2 toC = c - p;
    float d = length(toC);

    float up = smoothstep(1.0, 0.0, d);

    vec2 swirl = vec2(-toC.y, toC.x);

    return vec2(
        swirl.x * (0.10 + 0.10 * sin(t + d*6.0)),
        0.25 * up
    );
}

vec3 normal_from_height_map(vec2 uv, sampler2D tex)
{
    float eps = 1.0 / iResolution.x;
    
    float surfaceCurvature = 0.125;
    
    float x0 = pow(texture(tex, vec2(uv.x - eps, uv.y)).r, surfaceCurvature);
    float x1 = pow(texture(tex, vec2(uv.x + eps, uv.y)).r, surfaceCurvature);
    float y0 = pow(texture(tex, vec2(uv.x, uv.y - eps)).r, surfaceCurvature);
    float y1 = pow(texture(tex, vec2(uv.x, uv.y + eps)).r, surfaceCurvature);
    
    float dz_dx = (x0 - x1) / (2.0 * eps);
    float dz_dy = (y0 - y1) / (2.0 * eps);
    
    vec3 n = vec3(dz_dx, dz_dy, 1.0);
  
    return normalize(n);
}

vec3 desaturate(vec3 in_rgb)
{
    const vec3 W = vec3(0.2125, 0.7154, 0.0721);
    float luminance = dot(in_rgb, W);
    return vec3(luminance, luminance, luminance);
}

vec4 contrast(vec4 in_rgb, float c)
{
    return ((in_rgb - 0.5) * c) + 0.5;
}

vec3 internal_glow(vec3 n)
{
    vec3 glow = desaturate(texture(iChannel2, n.xy).rgb);
    glow = contrast(vec4(glow.rgb, 1.0), 0.1).rgb;
    
    return glow;
}

vec3 fakeReflection(vec3 n)
{
    n = normalize(n);

    vec2 uv;

    vec3 an = abs(n);

    if (an.x > an.y && an.x > an.z)
        uv = vec2(n.y, n.z) / (an.x + 1e-5);
    else if (an.y > an.z)
        uv = vec2(n.x, n.z) / (an.y + 1e-5);
    else
        uv = vec2(n.x, n.y) / (an.z + 1e-5);

    uv = uv * 0.5 + 0.5;

    float t = iTime * 0.1;
    uv += 0.03 * vec2(
        fbm(vec3(n * 2.0)),
        fbm(vec3(n * 2.0 + 7.0))
    );

    vec3 sky = vec3(0.08, 0.02, 0.01);
    vec3 lamp = vec3(1.0, 0.35, 0.05);
    vec3 floor = vec3(0.02, 0.01, 0.01);

    float k = smoothstep(0.2, 0.9, n.y);

    vec3 env = mix(floor, sky, uv.y);
    env = mix(env, lamp, k * 0.6);

    float fresnel = pow(1.0 - abs(n.z), 3.0);
    return env * (0.6 + fresnel);
}

// LAYER_2 uniforms (warp variant)
//@slider min=0.0 max=2.0 value=1.0
uniform float radii_mult = 1.0;
//@slider min=0.0 max=2.0 value=0.08
uniform float blob_dist = 0.08;

// LAYER_3 uniforms (normals variant)
//@slider min=0.0 max=2.0 value=1.0
uniform float norm_mult = 1.0;
//@slider min=0.0 max=2.0 value=1.0
uniform float glow_mult = 1.0;
//@slider min=0.0 max=2.0 value=1.0
uniform float final_mult = 1.0;
//@slider min=0.0 max=2.0 value=2.0
uniform float k = 2.0;
//@slider min=0.0 max=2.0 value=1.0
uniform float reflect_mult = 1.0;
//@rgb value=(0.08, 0.01, 0.8)
uniform vec3 base;
//@rgb value=(0.8, 0.4, 0.05)
uniform vec3 hot;

// LAYER_6 uniforms (post fx variant)
//@slider min=0.0 max=1.0 value=1.0
uniform float mask_strength = 0.5;
//@slider min=0.0 max=1.0 value=0.0
uniform float blur_strength = 0.0;

// Blur variant: enables chromatic aberration blur
//@button
uniform bool blur_variant = false;

// Gaussian blur variant
//@button
uniform bool gaussian_variant = false;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    float aspect_ratio = iResolution.x / iResolution.y;
    
    float blur_strength = 1.0;

    // LAYER_2: warp
    #ifdef LAYER_2
    vec2 warp_uvs = 4.0 * uv + vec2(0.0, iTime * 0.06);
    
    float warp_strength = 0.1;
    
    float zspeed = 0.35;
    float x = 2.0 * fbm(vec3(warp_uvs, 1.0 + iTime * zspeed)) - 1.0;
    float y = aspect_ratio * (2.0 * fbm(vec3(warp_uvs, 0.5 + iTime * zspeed)) - 1.0);
    
    vec2 warped_uv = uv + warp_strength * vec2(x, y);
    uv = warped_uv;
    #endif

    // LAYER_1: SDF metaballs (layer A output)
    #ifdef LAYER_1
    vec2 layer1_sites[15];
    float layer1_radii[15];
    
    for(int i = 0; i < 15; i++)
    {
        float a = float(i) / 15.0;
        vec2 base_site = vec2(
            bad_random(14.7654 * a + 174.24),
            bad_random(81.9414 * a + 25.123)
        );

        float fx = mix(0.05, 0.25, bad_random(10.0 + a));
        float fy = mix(0.04, 0.22, bad_random(20.0 + a));

        float px = 6.28318 * bad_random(30.0 + a);
        float py = 6.28318 * bad_random(40.0 + a);

        vec2 drift = vec2(
            sin(iTime * fx + px),
            cos(iTime * fy + py)
        ) * 0.18;

        vec2 flow = lava_bias(base_site + drift, iTime);

        layer1_sites[i] = base_site + drift + flow * 0.15;
        
        vec2 m = iMouse.xy / iResolution.xy;
        float mouse_dist = dist_squared_circle(layer1_sites[i], m, 0.1, aspect_ratio);
        vec2 repel_dir = normalize(layer1_sites[i] - m);
        float repel_radius = 0.2;
        float repel_strength = 1.0 - mouse_dist - repel_radius;
        repel_strength = clamp(repel_strength, 0.0, 0.18);
        layer1_sites[i] += repel_strength * repel_dir;
        
        layer1_radii[i] = mix(0.055, 0.09, bad_random(762.01 * a + 23.765)) * radii_mult;
    }
    
    float min_dist = 100.0;
    
    for(int i = 0; i < 15; i++)
    {
        float d = dist_squared_circle(uv, layer1_sites[i], layer1_radii[i], aspect_ratio);
        min_dist = poly_smin(d, min_dist, blob_dist);
    }
    
    float layer1_height = 0.0;
    if(min_dist > 0.0)
    {
        layer1_height = 0.0;
    }
    else
    {
        float h = -min_dist;
        layer1_height = smoothstep(-0.1, 0.1, h*1.1);
        layer1_height = pow(layer1_height, 3.3) * 2.0;
    }
    
    vec3 layer1_color = vec3(layer1_height, layer1_height, layer1_height);
    fragColor = vec4(layer1_color, 1.0);
    return;
    #endif

    // LAYER_3: Normals with reflection (layer B output)
    #ifdef LAYER_3
    vec4 layer3_distance = texture(iChannel1, uv);
    vec3 n = normal_from_height_map(uv, iChannel1) * norm_mult;
    
    vec2 m_pos = iMouse.xy / iResolution.xy;
    float dm = -50.0 * dist_squared_circle(uv, m_pos, 0.2, aspect_ratio);
    dm = clamp(dm, 0.0, 1.0);
    
    vec3 internal_color_a = 0.12 * vec3(0.88, 0.55, 0.15);
    vec3 internal_color_b = 0.45 * vec3(0.8, 1.0, 0.2);
    
    vec3 internal_color = mix(internal_color_a, internal_color_b, dm);
    
    float n_dot_v = dot(n, vec3(0.0, 0.0, 1.0));
    n_dot_v = 1.0 - pow(n_dot_v, 6.0);
    vec3 glow = internal_color * (1.0 - n_dot_v);
    
    vec3 layer3_final = vec3(0.0, 0.0, 0.0);
    layer3_final = layer3_final - 0.15 * texture(iChannel0, 0.2 * uv).rrr;
    if(layer3_distance.g > 0.01)
    {
        vec4 reflection = min(vec4(desaturate(fakeReflection(n).rgb), 1.0) * 1.0, vec4(0.999));
        vec4 spec = min(reflection * 2.0, vec4(1.0));
        reflection = vec4(pow(reflection.r, k),
                          pow(reflection.g, k),
                          pow(reflection.b, k), 1.0);
        
        vec3 glow_color = internal_glow(n);
        
        layer3_final = mix(base, hot, pow(uv.y,0.8));
        layer3_final = layer3_final + layer3_final * reflection.xyz * reflect_mult + pow(spec,vec4(10.0)).xyz * 0.1;
        layer3_final = contrast(vec4(layer3_final,1.0), 3.5).rgb * final_mult + glow * glow_color * glow_mult;
    }
    
    fragColor = vec4(layer3_final, 1.0);
    return;
    #endif

    // LAYER_4: Cube maps output
    #ifdef LAYER_4
    fragColor = vec4(vec3(0.0), 1.0);
    return;
    #endif

    // LAYER_3: Normals output (default)
    #ifdef LAYER_3
    fragColor = vec4(vec3(0.0), 1.0);
    return;
    #endif

    // Default: distance field output (layer C output)
    vec4 layerC_distance = texture(iChannel1, uv);
    fragColor = vec4(100.0 * layerC_distance.rgb, 1.0);

    // LAYER_6: Post-processing blur
    if(blur_variant || gaussian_variant)
    {
        float focus_level = texture(iChannel2, vec2(0.03 * iTime, 0.0)).r;
        focus_level = 0.5 * clamp((pow(focus_level, 1.5) - 0.15), 0.0, 1.0);
        if(iMouse.x < 0.01 || iMouse.y < 0.01) { focus_level = 0.0; }
        
        float blur_amt = blur_strength * 0.1;
        
        vec3 blurred = vec3(0.0);
        for(float i = 0.0; i < 12.0; i++)
        {
            float angle = radians(i / 12.0 * 360.0);
            vec2 offset = vec2(cos(angle), sin(angle)) * blur_amt;
            blurred += texture(iChannel0, uv + offset).rgb;
        }
        blurred /= 12.0;
        
        fragColor = vec4(blurred, 1.0);
    }
}