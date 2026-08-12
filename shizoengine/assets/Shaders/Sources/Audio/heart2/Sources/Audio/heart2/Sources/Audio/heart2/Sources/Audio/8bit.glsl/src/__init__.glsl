//@settings dtype=float32 format=rgba
#define HASHSCALE3 vec3(.10319, .10307, .09731)
const float dots = 44.;
const float radius = .275;
const float brightness = 0.1;

uniform sampler2D input1;

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec2 hash21(float p)
{
	vec3 p3 = fract(vec3(p) * HASHSCALE3);
	p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.xx+p3.yz)*p3.zy);
}

vec3 noisepattern(vec2 uv)
{
	return texture(iChannel1, uv, 0.0).xyz;
}

vec2 rot(vec2 uv,float a){
	return vec2(uv.x*cos(a)-uv.y*sin(a),uv.y*cos(a)+uv.x*sin(a));
}

vec4 audioeclipse(vec2 fragCoord, float fadein)
{
	vec2 p=(fragCoord.xy-.5*iResolution.xy)/min(iResolution.x,iResolution.y);
    vec3 c=vec3(0,0,0.1);
    for(float i=0.;i<dots; i++){
		float vol =  texture(iChannel2, vec2(i/dots, 0.0)).x;
		float b = vol * brightness;
        float x = radius*cos(iTime*3.14*float(i)/dots);
        float y = radius*sin(iTime*3.14*float(i)/dots);
        vec2 o = vec2(x,y);
		vec3 dotCol = hsv2rgb(vec3((i + iTime*10.)/dots,fadein,1.0));
		c += b/(length(p-o))*dotCol;
    } 
	float dist = distance(p , vec2(0));  
    float shape = smoothstep(0.295, 0.3, dist);
	return vec4(c,shape);
}

vec3 innercircle(vec2 fragCoord, float fadein)
{
    vec2 p=(fragCoord.xy-.5*iResolution.xy)/min(iResolution.x,iResolution.y);
	float dist = distance(p , vec2(0));  
    float shading = pow( min(max(dist*2., 0.),1.) , (1.-texture(iChannel2 , vec2(0.5), 0.0).x)*10.);
    vec2 U = (fragCoord * 2. - iResolution.xy) / iResolution.y;
    float star = dot(U*2.-1.,vec2(sin(iTime),cos(iTime)));
    return hsv2rgb(vec3(star*0.05+iTime*0.2, (1.-shading*20.)*fadein, 1.+sin(star+iTime*0.9))) * shading * 90. ;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float fadein = clamp(iTime * .5, 0., 1.);
    float fadeinslower = clamp(iTime * .03, 0., 1.);    
    float fadein2 = round(clamp(iTime * 0.0295, 0., 1.));
    float soundin = clamp(texture(iChannel2 , vec2(.5), 0.0).x * 6. - 1., 0., 1.);
    float lifetime = iTime*0.2;
    float lifetimestep = ceil(lifetime);
    vec3 stars = vec3(0.);
    for (float i=0.; i<4.; i++) {  
        float star = 0.;
        vec2 random1 = hash21(i*333.33+lifetimestep) * 2. - 1.;
        vec2 random2 = hash21(i*999.99+lifetimestep) * 2. - 1.;
	    vec2 U = ( fragCoord + (random2 * vec2(iResolution.xy * fract(lifetime+random1.x)) ) - iResolution.xy * vec2(0.5,0.5) ) / iResolution.y ;
	    U = rot(U, lifetime + sin(iTime) * 0.3 + cos(iTime*.3) * 0.2);
        U = abs(U * mat2(1, 1, -1, 1)) * mat2(2, 0, 1, 1.7);
        vec2 timerandom = pow(hash21(lifetimestep+i),vec2(2.));
        star = (timerandom.x + 0.25) * 1. / max(U.x, U.y);
        star *= 1. - abs(fract(lifetime+random1.x) * 2. - 1.);
        vec3 color = hsv2rgb(vec3( random1.y*0.7+fract(lifetime), random1.x*0.25+0.75, 0.4 ));
        stars += star * color * fadeinslower;
    }
    vec4 ae = audioeclipse(fragCoord,fadein2);
    stars += ae.rgb;
    stars = mix(innercircle(fragCoord, fadein2),stars,max(1.-fadein2,ae.a));
    stars *= fadein;
    stars += texture(input1 , ((fragCoord - vec2(0.5)) * vec2(soundin*0.25+.5, -1.0) + vec2(0.5)) / iResolution.xy, 0.0).xyz * 0.2 * soundin;
    stars += texture(input1 , ((fragCoord - vec2(0.5)) * vec2(-1.0, soundin*0.25+.5) + vec2(0.5)) / iResolution.xy, 0.0).xyz * 0.1 * soundin;
	vec3 prevbuf = texture(input1 , fragCoord / iResolution.xy, 0.0).xyz;    
    fragColor.xyz = mix(stars, prevbuf, 0.9);
    fragColor.w = clamp(texture(iChannel2 , vec2(fragCoord.y / iResolution.xy), 0.0).x, 0., 1.); 
}
