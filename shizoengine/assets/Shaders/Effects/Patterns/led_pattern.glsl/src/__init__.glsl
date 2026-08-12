

//@settings dtype=float32 format=rgba

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = fragCoord.xy / iResolution.y;
    float dt = sin(uv.x *20. + iTime);
    float circle = (cos(mod(uv.x * 32.0, 3.14) - 1.58) *0.5) *(sin(mod(uv.y * 32.0, 3.14)) *0.5) * (1.-dt);
	fragColor = vec4(12.0,4.0,2.0,1.0) * circle;
}

