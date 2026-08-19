
// Raymarching sketch about magic.
// I've started with the three turning spells,
// then a broken chain and finally a storm trapped in a sphere.

// Leon 12 / 07 / 2017
// using lines of code of IQ, Mercury, LJ, Koltes, Duke

#define PI 3.14159
#define TAU PI*2.
#define t iTime

// number of ray
#define STEPS 30.

// distance minimum for volume collision
#define BIAS 0.001

// distance minimum 
#define DIST_MIN 0.01

// rotation matrix
mat2 rot (float a) { float c=cos(a),s=sin(a);return mat2(c,-s,s,c); }

// distance field funtions
float sdSphere (vec3 p, float r) { return length(p)-r; }
float sdCylinder (vec2 p, float r) { return length(p)-r; }
float sdTorus( vec3 p, vec2 s ) {
  vec2 q = vec2(length(p.xz)-s.x,p.y);
  return length(q)-s.y;
}
float sdBox( vec3 p, vec3 b ) {
  vec3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

// smooth minimum
float smin (float a, float b, float r) {
    float h = clamp(.5+.5*(b-a)/r,0.,1.);
    return mix(b,a,h)-r*h*(1.-h);
}

// dat one line random function 
float rand(vec2 co) { return fract(sin(dot(co*0.123,vec2(12.9898,78.233))) * 43758.5453); }

// polar domain repetition
vec3 moda (vec2 p, float count) {
    float an = TAU/count;
    float a = atan(p.y,p.x)+an/2.;
    float c = floor(a/an);
    a = mod(a,an)-an/2.;
    return vec3(vec2(cos(a),sin(a))*length(p),c);
}

// the rythm of animation
// change the 3. to have more or less spell
float getLocalWave (float x) { return sin(-t+x*3.); }

// displacement in world space of the animation
float getWorldWave (float x) { return 1.-.1*getLocalWave(x); }

// camera control
vec3 camera (vec3 p) {
    p.yz *= rot((PI*(iMouse.y/iResolution.y-.5)));
    p.xz *= rot((PI*(iMouse.x/iResolution.x-.5)));
    return p;
}
  
// position of chain
vec3 posChain (vec3 p, float count) {
    float za = atan(p.z,p.x);
    vec3 dir = normalize(p);
    
    // domain repetition
    vec3 m = moda(p.xz, count);
    p.xz = m.xy;
    float lw = getLocalWave(m.z/PI);
    p.x -= 1.-.1*lw;
    
    // the chain shape
    p.z *= 1.-clamp(.03/abs(p.z),0.,1.);
    
    // animation of breaking chain
    float r1 = lw*smoothstep(.1,.5,lw);
    float r2 = lw*smoothstep(.4,.6,lw);
    p += dir*mix(0., 0.3*sin(floor(za*3.)), r1);
    p += dir*mix(0., 0.8*sin(floor(za*60.)), r2);
    
    // rotate chain for animation smoothness
    float a = lw * .3;
    p.xy *= rot(a);
    p.xz *= rot(a);
    return p;
}

// distance function for spell
float mapSpell (vec3 p) {
    float scene = 1.;
    float a = atan(p.z,p.x);
    float l = length(p);
    float lw = getLocalWave(a);
    
    // warping space into cylinder
    p.z = l-1.+.1*lw;
    
    // torsade effect
    p.yz *= rot(t+a*2.);
    
    // long cube shape
    scene = min(scene, sdBox(p, vec3(10.,vec2(.25-.1*lw))));
    
    // long cylinder cutting the box (intersection difference)
    scene = max(scene, -sdCylinder(p.zy, .3-.2*lw));
    return scene;
}

// distance function for the chain
float mapChain (vec3 p) {
    float scene = 1.;
    
    // number of chain
    float count = 21.;
    
    // size of chain
    vec2 size = vec2(.1,.02);
    
    // first set of chains
    float torus = sdTorus(posChain(p,count).yxz,size);
    scene = smin(scene, torus,.1);
    
    // second set of chains
    p.xz *= rot(PI/count);
    scene = min(scene, sdTorus(posChain(p,count).xyz,size));
    return scene;
}

// position of core stuff
vec3 posCore (vec3 p, float count) {
    
    // polar domain repetition
    vec3 m = moda(p.xz, count);
    p.xz = m.xy;
    
    // linear domain repetition
    float c = .2;
    p.x = mod(p.x,c)-c/2.;
    return p;
}

// distance field for the core thing in the center
float mapCore (vec3 p) {
    float scene = 1.;
    
    // number of torus repeated
    float count = 10.;
    float a = p.x*2.;
    
    // displace space
    p.xz *= rot(p.y*6.);
    p.xz *= rot(t);
    p.xy *= rot(t*.5);
    p.yz *= rot(t*1.5);
    vec3 p1 = posCore(p, count);
    vec2 size = vec2(.1,.2);
    
    // tentacles torus shape
    scene = min(scene, sdTorus(p1.xzy*1.5,size));
    
    // sphere used for intersection difference with the toruses
    scene = max(-scene, sdSphere(p,.6));
    return scene;
}

//@slider min=-10 max=10 value=-1.5
uniform float eye_z;

void mainImage( out vec4 color, in vec2 coord )
{
    // raymarch camera
	vec2 uv = (coord.xy-.5*iResolution.xy)/iResolution.y;
    vec3 eye = camera(vec3(uv,eye_z));
    vec3 ray = camera(normalize(vec3(uv,1.)));
    vec3 pos = eye;
    
    // dithering
	vec2 dpos = ( coord.xy / iResolution.xy );
	vec2 seed = dpos + fract(iTime);
    
    float shade = 0.;
    for (float i = 0.; i < STEPS; ++i) {
        
        // distance from the different shapes
		float distSpell = min(mapSpell(pos), mapCore(pos));
		float distChain = mapChain(pos);
        float dist = min(distSpell, distChain);
        
        // hit volume
        if (dist < BIAS) {
            
            // add shade
            shade += 1.;
            
            // hit non transparent volume
            if (distChain < distSpell) {
                
                // set shade and stop iteration
                shade = STEPS-i-1.;
                break;
            }
        }
        
        // dithering
        dist=abs(dist)*(.8+0.2*rand(seed*vec2(i)));
        
        // minimum step
        dist = max(DIST_MIN,dist);
        
        // raymarch
        pos += ray*dist;
    }
    
    // color from the normalized steps
    color = vec4(shade/(STEPS-1.));
}
