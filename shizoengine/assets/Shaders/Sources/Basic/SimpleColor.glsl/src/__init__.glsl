// ==== Custom Uniform Controls ====

//@rgba value=(1,0,0,1)
uniform vec4 color;

//@slider value=1
uniform float brightness;

//@slider value=0
uniform float hue_rotate;


vec4 shiftHue(in vec3 col, in float Shift)
{
    vec3 P = vec3(0.55735) * dot(vec3(0.55735), col);
    vec3 U = col - P;
    vec3 V = cross(vec3(0.55735), U);    
    col = U * cos(Shift * 6.2832) + V * sin(Shift * 6.2832) + P;
    return vec4(col, 1.0);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    fragColor = color * brightness;
	fragColor = shiftHue(fragColor.rgb, hue_rotate);
}
