// ==== Custom Uniform Controls ====

//@vec2 min=(0.01,0.01) max=(2.0,2.0) value=(0.1,0.1)
uniform vec2 grid_spacing;

//@float min=0.001 max=0.1 value=0.005
uniform float line_width;

//@rgb value=(1.0,1.0,1.0)
uniform vec3 grid_color;

//@rgb value=(0.0,0.0,0.0)
uniform vec3 bg_color;

//@float min=-180.0 max=180.0 value=0.0
uniform float angle;

//@float min=0.0 max=2.0 value=0.5
uniform float perspective;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;
    uv -= 0.5;

    // Apply perspective warping
    float persp = perspective * (1.0 - uv.y);
    vec2 grid_uv = uv;
    grid_uv.x += persp * sin(uv.y * 3.14159);

    // Apply rotation
    float angle_rad = radians(angle + iTime * 10.0);
    mat2 rot = mat2(cos(angle_rad), -sin(angle_rad), sin(angle_rad), cos(angle_rad));
    grid_uv = rot * grid_uv;

    // Calculate grid lines
    vec2 grid = abs(fract(grid_uv / grid_spacing) - 0.5) / grid_spacing;
    float line = max(grid.x, grid.y);
    float mask = 1.0 - smoothstep(line_width, line_width + 0.005, line);

    vec3 color = mix(bg_color, grid_color, mask);
    fragColor = vec4(color, 1.0);
}