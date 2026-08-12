//@settings dtype=float32 format=rgba
#define HASHSCALE3 vec3(.10319, .10307, .09731)
#define SQUARERATIO 1
#define RIGHTANGLES 1

#define intro 12.5
#define outro 200.

const float bpm = 157. / 60. / 2.;

float getCirclesMode(float time){ 
   return 2.* fract(time * bpm * .125);
}

// track - Garbage by Martin Chapman

// hashes by dave hoshkins
float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{

    float circlesMode = getCirclesMode(iTime);
    vec2 quadrant = fragCoord.xy/iResolution.xy * 2.;
    float index = floor(quadrant.x) + floor(quadrant.y) * 2. + 1.;
    quadrant-=1.;
    
    //quadrant.x *= iResolution.x/iResolution.y; 
    quadrant = abs(quadrant);
    float xoff = (iResolution.x - iResolution.y) / iResolution.x; 
    //quadrant.x += (iResolution.x - iResolution.y) / iResolution.x * .5;
   
	vec2 uv = fragCoord.xy / iResolution.xy - .5;
	vec3 col = vec3(.9);
	vec4 p = texelFetch(iChannel0, ivec2(fragCoord.xy), 0);
	float d = p.r;
    float floorTime = floor(iTime * bpm );
    float mode = .75 + .25 * cos(.3* iTime + index); // try .5;
    
    float colorPhase = smoothstep(outro + 12., outro, iTime); // by time, but lets do it by mouse instead.
	colorPhase = smoothstep(0.95, 0.85, iMouse.x / iResolution.x);
    
    if(circlesMode < 1.){
    	d = 0.; // get rid of lines
    }
    fragColor.rgb = mix(vec3(1.4 , .5*abs(sin(iTime)), .76 * cos(iTime)), col, max(mode + d, 0.));
    
    // add circles to one quadrant
    if(circlesMode < 1. || mod(index + floorTime, 4.) < -.31 + iMouse.y/iResolution.y * 4.){
    	fragColor.rgb = mix(fragColor.rgb, fragColor.rgb *= vec3(2., 1. , 0.) * vec3(colorPhase), p.g);
        //fragColor.b += p.b * (1. + cos(iTime)); /// too long on pink. use this to change color per circle
    }
    // recolor the lines per quadrant
    fragColor.rgb = mix(vec3(1., index*.2, 1. - index*.2) * colorPhase, fragColor.rgb, smoothstep(-1.,.1, .2+d * (index)) );
	
    //fragColor.rgb = mix( fragColor.rgb *= vec3(2., 1. , 0.) * vec3(colorPhase),fragColor.rgb, smoothstep(-1.,.1, .2+d ));

    
    vec4 
		n = texelFetch(iChannel0, ivec2(fragCoord.xy)+ivec2(0,1) , 0),
		s = texelFetch(iChannel0, ivec2(fragCoord.xy)+ivec2(0,-1) , 0),
        e = texelFetch(iChannel0, ivec2(fragCoord.xy)+ivec2(1,0) , 0),
		w = texelFetch(iChannel0, ivec2(fragCoord.xy)+ivec2(-1,0) , 0);
    
    //fragColor.g += w.r; fragColor.b += e.r;
            
    vec3 norm = normalize(vec3(e.a-w.a, n.a-s.a, .0));
    vec3 normUps = normalize(vec3(e.a-w.a, n.a-s.a, .0) *.5 + .5);
    vec3 gradient = 1. - normUps;
    
    //fragColor.rg *= norm.xy; // show normal
    fragColor.rgb *= gradient + .5;
    
    vec3 crazy3 = vec3(cos(3.*iTime - index),sin(iTime + index),0.);
    vec3 ncol = fragColor.rgb + (vec3(1. * sin(iTime), -.2* cos(iTime), -.5)+ .09*hash12((uv)*1000.)) * vec3(clamp(0.,.1,dot(norm, crazy3)));
    
    fragColor.rgb = mix(fragColor.rgb, ncol , 1.5 );//* fract(iTime * bpm * .125 ));//* smoothstep(.85, .95, iMouse.x / iResolution.x));
    
    //float distL1 = distance(vec2(sin(iTime), cos(iTime)), (uv - .5)*3.);
    //fragColor *= (1.-distL1);
        
    float vig = length(uv);
    fragColor.rgb *= (1.-pow(vig, 3.));
	fragColor.a = 1.0;
    //fragColor *= fragColor;
    //fragColor *= 1.45;
    //fragColor *= 1. + .09*hash12((uv)*1000.); // add a grain to the backgroun
    
    //fragColor.rgb = vec3(1. + d); // show lines only
    
	
    #if SQUARERATIO
    if(quadrant.x > (iResolution.y/iResolution.x)) fragColor *= .5; // frame for instagram, square aspect ratio
	#endif


}
