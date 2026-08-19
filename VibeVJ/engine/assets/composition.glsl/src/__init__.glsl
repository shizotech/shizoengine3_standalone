
//@pushbutton displayname="No Alpha"
uniform int no_alpha;

void mainImage( out vec4 fragColor, in vec2 p )
{
    p /= iResolution.xy;

    fragColor = texture(iChannel0, p);
	
	if(no_alpha == 1)
		fragColor.a = 1.0;
}
