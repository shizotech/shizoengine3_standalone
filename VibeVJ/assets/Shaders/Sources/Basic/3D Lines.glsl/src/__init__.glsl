// ==== Custom Uniform Controls ====

//@vec2 min=(1,1) max=(100,100) value=(2,2)
uniform vec2 line_grid;

//@float min=0.001 max=0.2 value=0.05
uniform float line_thickness;

//@float min=0.0 max=1.0 value=0.3
uniform float wave_amplitude;

//@float min=0.1 max=20.0 value=3.0
uniform float wave_frequency;

//@float min=-10.0 max=10.0 value=1.0
uniform float wave_speed;

//@rgb value=(0.1,0.6,1.0)
uniform vec3 line_color;

//@rgb value=(0.0,0.0,0.0)
uniform vec3 bg_color;

//@float min=0.0 max=1.0 value=0.4
uniform float line_opacity;

//@float min=-180.0 max=180.0 value=0.0
uniform float rotation_y;

//@float min=0.5 max=10.0 value=2.5
uniform float zoom;

//@vec2 min=(-2.0,-2.0) max=(2.0,2.0) value=(0.0,0.0)
uniform vec2 pan;

//@int min=0 max=1 value=0
uniform int audio_reactive;

//@float min=0.0 max=2.0 value=1.0
uniform float audio_influence;

//@float min=0.0 max=20.0 value=1.0
uniform float hue_speed;

//@float min=0.0 max=2.0 value=0.6
uniform float glow_strength;

// iResolution and iTime uniforms are implicitly provided by Shadertoy

// Convert a hue in [0,1] to an RGB color (rainbow cycling helper)
#define hue2rgb(hue) 0.5 + 0.5 * cos(6.283185 * hue + vec3(0.0, 2.094, 4.18879))

// Rotate 2D vector by angle in radians
mat2 rot2d(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Signed distance from point p to line segment a-b in 3D
float sdSegment3D(vec3 p, vec3 a, vec3 b) {
    vec3 pa = p - a;
    vec3 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Distance to the single nearest line, computed analytically (O(1) instead of O(gx*gy)).
// Uses a passed-in amplitude (so audio reactivity can modulate it).
// Writes the per-line wave offset to waveYOut.
float nearestLineDist(vec3 pos, float amplitude, out float waveYOut) {
    int gx = max(int(line_grid.x), 2);
    int gy = max(int(line_grid.y), 2);
    
    float fx = (pos.x + 1.0) * 0.5;
    float fz = (pos.z + 1.0) * 0.5;
    
    int cx = int(clamp(round(fx * float(gx - 1)), 0, gx - 1));
    int cz = int(clamp(round(fz * float(gy - 1)), 0, gy - 1));
    
    float lineX = mix(-1.0, 1.0, float(cx) / float(gx - 1));
    float lineZ = mix(-1.0, 1.0, float(cz) / float(gy - 1));
    
    float wavePhase = wave_frequency * pos.z + iTime * wave_speed * 6.283185 + float(cx + cz) * 0.5;
    float waveY = sin(wavePhase) * amplitude;
    waveYOut = waveY;
    
    vec3 lineStart = vec3(lineX, -2.0 + waveY, lineZ);
    vec3 lineEnd = vec3(lineX, 2.0 + waveY, lineZ);
    return sdSegment3D(pos, lineStart, lineEnd);
}

// Sample the FFT texture (iChannel1) across a window of the spectrum.
float getAudioInfluence() {
    float sum = 0.0;
    for (int i = 0; i < 32; i++) {
        float band = float(i) / 32.0;
        sum += texture(iChannel1, vec2(band, 0.0)).r;
    }
    return sum / 32.0;
}

// Raymarching function that samples volumetric density along ray to render smoky lines
vec4 raymarchLines(vec3 ro, vec3 rd, vec3 color) {
    float t = 0.0;
    float tMax = 10.0;
    float stepSize = 0.05;
    
    vec3 col = vec3(0.0);
    float alpha = 0.0;

    // Per-frame-constant rotation, computed once outside the loop
    float angle = radians(rotation_y);
    mat2 rot = rot2d(angle);
    
    // Audio reactivity: sample the FFT texture once before the raymarch loop
    float audio = (audio_reactive == 1) ? getAudioInfluence() : 0.0;
    float effAmp = wave_amplitude * (1.0 + audio_influence * audio);
    
    for(int i=0; i<200; i++) {
        if(t > tMax || alpha > 0.95) break;
        
        vec3 pos = ro + rd * t;
        
        // Apply rotation and pan (rotation matrix hoisted before the loop)
        vec2 xz = rot * pos.xz;
        pos.x = xz.x;
        pos.z = xz.y;
        pos.xy -= pan;
        
        // Distance to the single nearest line, computed analytically (O(1))
        float waveY;
        float minDist = nearestLineDist(pos, effAmp, waveY);

        // Compute density based on distance to nearest line
        float density = smoothstep(line_thickness, 0.0, minDist);

        // Softer, wider glow/halo around each line
        float glow = smoothstep(max(line_thickness * 4.0, 0.5), 0.0, minDist) * glow_strength;

        // Accumulate color with alpha blending (smoky look)
        float a = (density + glow * 0.5) * line_opacity * (1.0 - alpha);
        col += color * a;
        alpha += a;

        t += stepSize;
    }

    return vec4(col, clamp(alpha, 0.0, 1.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Convert fragCoord to normalized device coords [-1,1]
    vec2 uv = (fragCoord.xy / iResolution.xy) * 2.0 - 1.0;
    uv.x *= iResolution.x / iResolution.y;

    // Camera origin and direction
    vec3 ro = vec3(0.0, 0.0, zoom);
    vec3 rd = normalize(vec3(uv.x, uv.y, -1.5));

    // When hue_speed > 0, cycle the line color through the rainbow over time;
    // when hue_speed == 0, fall back to the static line_color.
    vec3 activeColor = (hue_speed > 0.0) ? hue2rgb(iTime * hue_speed * 0.05) : line_color;

    vec4 col = raymarchLines(ro, rd, activeColor);

    // Blend over background
    vec3 finalColor = mix(bg_color, col.rgb, col.a);
    fragColor = vec4(finalColor, 1.0);
}
