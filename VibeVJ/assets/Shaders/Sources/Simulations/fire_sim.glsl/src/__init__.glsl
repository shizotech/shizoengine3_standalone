// ==== Fire Simulation - Cellular Automaton with Feedback ====

//@float min=0.0 max=1.0 value=0.8
uniform float fire_heat;

//@float min=-1.0 max=1.0 value=0.0
uniform float fire_wind;

//@rgb value=(1.0,0.9,0.3)
uniform vec3 fire_color_hot;

//@rgb value=(1.0,0.4,0.0)
uniform vec3 fire_color_mid;

//@rgb value=(0.5,0.0,0.0)
uniform vec3 fire_color_cold;

//@float min=0.0 max=1.0 value=0.3
uniform float fire_spread;

//@float min=0.0 max=1.0 value=0.7
uniform float fire_lifespan;

//@float min=0.0 max=2.0 value=1.0
uniform float fire_intensity;

//@float min=0.0 max=1.0 value=0.0
uniform float fire_base_y;

//@float min=0.0 max=1.0 value=1.0
uniform float fire_mouse_interact;


// Hash function for pseudo-random values
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Noise function
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    // Get previous frame (feedback)
    vec4 prevFrame = texture(iChannel0, uv);
    float heat = prevFrame.r;
    
    // Initialize first frame or reset
    if (iFrame == 0 || fire_heat <= 0.0) {
        heat = fbm(vec2(uv.x * 10.0, uv.y * 5.0 + iTime)) * 0.3;
    }
    
    // Base heat source at bottom
    float baseDistance = abs(uv.y - fire_base_y);
    float baseHeat = smoothstep(0.05, 0.0, baseDistance);
    
    // Add heat at base with noise
    float noiseVal = fbm(vec2(uv.x * 8.0 + iTime * 0.5, uv.y * 4.0));
    float sourceHeat = baseHeat * noiseVal * fire_heat * 1.2;
    
    // Apply heat source
    heat += sourceHeat;
    
    // Mouse interaction - add heat at cursor
    if (fire_mouse_interact > 0.0 && iMouse.z > 0.0) {
        vec2 mouseUV = iMouse.xy / iResolution.xy;
        float distToMouse = length(uv - mouseUV);
        float mouseHeat = smoothstep(0.15, 0.0, distToMouse) * fire_mouse_interact * 0.8;
        heat += mouseHeat;
    }
    
    // Cellular automaton rules for fire propagation
    
    // Heat rises (vertical movement)
    vec2 shiftUp = vec2(0.0, 1.0 / iResolution.y);
    float heatFromBelow = texture(iChannel0, uv + shiftUp).r;
    
    // Wind effect (horizontal movement)
    vec2 windShift = vec2(fire_wind * 0.002, 0.0);
    vec2 windPos = uv + windShift;
    float heatFromWind = texture(iChannel0, clamp(windPos, 0.0, 1.0)).r;
    
    // Spread to neighbors
    float leftHeat = texture(iChannel0, uv + vec2(-1.0 / iResolution.x, 0.0)).r;
    float rightHeat = texture(iChannel0, uv + vec2(1.0 / iResolution.x, 0.0)).r;
    float spreadHeat = (leftHeat + rightHeat) * fire_spread * 0.25;
    
    // Combine propagated heat
    float newHeat = heatFromBelow * 0.6 + heatFromWind * 0.3 + spreadHeat;
    
    // Apply lifespan (cooling)
    newHeat *= (1.0 - fire_lifespan * 0.1);
    
    // Clamp heat values
    newHeat = clamp(newHeat, 0.0, 1.0);
    
    // Add some noise for realistic flickering
    float flicker = noise(vec2(uv.x * 20.0, uv.y * 15.0 + iTime * 3.0)) * 0.1;
    newHeat += flicker;
    newHeat = clamp(newHeat, 0.0, 1.0);
    
    // Apply intensity
    newHeat *= fire_intensity;
    
    // Color mapping based on temperature
    vec3 color;
    
    if (newHeat > 0.7) {
        // Hot core - yellow/white
        float t = (newHeat - 0.7) / 0.3;
        color = mix(fire_color_hot, vec3(1.0), t);
    } else if (newHeat > 0.4) {
        // Mid temperature - orange
        float t = (newHeat - 0.4) / 0.3;
        color = mix(fire_color_mid, fire_color_hot, t);
    } else if (newHeat > 0.1) {
        // Cool edges - red/dark red
        float t = (newHeat - 0.1) / 0.3;
        color = mix(fire_color_cold, fire_color_mid, t);
    } else {
        // Very cool - dark
        color = fire_color_cold * newHeat * 2.0;
    }
    
    // Add glow effect
    float glow = newHeat * newHeat * 0.5;
    color += vec3(glow);
    
    // Output current frame for feedback
    fragColor = vec4(newHeat, newHeat, newHeat, 1.0);
}
