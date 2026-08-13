//@settings dtype=float32 format=rgba
//@slider min=1.0 max=20.0 value=5.0
uniform float tile_size;
//@slider min=0.0 max=6.28318 value=0.0
uniform float rotation;
//@rgb
uniform vec3 color1;
//@rgb
uniform vec3 color2;
//@int min=1 max=5 value=1
uniform int pattern_type;

// ============================================================
// BasicPattern - Pattern generation
// ============================================================
// This shader demonstrates various procedural pattern generators
// that can be controlled with sliders and color pickers.
// ============================================================

uniform sampler2D in;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    float t = iTime * 0.2;
    
    // Tile the UV space
    vec2 tile = uv * tile_size;
    vec2 tileFrac = fract(tile);
    vec2 tileID = floor(tile);
    
    // Pattern 1: Checkerboard
    float pattern;
    if (pattern_type == 1) {
        pattern = mod(tileID.x + tileID.y, 2.0);
    }
    // Pattern 2: Stripes
    else if (pattern_type == 2) {
        float line = abs(sin(tileFrac.x * 3.14159 * 2.0));
        pattern = step(0.5, line);
    }
    // Pattern 3: Circles
    else if (pattern_type == 3) {
        float dist = length(tileFrac - 0.5);
        pattern = smoothstep(0.3, 0.25, dist) * smoothstep(0.1, 0.15, dist);
    }
    // Pattern 4: Crosshatch
    else if (pattern_type == 4) {
        pattern = step(0.4, abs(sin(tileFrac.x * 3.14159))) * 
                  step(0.4, abs(sin(tileFrac.y * 3.14159)));
    }
    // Pattern 5: Diamonds
    else {
        float d = abs(tileFrac.x - 0.5) + abs(tileFrac.y - 0.5);
        pattern = step(d, 0.5) * step(abs(tileFrac.x - tileFrac.y), 0.5);
    }
    
    // Apply rotation to tile coordinates
    if (rotation != 0.0) {
        vec2 centered = tileFrac - 0.5;
        float c = cos(rotation);
        float s = sin(rotation);
        tileFrac = vec2(
            centered.x * c - centered.y * s + 0.5,
            centered.x * s + centered.y * c + 0.5
        );
    }
    
    // Color blend based on pattern and time
    float timeMod = sin(t + tileID.x * 0.5 + tileID.y * 0.3) * 0.5 + 0.5;
    vec3 col = mix(color1, color2, timeMod * pattern);
    
    // Add subtle animation
    col += vec3(0.02) * sin(uv.x * 20.0 + iTime);
    
    // Blend with input
    vec4 inputColor = texture(in, uv);
    col = mix(inputColor.rgb, col, 0.7);
    
    fragColor = vec4(col, 1.0);
}
