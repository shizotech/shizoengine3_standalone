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

//@vec3 min=(0.0,0.0,0.0) max=(1.0,1.0,1.0) value=(0.1,0.6,1.0)
uniform vec3 line_color;

//@vec3 min=(0.0,0.0,0.0) max=(1.0,1.0,1.0) value=(0.0,0.0,0.0)
uniform vec3 bg_color;

//@float min=0.0 max=1.0 value=0.4
uniform float line_opacity;

//@float min=-180.0 max=180.0 value=0.0
uniform float rotation_y;

//@float min=0.5 max=10.0 value=2.5
uniform float zoom;

//@vec2 min=(-2.0,-2.0) max=(2.0,2.0) value=(0.0,0.0)
uniform vec2 pan;


// iResolution and iTime uniforms are implicitly provided by Shadertoy

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

// Raymarching function that samples volumetric density along ray to render smoky lines
vec4 raymarchLines(vec3 ro, vec3 rd) {
    float t = 0.0;
    float tMax = 10.0;
    float stepSize = 0.05;
    
    vec3 col = vec3(0.0);
    float alpha = 0.0;
    
    for(int i=0; i<200; i++) {
        if(t > tMax || alpha > 0.95) break;
        
        vec3 pos = ro + rd * t;

        // Apply rotation and pan
        float angle = radians(rotation_y);
        mat2 rot = rot2d(angle);
        vec2 xz = rot * pos.xz;
        pos.x = xz.x;
        pos.z = xz.y;
        pos.xy -= pan;

        // Lines arranged in grid in XZ plane
        vec3 nearestPoint = vec3(0.0);

        float minDist = 1e10;

        for(int xi=0; xi < line_grid.x; xi++) {
            for(int zi=0; zi < line_grid.y; zi++) {

                float fx = float(xi) / float(max(line_grid.x - 1, 1));
                float fz = float(zi) / float(max(line_grid.y - 1, 1));

                // Position of line in XZ grid [-1..1]
                float lineX = mix(-1.0, 1.0, fx);
                float lineZ = mix(-1.0, 1.0, fz);

                // Wave offset on Y for current line (time + position for variation)
                float wavePhase = wave_frequency * pos.z + iTime * wave_speed * 6.283185 + float(xi + zi) * 0.5;
                float waveY = sin(wavePhase) * wave_amplitude;

                // Closest point on the line segment along Y axis (line runs vertically along Y)
                vec3 lineStart = vec3(lineX, -2.0 + waveY, lineZ);
                vec3 lineEnd = vec3(lineX, 2.0 + waveY, lineZ);

                float dist = sdSegment3D(pos, lineStart, lineEnd);
                if(dist < minDist) {
                    minDist = dist;
                    nearestPoint = pos;
                }
            }
        }

        // Compute density based on distance to nearest line
        float density = smoothstep(line_thickness, 0.0, minDist);

        // Accumulate color with alpha blending (smoky look)
        float a = density * line_opacity * (1.0 - alpha);
        col += line_color * a;
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

    vec4 col = raymarchLines(ro, rd);

    // Blend over background
    vec3 finalColor = mix(bg_color, col.rgb, col.a);
    fragColor = vec4(finalColor, 1.0);
}
