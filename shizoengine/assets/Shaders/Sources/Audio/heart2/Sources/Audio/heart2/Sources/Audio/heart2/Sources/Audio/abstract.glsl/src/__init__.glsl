//@settings dtype=float32 format=rgba
#define HASHSCALE3 vec3(.10319, .10307, .09731)
#define SQUARERATIO 1
#define RIGHTANGLES 1

const float bpm = 157. / 60. / 2.;

float getCirclesMode(float time){ 
   return 2.* fract(time * bpm * .125);
}

uniform float lineWidth = 0.011;

// hashes by dave hoshkins
float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
vec2 hash23(vec3 p3)
{
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}

float ln (vec2 p, vec2 a, vec2 b) {
    return length(p-a-(b-a)*clamp(dot(p-a,b-a)/dot(b-a,b-a),0.,1.));
}

float lnd (vec2 p, vec2 a, vec2 b) {
    vec2 v = p-a-(b-a)*clamp(dot(p-a,b-a)/dot(b-a,b-a),0.,1.);
    if(v.x * v.y > 0.) return 1.;
    else return 0.;
}

float circle(vec2 p, vec2 c, vec2 center){
    return 1.-smoothstep(0., .01, abs(length(p - center) - length(c - center)));
}

float interiorCircle(vec2 p, vec2 c, vec2 center, float fuz){
    float r = length(c - center);
    return smoothstep(0., -r * fuz, length(p - center) - r);
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
 
    float circlesMode = getCirclesMode(iTime);
    vec2 quadrant = fragCoord.xy/iResolution.xy * 2.;
    float index = floor(quadrant.x) + floor(quadrant.y) * 2. + 1.;
    quadrant -= 1.;
    quadrant.x *= iResolution.x/iResolution.y;
    
	vec2 uv = fragCoord.xy / iResolution.yy; //
    
    uv = abs(quadrant);
    uv.x += .3; // cent
    
    vec2 center = vec2(.5/iResolution.y*iResolution.x, .5);
    
	//float wave = texelFetch( iChannel0, ivec2(tx,1), 0 ).x;
	
	vec3 col = vec3(0.) ;
    float d = 0.;
    float h = 0.;
    float c = 0.;
    vec2 pt = center;
    #if SQUARERATIO
    pt = vec2(.5);
    #endif
    
    float fft  = texelFetch( iChannel0, ivec2(50. * index,0), 0 ).x; 
    float time = floor(iTime * bpm );// +floor(fft * 3.);
    float ftime = fract(iTime * bpm + index*.2 );
    
    vec2 prev = pt - (hash23(vec3(time, 1000.*index, time)) -.5) * fft*.2;
    
    prev.x *= iResolution.x/iResolution.y;
    vec2 dir = hash23(vec3(0.*100., time, 1000.*index)) -.5;
    prev += dir * ftime * 1. *cos(ftime);
    vec2 orig = prev;
    
    float i = 0.;
    for(i; i < 4.; ++i){
    
        vec2 curr = .5 - (hash23(vec3(time * index, 1000.*index, i)) -.5)*2. * fft * .3;
        
        #if RIGHTANGLES
        if(mod(i, 2.) == 0.){ // force right angles
            curr.y = prev.y;
            curr.x *= iResolution.x/iResolution.y;
        }
        else curr.x = prev.x;
        #else
        
        curr.x *= iResolution.x/iResolution.y;
        #endif
        
        vec2 dir = hash23(vec3(i*100. * index, index*1000., time)) -.5;
        
        vec2 choose = vec2(mod(index, 2.), mod(i, 2.));
        curr += dir * choose * ftime * cos(ftime);
        
        vec2 toCenter = center-curr;
        float lenToCenter = length(toCenter);
        curr.x +=  1. * toCenter.x * lenToCenter*lenToCenter; // prevent random points from leaving the 
        
        float ld = ln(uv, prev, curr);
        d -= 1. - smoothstep(0., lineWidth, ld);
        h +=  clamp(0.,1.,pow(1.-ld,2.));
        
        float cdist = circle(uv, curr, prev);
        if(circlesMode >= 1.)
        cdist = interiorCircle(uv, orig, prev, (1.)/4. + .001);
        c+= cdist;
        //h += interiorCircle(uv, curr, prev, 4.); 
        col.b += cdist * i;
        prev = curr;
        
    }
    
    // reconnect to original pt
    float ld = ln(uv, prev, orig);
    d -= 1. - smoothstep(0., lineWidth, ld);
    h +=  clamp(0.,1.,pow(1.-ld,2.));
    float cdist = interiorCircle(uv, orig, prev, (1.)/4. + .001);
    c+= cdist;
    col.b += cdist * i;
	col.r = d;
    col.g = c;
    
    
	fragColor = vec4(col,h);
}
