// Colorize Multiply Shader

//@float min=0.0 max=10.0 value=1.0
uniform float color_mult;

//@vec4 min=(0.0,0.0,0.0,0.0) max=(1.0,1.0,1.0,1.0) value=(1.0,1.0,1.0,1.0)
uniform vec4 colors;

void mainImage( out vec4 fragColor, in vec2 p )
{
    p /= iResolution.xy;

    fragColor = texture(iChannel0, p) * colors * color_mult;
}
