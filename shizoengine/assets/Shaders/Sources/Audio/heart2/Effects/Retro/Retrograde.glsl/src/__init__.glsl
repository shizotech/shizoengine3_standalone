// ==== Custom Uniform Controls ====

//@float min=0.0 max=1 value=0.02
uniform float aberration_strength;

//@float min=0.0 max=0.02 value=0.005
uniform float vibration_strength;

//@float min=0.1 max=100.0 value=2.0
uniform float vibration_frequency;

//@float min=0.0 max=1.0 value=0.5
uniform float aberration_softness;

//@float min=0.0 max=5.0 value=0.3
uniform float blur_amount;

//@float min=0.0 max=0.2 value=0.05
uniform float noise_intensity;

//@float min=0.0 max=2.0 value=0.2
uniform float noise_speed;

//@float min=0.0 max=1.0 value=0.3
uniform float vignette_strength;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453);
}

// 9-tap Gaussian blur kernel (simple, small radius)
vec3 gaussianBlur(sampler2D tex, vec2 uv, vec2 resolution, float radius) {
    vec2 texel = 1.0 / resolution;
    float offsets[9];
offsets[0]=-4.;offsets[1]=-3.;offsets[2]=-2.;offsets[3]=-1.;offsets[4]=0.;offsets[5]=1.;offsets[6]=2.;offsets[7]=3.;offsets[8]=4.;
float weights[9];
weights[0]=0.05;weights[1]=0.09;weights[2]=0.12;weights[3]=0.15;weights[4]=0.16;weights[5]=0.15;weights[6]=0.12;weights[7]=0.09;weights[8]=0.05;
    vec3 col = vec3(0.0);
    float total = 0.0;
    for(int i = 0; i < 9; i++) {
        for(int j = 0; j < 9; j++) {
            vec2 offset = vec2(offsets[i], offsets[j]) * texel * radius;
            float w = weights[i] * weights[j];
            col += texture(tex, uv + offset).rgb * w;
            total += w;
        }
    }
    return col / total;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Center coords for radial effect
    vec2 center = vec2(0.5);
    vec2 toCenter = uv - center;
    float dist = length(toCenter);

    // Normalize direction vector (avoid div by zero)
    vec2 dir = dist > 0.0 ? normalize(toCenter) : vec2(0.0);

    // Time based vibration offset
    float vib = sin(iTime * 6.283185 * vibration_frequency) * vibration_strength;

    // Calculate per channel aberration offsets (wavelength dependent)
    float offsetR = aberration_strength * (1.0 + vib) * dist;
    float offsetG = aberration_strength * 0.7 * (1.0 + vib) * dist;
    float offsetB = aberration_strength * 0.4 * (1.0 + vib) * dist;

    // Sample shifted UVs per channel
    vec2 uvR = uv + dir * offsetR;
    vec2 uvG = uv + dir * offsetG;
    vec2 uvB = uv + dir * offsetB;

    // Clamp UVs to [0,1]
    uvR = clamp(uvR, vec2(0.0), vec2(1.0));
    uvG = clamp(uvG, vec2(0.0), vec2(1.0));
    uvB = clamp(uvB, vec2(0.0), vec2(1.0));

    // Sample texture channels separately
    float r = texture(iChannel0, uvR).r;
    float g = texture(iChannel0, uvG).g;
    float b = texture(iChannel0, uvB).b;
    vec3 col = vec3(r, g, b);

    // Apply optional blur for softness
    if(blur_amount > 0.0) {
        vec3 blurred = gaussianBlur(iChannel0, uv, iResolution.xy, blur_amount * 3.0);
        // Blend original and blurred by softness
        col = mix(col, blurred, aberration_softness * blur_amount);
    }

    // Add subtle noise overlay (animated)
    float noise = rand(fragCoord.xy * iTime * noise_speed);
    col += (noise - 0.5) * noise_intensity;

    // Apply vignette for natural falloff
    float vignette = smoothstep(0.8, 0.4, dist);
    col *= mix(1.0, vignette, vignette_strength);

    fragColor = vec4(col, 1.0);
}
