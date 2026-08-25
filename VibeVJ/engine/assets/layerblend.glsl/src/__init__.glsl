
//@enum options=(No Blend, Add, Add Mask, Mix, Multiply, MultiplyInput, Chroma R, Chroma G, Chroma B)
uniform int BLEND;

//@pushbutton
uniform int FLIP_Y;

//@pushbutton
uniform int NO_ALPHA;

uniform float MIX;

uniform float MASTER;

uniform float TRANSITION;


void mainImage( out vec4 fragColor, in vec2 p )
{
    vec2 uv = p / iResolution.xy;
	
	if(FLIP_Y == 1)
	{
		uv.y = 1.0 - uv.y;
	}
	
	vec4 c1 = texture( iChannel1, uv );
	vec4 c2 = texture( iChannel0, uv );
	vec4 c3 = texture( iChannel2, uv );
   
	c2 = (1.0 - TRANSITION) * c2 + c3 * TRANSITION;
	
	if(BLEND == 0) //No Blend
		fragColor = c2;
	else if(BLEND == 1) //Add
	{
		fragColor = c1 + c2 * MIX;
	}
	if(BLEND == 2) //ADD MASK
	{
		c1 = clamp(c1,0.0,1.0);
		c2 = clamp(c2*MIX,0.0,1.0);
		
		float mix_alpha = max(c2[0], max(c2[1], c2[2]));
		
		vec4 c3 = mix(c1, c2, mix_alpha);
		fragColor = mix(c1, c3, MIX);
	}
	else if(BLEND == 3) //MIX
	{
		fragColor = mix(c1, c2, MIX);
	}
	else if(BLEND == 4) //Mult
	{
		fragColor = mix(c2, c1 * c2, MIX);
	}
	else if(BLEND == 5) //Mult
	{
		fragColor = mix(c1, c1 * c2, MIX);
	}
	else if(BLEND >= 6 && BLEND <= 8) // CHROMA R/G/B
	{
		float threshold = 0.4;  // Adjust this value for tighter keying
		float sensitivity = 0.2;

		float chromaValue;
		if(BLEND == 4) chromaValue = c2.r; // RED
		if(BLEND == 5) chromaValue = c2.g; // GREEN
		if(BLEND == 6) chromaValue = c2.b; // BLUE

		// Find the max of the non-chroma channels
		float otherMax;
		if(BLEND == 4) otherMax = max(c2.g, c2.b);
		if(BLEND == 5) otherMax = max(c2.r, c2.b);
		if(BLEND == 6) otherMax = max(c2.r, c2.g);

		// Determine mask where chroma color is significantly dominant
		float alpha = smoothstep(threshold, threshold + sensitivity, chromaValue - otherMax);

		// Use alpha to blend foreground (c2) over background (c1)
		vec4 blended = mix(c1, c2, 1.0 - alpha);
		fragColor = mix(c1, blended, MIX);
	}
	
	if(NO_ALPHA == 1)
		fragColor.a = 1.0;
		
	fragColor.rgb = fragColor.rgb * MASTER;
}
