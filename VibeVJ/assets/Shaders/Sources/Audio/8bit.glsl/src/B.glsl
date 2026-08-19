uniform sampler2D A;

vec3 ditherpattern(vec2 uv)
{
    vec3 d = texture(A, uv, 0.0).xyz;
    d.x = fract(iTime + d.x);
    d.y = fract(iTime + d.y + .33);
    d.z = fract(iTime + d.z + .66);
	return d;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = fragCoord.xy / iResolution.xy;
    uv *=  1.0 - uv.yx;
    float vig = uv.x*uv.y * 1.0;
    vig = pow(vig, 0.15);
    fragColor = texture( A , fragCoord / iResolution.xy , 0.0) * vec4(vec3(10.),1.);
    fragColor.rgb *= vec3(vig);     
	fragColor.rgb *= sin(iTime*1.)*0.1 + 1.;    
    fragColor.rgb = ceil(fragColor.rgb * vec3(2.) + ditherpattern(fragCoord/iResolution.xy) * vec3(8.)) / vec3(10.);    
}
