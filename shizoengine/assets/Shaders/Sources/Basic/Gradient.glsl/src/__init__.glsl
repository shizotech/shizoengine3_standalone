// ==== Custom Uniform Controls ====

//@vec2 min=(-1.0,-1.0) max=(1.0,1.0) value=(0.5,0.5)
uniform vec2 gradient_direction;

//@rgb value=(1.0,0.0,0.0)
uniform vec3 color1;

//@rgb value=(0.0,1.0,0.0)
uniform vec3 color2;

//@rgb value=(0.0,0.0,1.0)
uniform vec3 color3;

//@float min=0.01 max=3.0 value=0.5
uniform float speed;

//@enum options=(Linear, Radial, Diagonal)
uniform int pattern;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;

    float time = iTime * speed;
    float t = fract(time * 0.1);

    float dist;

    if (pattern == 0)
    {
        // Linear gradient
        dist = dot(uv - 0.5, normalize(gradient_direction + 0.001)) * 2.0;
        dist += time * 0.2;
    }
    else if (pattern == 1)
    {
        // Radial gradient
        dist = length(uv - 0.5);
        dist -= time * 0.1;
    }
    else if (pattern == 2)
    {
        // Diagonal gradient
        dist = (uv.x + uv.y) * 0.5;
        dist += time * 0.15;
    }

    dist = fract(dist);

    // Three-color gradient
    vec3 color;
    if (dist < 0.5)
    {
        color = mix(color1, color2, dist * 2.0);
    }
    else
    {
        color = mix(color2, color3, (dist - 0.5) * 2.0);
    }

    fragColor = vec4(color, 1.0);
}