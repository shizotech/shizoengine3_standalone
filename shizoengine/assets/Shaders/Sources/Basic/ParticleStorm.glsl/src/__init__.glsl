// ParticleStorm.glsl
// GPU-based particle system generator for VJ shaders
// Creates dynamic particle explosions with physics simulation
// All particle data is computed on the GPU using hash functions

// --- Particle Parameters ---
uniform float particle_count;
uniform float particle_speed;
uniform float particle_gravity;
uniform float particle_size;
//@rgb
uniform vec3  particle_colors;
uniform float particle_life;
uniform float particle_emission;
uniform float particle_spread;

// --- Hash & Noise Functions ---
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yy) * p3.zy);
}

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float noise2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// --- Particle Generation ---
// Returns particle position and velocity given an ID and time
vec2 getParticlePos(float id, float t) {
    float age = mod(t * particle_emission + id * 0.1, particle_life);
    float lifeRatio = age / particle_life;
    
    float h = hash1(id);
    float h2 = hash1(id + 100.0);
    
    vec2 dir = vec2(cos(h * 6.28318), sin(h2 * 6.28318));
    float speed = particle_speed * (0.5 + h * 0.5);
    
    vec2 pos = vec2(0.0);
    vec2 vel = dir * speed;
    
    float dt = age;
    pos += vel * dt;
    pos.y += 0.5 * particle_gravity * dt * dt;
    
    return pos;
}

vec3 getParticleColor(float id, float t) {
    float h = hash1(id);
    float lifeRatio = mod(t * particle_emission + id * 0.1, particle_life) / particle_life;
    
    vec3 col1 = particle_colors;
    vec3 col2 = vec3(1.0 - h, 0.5 + h * 0.5, 0.2);
    vec3 col3 = vec3(0.8, 0.3, 1.0);
    
    float t1 = smoothstep(0.0, 0.3, lifeRatio);
    float t2 = smoothstep(0.3, 0.7, lifeRatio);
    
    vec3 col = mix(col1, col2, t1);
    col = mix(col, col3, t2 * 0.5);
    
    float alpha = 1.0 - lifeRatio;
    col *= alpha * (0.7 + 0.3 * sin(id + t * 2.0));
    
    return col;
}

// --- Mouse Interaction ---
vec2 getMousePos() {
    return vec2(0.5);
}

bool isMousePressed() {
    return false;
}

// --- Particle Rendering ---
vec3 drawParticle(vec2 uv, vec2 pos, float size, vec3 col, float t) {
    vec2 diff = uv - pos;
    float dist = length(diff);
    float radius = size * 0.003;
    
    // Core glow
    float core = smoothstep(radius * 2.0, 0.0, dist);
    float glow = exp(-dist * dist / (radius * radius * 2.0)) * 0.5;
    float ring = smoothstep(radius, radius * 0.5, dist) * smoothstep(radius * 0.3, radius * 0.5, dist);
    
    // Twinkle effect
    float h = hash1(floor(pos.x * 100.0) + floor(pos.y * 100.0));
    float twinkle = 0.7 + 0.3 * sin(t * 3.0 + h * 6.28);
    
    return (core + glow + ring * 0.3) * col * twinkle;
}

// --- Main Image ---
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 center = vec2(iResolution.xy * 0.5);
    vec2 uv = (fragCoord - center) / iResolution.y;
    
    vec2 mouse = getMousePos() * 2.0 - 1.0;
    mouse.y = -mouse.y;
    mouse = mouse * 1.5;
    
    int count = int(particle_count);
    vec3 color = vec3(0.0);
    
    for (int i = 0; i < 2000; i++) {
        if (i >= count) {
            break;
        }
        
        float id = float(i);
        vec2 pos = getParticlePos(id, iTime);
        vec3 col = getParticleColor(id, iTime);
        
        // Apply spread
        float h = hash1(id);
        pos += vec2(cos(h * 6.28), sin(h * 6.28)) * particle_spread * 0.1;
        
        // Convert to screen space for rendering
        vec2 screenUV = uv - pos * 0.5;
        
        float alpha = col.r + col.g + col.b;
        if (alpha > 0.01) {
            vec3 pColor = drawParticle(screenUV, vec2(0.0), particle_size, col, iTime);
            color += pColor;
        }
    }
    
    // Additive blending background
    vec3 bg = vec3(0.01, 0.01, 0.02);
    vec3 finalColor = bg + color;
    
    // Tone mapping
    finalColor = finalColor / (finalColor + vec3(1.0));
    finalColor = pow(finalColor, vec3(0.8));
    
    fragColor = vec4(finalColor, 1.0);
}
