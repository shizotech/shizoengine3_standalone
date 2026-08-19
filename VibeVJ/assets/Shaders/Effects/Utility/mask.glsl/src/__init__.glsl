//@float min=0.01 max=100 value=1
uniform float mask_scale;
//@enum options=(MULTICOLOR,SINGLECOLOR)
uniform int mask_mode;

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{        
	
	vec2 uv = fragCoord.xy / iResolution.xy;
	
	vec4 c3 = texture( iChannel2, uv );
    vec4 c1 = texture( iChannel1, uv );
    vec4 c2 = texture( iChannel0, uv );
	
	c1 = clamp(c1,0.0,1.0);
    c2 = clamp(c2,0.0,1.0);
	// fragColor = vec4(pp, pp, pp, 1.0);
	if(mask_mode == 1)
		c3 = vec4(vec3(max(c3.z, max(c3.y, c3.x))), 1.0);
    fragColor = mix(c1, c2, clamp(c3*mask_scale,0.0,1.0) );
}
