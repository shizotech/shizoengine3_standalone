// ==== Custom Uniform Controls ====

//@slider
uniform float value;

//@int min=0 max=1 value=0
uniform int flip_y;

//@enum options=(Mix, Add, Mult)
uniform int mix_type;

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{        
	
	vec2 uv = fragCoord.xy / iResolution.xy;
	
	if(flip_y == 1)
	{
		uv.y = 1.0 - uv.y;
	}
	
    vec4 c2 = texture( iChannel1, uv );
    vec4 c1 = texture( iChannel0, uv );
	
	c1 = clamp(c1,0.0,1.0);
    c2 = clamp(c2,0.0,1.0);
    // fragColor = vec4(pp, pp, pp, 1.0);
	if(mix_type == 0)
		fragColor = mix(c1, c2, value );
	else if(mix_type == 1)
		fragColor = c1 + c2;
	else if(mix_type == 2)
		fragColor = c1 * c2;
}
