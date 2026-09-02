// Retro Scanlines Effect
// Shadertoy format

//@slider min=1.0 max=50.0 value=10.0
uniform float scanline_density;

//@slider min=0.0 max=1.0 value=0.3
uniform float scanline_opacity;

//@slider min=0.0 max=2.0 value=0.0
uniform float scanline_curvature;

//@slider min=0.0 max=1.0 value=0.0
uniform float scanline_flicker;

//@slider min=0.0 max=10.0 value=3.0
uniform float scanline_flicker_speed;

//@rgb value=(0.0,0.0,0.2)
uniform vec3 scanline_color_tint;

//@slider min=0.0 max=1.0 value=0.0
uniform float scanline_phosphor;

uniform sampler2D input;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float time = iTime;
    
    vec2 coord = uv;
    
    // Apply curvature (CRT monitor bulge)
    if (scanline_curvature > 0.0) {
        float d = length(coord - vec2(0.5));
        coord = mix(coord, vec2(0.5), scanline_curvature * d * d);
    }
    
    // Sample the input texture
    vec3 color = texture(input, coord).rgb;
    
    // Scanline effect - alternating dark bands
    float scanline_pattern = sin(coord.y * scanline_density * 3.14159265) * 0.5 + 0.5;
    scanline_pattern = pow(scanline_pattern, 1.0 + scanline_opacity * 2.0);
    
    // Dark scanlines (inverted pattern)
    float scanline_dark = 1.0 - scanline_pattern;
    scanline_dark = clamp(scanline_dark * scanline_opacity, 0.0, 1.0);
    
    color -= scanline_dark;
    
    // Apply color tint to scanlines
    color += scanline_color_tint * scanline_dark;
    
    // Phosphor effect - slight RGB shift simulating CRT phosphors
    if (scanline_phosphor > 0.0) {
        float shift = scanline_phosphor * 0.002;
        vec3 phosphor;
        phosphor.r = texture(input, coord + vec2(shift, 0.0)).r;
        phosphor.g = texture(input, coord).g;
        phosphor.b = texture(input, coord - vec2(shift, 0.0)).b;
        color = mix(color, phosphor, scanline_phosphor);
    }
    
    // Flicker effect - subtle brightness modulation
    if (scanline_flicker > 0.0) {
        float flicker = sin(time * scanline_flicker_speed * 2.0) * 0.5 + 0.5;
        flicker = mix(1.0, flicker, scanline_flicker);
        color *= flicker;
    }
    
    fragColor = vec4(color, 1.0);
}
