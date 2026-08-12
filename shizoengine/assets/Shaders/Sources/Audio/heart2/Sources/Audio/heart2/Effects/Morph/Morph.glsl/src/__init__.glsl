// ==== Custom Uniform Controls ====

//@float min=0.0 max=2.0 value=0.2
uniform float warp_strength;

//@float min=0.1 max=20.0 value=3.0
uniform float warp_frequency;

//@float min=0.0 max=10.0 value=1.0
uniform float warp_speed;

//@int min=1 max=8 value=3
uniform int warp_layers;

//@enum options=(None,Oscillate,Flow,Pulse)
uniform int anim_mode;

//@int min=0 max=1 value=0
uniform int audio_mod;

//@vec3 min=(0.0,0.0,0.0) max=(2.0,2.0,2.0) value=(1.0,1.0,1.0)
uniform vec3 axis_strength;

//@float min=0.1 max=10.0 value=1.0
uniform float wiggle_detail;

//@float min=0.0 max=2.0 value=1.0
uniform float morph_amount;

//@float min=0.0 max=2.0 value=1.0
uniform float saturation;

// ==== Core Shader ====

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

float noise(vec3 x) {
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f*f*(3.0 - 2.0*f);
    float n = p.x + p.y*57.0 + 113.0*p.z;
    return mix(mix(mix(hash(n+  0.0), hash(n+  1.0), f.x),
                   mix(hash(n+ 57.0), hash(n+ 58.0), f.x), f.y),
               mix(mix(hash(n+113.0), hash(n+114.0), f.x),
                   mix(hash(n+170.0), hash(n+171.0), f.x), f.y), f.z);
}

float getAudioInfluence() {
    float sum = 0.0;
    for (int i = 0; i < 64; i++) {
        float band = float(i) / 64.0;
        sum += texture(iChannel1, vec2(band, 0.25)).r;
    }
    return sum / 64.0;
}

vec3 warp(vec3 pos, float t) {
    vec3 warped = pos;
    float amp = warp_strength;
    float freq = warp_frequency;

    for (int i = 0; i < 8; i++) {
        if (i >= warp_layers) break;

        float offset = float(i) * 10.0;
        vec3 n = vec3(
            noise(pos * freq + t + offset),
            noise(pos.yzx * freq + t + offset + 23.4),
            noise(pos.zxy * freq + t + offset + 54.7)
        );
        warped += (n - 0.5) * amp;

        freq *= wiggle_detail;
        amp *= 0.5;
    }
    return warped;
}

vec3 animateWarp(vec3 pos, float time) {
    float t = time * warp_speed;
    if (anim_mode == 0) t = 0.0; // None
    else if (anim_mode == 1) t = sin(time * warp_speed); // Oscillate
    else if (anim_mode == 2) t = time * warp_speed; // Flow
    else if (anim_mode == 3) t = abs(sin(time * warp_speed * 0.5)); // Pulse

    if (audio_mod == 1) {
        float a = getAudioInfluence();
        t *= 0.5 + a;
    }

    return warp(pos, t);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // Maintain aspect ratio and use correct normalization for full image coverage
    vec2 normCoord = (fragCoord - 0.5 * iResolution.xy) / min(iResolution.x, iResolution.y);

    vec3 pos = vec3(normCoord, 0.5);
    vec3 warped = animateWarp(pos * morph_amount * axis_strength, iTime);

    vec2 warped_uv = warped.xy * min(iResolution.x, iResolution.y) / iResolution.xy + 0.5;
    warped_uv = clamp(warped_uv, 0.0, 1.0);

    vec3 col = texture(iChannel0, warped_uv).rgb;

    float avg = (col.r + col.g + col.b) / 3.0;
    col = mix(vec3(avg), col, saturation);

    fragColor = vec4(col, 1.0);
}
