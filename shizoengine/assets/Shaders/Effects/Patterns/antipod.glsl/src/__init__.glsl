//@settings dtype=float32 format=rgba
// Code by Flopine

// Thanks to wsmind, leon, XT95, lsdlive, lamogui, 
// Coyhot, Alkama,YX, NuSan, slerpy, wwrighter 
// BigWings, FabriceNeyret and Blackle for teaching me

// Thanks LJ for giving me the spark :3

// Thanks to the Cookie Collective, which build a cozy and safe environment for me 
// and other to sprout :)  
// https://twitter.com/CookieDemoparty


#define PI acos(-1.)
#define TAU (2.*PI)
#define hr vec2(1., sqrt(3.))

#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))
#define noise(u) textureLod(iChannel0, u, 0.).x

#define od(p,d) (dot(p,normalize(sign(p)))-d)
#define box(p,c) length(max(abs(p)-c, 0.))

#define speed 3.14159265359
#define palette(t,c,d) (vec3(.5)+vec3(.5)*cos(TAU*(c*t+d)))
#define anim(u,s) sin(length(atan(u.x, u.y)+iTime*speed*s)-length(u))

struct obj
{
    float d;
    vec3 col;
};


obj minobj(obj a, obj b)
{
    if (a.d<b.d) return a;
    else return b;
}

// from iq
// https://iquilezles.org/articles/distfunctions/
float hprism (vec3 p, vec2 h)
{
    const vec3 k = vec3(-0.8660254, 0.5, 0.57735);
    p = abs(p);
    p.xy -= 2.0*min(dot(k.xy, p.xy), 0.0)*k.xy;
    vec2 d = vec2(
       length(p.xy-vec2(clamp(p.x,-k.z*h.x,k.z*h.x), h.x))*sign(p.y-h.x),
       p.z-h.y );
    return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

vec4 hgrid (vec2 uv)
{
    vec2 ga=mod(uv,hr)-hr*.5, gb=mod(uv-hr*.5, hr)-hr*.5,
    guv=dot(ga,ga)<dot(gb,gb)?ga:gb,
    gid = uv-guv;
    
    return vec4(guv, gid);
}

obj SDF (vec3 p)
{
    p.yz *= rot(-atan(1./sqrt(2.)));
    p.xz *= rot(PI/4.);
    
    vec4 hg = hgrid(p.xz),
    hgo = hgrid(p.xz-hr.yx*.33);
    vec2 ohgoid = hgo.zw+.001;
    float size = mix(.05, .18, anim(ohgoid, -1.)); 
    float p1 = mix(box(vec3(hgo.x, p.y, hgo.y), vec3(size)), od(vec3(hgo.x, p.y, hgo.y), size), .5);
    
    obj o1 = obj(p1,  vec3(1.));
    
    vec2 hid = hg.zw,
    ohid = hid+.001,
    pxz = hg.xy;   
    float n = noise(hid*.24), 
    
    r=mix(.1, .3 ,anim(ohid, 1.)), h=.4,
    d = hprism(vec3(pxz, p.y), vec2(r, h)),
    ogd1 = abs(abs(abs(d)-.05)-.025)-.0025,
    ogd2 = abs((abs(d)-.05))-.015,    
    ogd = (n < .5) ? ogd1 : ogd2;
    d = max(abs(p.y)-.1, ogd);

    obj o2 = obj( d, palette(length(hid), vec3(.1),vec3(.7, .4, .25)) );
    
    return minobj(o1,o2); 
}

vec3 gn (vec3 p, float e)
{
    vec2 eps = vec2(e, 0.);
    return normalize(SDF(p).d-vec3(SDF(p-eps.xyy).d, SDF(p-eps.yxy).d, SDF(p-eps.yyx).d));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.*fragCoord-iResolution.xy)/iResolution.y;
    
    vec3 ro = vec3(uv*3., -20.), rd=vec3(0.,0.,1.),p=ro,
    col=vec3(0.01), l=normalize(vec3(.1, .5, -1.));
    
    bool hit=false; obj O;
    
    for (float i=0.; i<100.; i++)
    {
        O = SDF(p);
        if (O.d<.01)
        {
            hit = true; break;
        }
        p += O.d*rd*.5;
    }
    
    if (hit)
    {
        vec3 n = gn(p,1e-3);
        float li = max(dot(n,l), 0.);
        col = O.col*li;
    }
    
    fragColor = vec4(sqrt(col), 1.0);
}
