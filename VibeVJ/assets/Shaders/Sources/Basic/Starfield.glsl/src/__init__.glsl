// ==== Custom Uniform Controls ====

//@int min=10 max=1000 value=200
uniform int star_count;

//@float min=0.01 max=2.0 value=0.5
uniform float star_speed;

//@float min=0.001 max=0.05 value=0.01
uniform float star_size;

//@rgb value=(1.0,1.0,1.0)
uniform vec3 star_color;

//@rgb value=(0.0,0.0,0.05)
uniform vec3 bg_color;

//@int min=1 max=5 value=3
uniform int depth_layers;

// Hash function for pseudo-random star positions
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;

    float time = iTime * star_speed;

    vec3 color = bg_color;

    // Generate stars in layers
    for (int layer = 0; layer < depth_layers; layer++) {
        float layer_depth = float(layer + 1) / float(depth_layers);
        float layer_speed = 1.0 + layer_depth * 2.0;
        float layer_size = star_size * (0.5 + layer_depth * 0.5);
        float layer_brightness = 0.3 + layer_depth * 0.7;

        // Pseudo-random star positions
        vec2 star_uv = uv * (10.0 + layer * 5.0);
        vec2 star_cell = floor(star_uv);
        vec2 star_pos = fract(star_uv) - 0.5;

        // Get random offset for this star
        float rand_val = hash(star_cell + float(layer) * 100.0);
        vec2 offset = vec2(hash(star_cell + rand_val * 317.1), hash(star_cell + rand_val * 731.3)) - 0.5;

        // Animate star movement
        offset.y += time * layer_speed * 0.1;
        offset = fract(offset + 0.5) - 0.5;

        // Calculate distance to star
        float dist = length(star_pos - offset);
        float twinkle = sin(time * 3.0 + rand_val * 6.28) * 0.3 + 0.7;

        // Star brightness based on distance
        float brightness = smoothstep(layer_size * 2.0, 0.0, dist) * twinkle * layer_brightness;

        // Add to color
        color += star_color * brightness;
    }

    fragColor = vec4(color, 1.0);
}