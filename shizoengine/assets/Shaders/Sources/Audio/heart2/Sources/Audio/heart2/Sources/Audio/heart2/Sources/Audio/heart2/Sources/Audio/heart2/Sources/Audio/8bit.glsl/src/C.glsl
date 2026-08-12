uniform sampler2D B;

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    float warpA =  texture(B, vec2(uv.y)).w;
    vec2 warpuv = (uv - 0.5) *  ( pow( warpA * vec2(-1.,-0.025),vec2(4.)) + vec2(1.,1.)) +0.5;
    warpuv = mix(warpuv,uv, pow(2.*distance(0.5,uv.x),2.) );
    fragColor = texture(B,warpuv);
	fragColor.rgb *= .9 + smoothstep(0.,1.,fragColor.w) * 0.2;
}
