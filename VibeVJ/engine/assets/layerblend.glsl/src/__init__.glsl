
//@enum options=(No Blend, Add, Add Mask, Mix, Multiply, MultiplyInput, Chroma R, Chroma G, Chroma B)
uniform int BLEND;

//@pushbutton
uniform int FLIP_Y;

//@pushbutton
uniform int NO_ALPHA;

uniform float MIX;

uniform float MASTER;

uniform float TRANSITION;

//Set by the Clipview (link_shaders): 1 while no clip runs on this layer. The layer then passes the layers below
//(iChannel1) through unchanged, whatever the blend mode, instead of laying an empty picture over them; with No Blend
//an empty Layer 1 made the whole output black (#574). A clip fading in on an empty layer fades from that picture.
uniform int LAYER_EMPTY;

//The layer over the layers below: c1 the layers below, c2 the clip of this layer
vec4 blend_layer(vec4 c1, vec4 c2)
{
	vec4 result = c2;

	if(BLEND == 0) //No Blend
		result = c2;
	else if(BLEND == 1) //Add
	{
		result = c1 + c2 * MIX;
	}
	if(BLEND == 2) //ADD MASK
	{
		vec4 a = clamp(c1,0.0,1.0);
		vec4 b = clamp(c2*MIX,0.0,1.0);

		float mix_alpha = max(b[0], max(b[1], b[2]));

		vec4 masked = mix(a, b, mix_alpha);
		result = mix(a, masked, MIX);
	}
	else if(BLEND == 3) //MIX
	{
		result = mix(c1, c2, MIX);
	}
	else if(BLEND == 4) //Mult
	{
		result = mix(c2, c1 * c2, MIX);
	}
	else if(BLEND == 5) //Mult
	{
		result = mix(c1, c1 * c2, MIX);
	}
	else if(BLEND >= 6 && BLEND <= 8) // CHROMA R/G/B
	{
		float threshold = 0.4;  // Adjust this value for tighter keying
		float sensitivity = 0.2;

		float chromaValue;
		if(BLEND == 6) chromaValue = c2.r; // RED
		if(BLEND == 7) chromaValue = c2.g; // GREEN
		if(BLEND == 8) chromaValue = c2.b; // BLUE

		// Find the max of the non-chroma channels
		float otherMax;
		if(BLEND == 6) otherMax = max(c2.g, c2.b);
		if(BLEND == 7) otherMax = max(c2.r, c2.b);
		if(BLEND == 8) otherMax = max(c2.r, c2.g);

		// Determine mask where chroma color is significantly dominant
		float alpha = smoothstep(threshold, threshold + sensitivity, chromaValue - otherMax);

		// Use alpha to blend foreground (c2) over background (c1)
		vec4 blended = mix(c1, c2, 1.0 - alpha);
		result = mix(c1, blended, MIX);
	}

	if(NO_ALPHA == 1)
		result.a = 1.0;

	result.rgb = result.rgb * MASTER;
	return result;
}

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

	if(LAYER_EMPTY == 1)
	{
		//No clip runs: the layers below as they are. A clip fading in (iChannel2) takes over from them
		fragColor = mix(c1, blend_layer(c1, c3), TRANSITION);
		return;
	}

	c2 = (1.0 - TRANSITION) * c2 + c3 * TRANSITION;

	fragColor = blend_layer(c1, c2);
}
