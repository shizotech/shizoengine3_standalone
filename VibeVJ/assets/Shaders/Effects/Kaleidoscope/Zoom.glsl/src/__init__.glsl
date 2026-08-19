// ==== Custom Uniform Controls ====

//@float min=0.01 max=3.0 value=0.5
uniform float zoom_speed;

//@float min=0.0 max=2.0 value=0.5
uniform float zoom_amount;

//@vec2 min=(-0.5,-0.5) max=(1.5,1.5) value=(0.5,0.5)
uniform vec2 zoom_center;

//@float min=0.1 max=10.0 value=2.0
uniform float zoom_smooth;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    float time = iTime * zoom_speed;
    float zoom = 1.0 + sin(time) * zoom_amount;

    // Zoom towards center
    vec2 center = zoom_center;
    vec2 delta = uv - center;
    vec2 zoomed_uv = center + delta / zoom;

    // Add warp effect
    float dist = length(delta);
    float warp = sin(dist * 10.0 - time * 3.0) * (1.0 - zoom) * 0.02;
    zoomed_uv += normalize(delta + 0.001) * warp;

    fragColor = texture2D(iChannel0, zoomed_uv);

    if (fragColor.a == 0.0)
    {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
}