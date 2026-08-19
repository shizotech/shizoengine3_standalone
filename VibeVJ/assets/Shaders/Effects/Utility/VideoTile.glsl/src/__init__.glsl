// ==== Custom Uniform Controls ====

//@int min=1 max=10 value=2
uniform int grid_x;

//@int min=1 max=10 value=2
uniform int grid_y;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Get the normalized screen coordinates (0 to 1)
    vec2 uv = fragCoord / iResolution.xy;

    // Aspect correction to keep uniform tiles
    vec2 aspect = iResolution.xy / min(iResolution.x, iResolution.y);

    // Adjust the UV coordinates based on the grid
    int gx = max(1, grid_x); // prevent divide-by-zero
    int gy = max(1, grid_y);

    // Tile size in UV space
    vec2 tileCount = vec2(float(gx), float(gy));
    vec2 tileUV = fract(uv * tileCount); // Wrap UVs into each tile

    // Fetch the color from the texture
    vec3 color = texture(iChannel0, tileUV).rgb;

    fragColor = vec4(color, 1.0);
}
