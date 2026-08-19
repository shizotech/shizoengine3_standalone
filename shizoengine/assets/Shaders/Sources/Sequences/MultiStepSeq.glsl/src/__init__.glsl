// MultiStepSeq - Multi-stage sequential animation builder
// Defines up to 5 sequence stages that play sequentially in time
// Each stage has: start time offset, color, duration, and shape (Solid, Circle, Fade)
//
precision highp float;

// Standard hash function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// ==== Custom Uniform Controls ====

//@int min=1 max=5 value=3
uniform int stage_count;

//@float min=0.1 max=3.0 value=1.0
uniform float sequence_speed;

//@int min=1 max=32 value=8
uniform int grid_x;

//@int min=1 max=32 value=8
uniform int grid_y;

// Stage 1 controls
//@rgb value=(1.0, 0.2, 0.2)
uniform vec3 stage1_color;
//@float min=0.0 max=10.0 value=0.0
uniform float stage1_offset;
//@float min=0.1 max=10.0 value=2.0
uniform float stage1_duration;
//@int min=0 max=2 value=0
uniform int stage1_shape;

// Stage 2 controls
//@rgb value=(0.2, 1.0, 0.2)
uniform vec3 stage2_color;
//@float min=0.0 max=10.0 value=2.0
uniform float stage2_offset;
//@float min=0.1 max=10.0 value=2.0
uniform float stage2_duration;
//@int min=0 max=2 value=0
uniform int stage2_shape;

// Stage 3 controls
//@rgb value=(0.2, 0.2, 1.0)
uniform vec3 stage3_color;
//@float min=0.0 max=10.0 value=4.0
uniform float stage3_offset;
//@float min=0.1 max=10.0 value=2.0
uniform float stage3_duration;
//@int min=0 max=2 value=0
uniform int stage3_shape;

// Stage 4 controls
//@rgb value=(1.0, 1.0, 0.2)
uniform vec3 stage4_color;
//@float min=0.0 max=10.0 value=6.0
uniform float stage4_offset;
//@float min=0.1 max=10.0 value=2.0
uniform float stage4_duration;
//@int min=0 max=2 value=0
uniform int stage4_shape;

// Stage 5 controls
//@rgb value=(1.0, 0.2, 1.0)
uniform vec3 stage5_color;
//@float min=0.0 max=10.0 value=8.0
uniform float stage5_offset;
//@float min=0.1 max=10.0 value=2.0
uniform float stage5_duration;
//@int min=0 max=2 value=0
uniform int stage5_shape;

// Get stage color based on index
vec3 get_stage_color(int idx) {
    if (idx == 1) return stage1_color;
    if (idx == 2) return stage2_color;
    if (idx == 3) return stage3_color;
    if (idx == 4) return stage4_color;
    return stage5_color;
}

// Get stage offset based on index
float get_stage_offset(int idx) {
    if (idx == 1) return stage1_offset;
    if (idx == 2) return stage2_offset;
    if (idx == 3) return stage3_offset;
    if (idx == 4) return stage4_offset;
    return stage5_offset;
}

// Get stage duration based on index
float get_stage_duration(int idx) {
    if (idx == 1) return stage1_duration;
    if (idx == 2) return stage2_duration;
    if (idx == 3) return stage3_duration;
    if (idx == 4) return stage4_duration;
    return stage5_duration;
}

// Get stage shape based on index
int get_stage_shape(int idx) {
    if (idx == 1) return stage1_shape;
    if (idx == 2) return stage2_shape;
    if (idx == 3) return stage3_shape;
    if (idx == 4) return stage4_shape;
    return stage5_shape;
}

// Calculate shape activation for a grid cell
float calculate_shape(int cell_x, int cell_y, int shape, vec2 grid_center) {
    vec2 cell_center = vec2(float(cell_x) + 0.5, float(cell_y) + 0.5);
    cell_center = cell_center / vec2(float(grid_x), float(grid_y));
    
    if (shape == 0) {
        // Solid: light up entire grid
        return 1.0;
    } else if (shape == 1) {
        // Circle: light up cells within a circle from center
        vec2 dist = cell_center - grid_center;
        float radius = 0.5; // Half of grid
        float dist_from_center = length(dist);
        return 1.0 - smoothstep(radius - 0.05, radius, dist_from_center);
    } else {
        // Fade: fade based on distance from center
        vec2 dist = cell_center - grid_center;
        float dist_from_center = length(dist);
        return 1.0 - smoothstep(0.0, 0.5, dist_from_center);
    }
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    
    // Calculate animation parameter
    float anim_time = iTime * sequence_speed;
    
    // Grid center
    vec2 grid_center = vec2(0.5, 0.5);
    
    // Determine which grid cell we're in
    vec2 cell_uv = uv * vec2(float(grid_x), float(grid_y));
    ivec2 cell_coord = ivec2(floor(cell_uv));
    cell_coord = clamp(cell_coord, ivec2(0), ivec2(grid_x - 1, grid_y - 1));
    
    // Find the active stage based on time
    vec3 final_color = vec3(0.0);
    float max_activation = 0.0;
    
    // Iterate through stages
    for (int i = 1; i <= 5; i++) {
        if (i > stage_count) break;
        
        float offset = get_stage_offset(i);
        float duration = get_stage_duration(i);
        int shape = get_stage_shape(i);
        vec3 stage_color = get_stage_color(i);
        
        float stage_time = anim_time - offset;
        if (stage_time >= 0.0 && stage_time < duration) {
            float shape_activation = calculate_shape(cell_coord.x, cell_coord.y, shape, grid_center);
            float fade_in = smoothstep(0.0, 0.1, stage_time);
            float fade_out = smoothstep(duration, duration - 0.1, stage_time);
            float stage_activation = shape_activation * fade_in * fade_out;
            if (stage_activation > max_activation) {
                max_activation = stage_activation;
                final_color = stage_color * stage_activation;
            }
        }
    }
    
    // Output
    fragColor = vec4(final_color, 1.0);
}
