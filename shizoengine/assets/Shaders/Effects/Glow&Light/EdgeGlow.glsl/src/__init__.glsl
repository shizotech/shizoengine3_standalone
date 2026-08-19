// ==== Custom Uniform Controls ====

//@float min=0.01 max=1.0 value=0.3
uniform float edge_threshold;

//@float min=0.0 max=2.0 value=0.5
uniform float glow_intensity;

//@rgb value=(1.0,1.0,1.0)
uniform vec3 glow_color;

//@rgb value=(1.0,1.0,1.0)
uniform vec3 edge_color;

//@float min=0.0 max=1.0 value=0.7
uniform float blend;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;

    // Sample surrounding pixels for edge detection
    float top = dot(texture2D(iChannel0, uv + vec2(0.0, texel.y)).rgb, vec3(0.2126, 0.7152, 0.0722));
    float bottom = dot(texture2D(iChannel0, uv + vec2(0.0, -texel.y)).rgb, vec3(0.2126, 0.7152, 0.0722));
    float left = dot(texture2D(iChannel0, uv + vec2(-texel.x, 0.0)).rgb, vec3(0.2126, 0.7152, 0.0722));
    float right = dot(texture2D(iChannel0, uv + vec2(texel.x, 0.0)).rgb, vec3(0.2126, 0.7152, 0.0722));

    // Sobel-like edge detection
    float edge_x = right - left;
    float edge_y = top - bottom;
    float edge = length(vec2(edge_x, edge_y));

    // Glow based on edges
    vec4 glow = vec4(0.0);
    for (float x = -3.0; x <= 3.0; x += 1.0) {
        for (float y = -3.0; y <= 3.0; y += 1.0) {
            vec2 offset = vec2(x, y) * texel;
            float sample_edge = length(vec2(
                dot(texture2D(iChannel0, uv + vec2(texel.x, 0.0)).rgb, vec3(0.2126, 0.7152, 0.0722)) -
                dot(texture2D(iChannel0, uv + vec2(-texel.x, 0.0)).rgb, vec3(0.2126, 0.7152, 0.0722)),
                dot(texture2D(iChannel0, uv + vec2(0.0, texel.y)).rgb, vec3(0.2126, 0.7152, 0.0722)) -
                dot(texture2D(iChannel0, uv + vec2(0.0, -texel.y)).rgb, vec3(0.2126, 0.7152, 0.0722))
            ));

            if (sample_edge > edge_threshold) {
                glow += vec4(glow_color, 1.0);
            }
        }
    }
    glow /= 49.0;

    // Combine original with edges and glow
    vec4 input = texture2D(iChannel0, uv);
    vec3 color = input.rgb;

    // Apply edge color
    color = mix(color, edge_color, smoothstep(edge_threshold, edge_threshold + 0.1, edge));

    // Add glow
    color += glow.rgb * glow_intensity * smoothstep(edge_threshold, edge_threshold + 0.2, edge);

    color = mix(input.rgb, color, blend);

    fragColor = vec4(color, input.a);
}