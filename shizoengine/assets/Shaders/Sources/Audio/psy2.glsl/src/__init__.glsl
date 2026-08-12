//@settings dtype=float32 format=rgba

#include shared_utils.glsl

float _seed;

float rand()
{
    _seed++;
    return hash11(_seed);
}

#define FFT(a) ((texture(iChannel2, vec2(a,0)).x+.05)*10.)

vec2 map(vec3 p)
{
    vec2 acc = vec2(10000.,-1.);
    
    vec3 op = p;
    vec3 rep = vec3(1.);
    vec3 id = floor((p+rep*.5)/rep);
    p = mod(p+rep*.5,rep)-rep*.5;
    p.xz *= r2d(id.y+iTime);
    p.xy *= r2d(sin(id.z)+iTime*.3);
    vec3 sz = FFT(length(id))*rep*.3 * (sin((id.x)*length(id)+iTime)*.5+.5);
    float shape = mix(_cucube(p, sz, vec3(.02)), length(p)-length(sz), sin(iTime)*.5-.5);
    shape = max(shape, -(length(op)-5.));
    acc = _min(acc, vec2(shape, 0.));
    
    return acc;
}

vec3 getNorm(vec3 p, float d)
{
    vec2 e = vec2(0.001, 0.);
    return normalize(vec3(d)-vec3(map(p-e.xyy).x, map(p-e.yxy).x, map(p-e.yyx).x));
}
vec3 getCol(vec3 p, vec3 n)
{
    vec3 col = n*.5+.5;
    col.xy *= r2d(p.z*5.+iTime);
    col.yz *= r2d(sin(p.y*5.)-iTime);
    col = abs(col);
    return n*.5+.5;
}
vec3 accCol;
vec3 trace(vec3 ro, vec3 rd, int steps)
{
    accCol = vec3(0.);
    vec3 p = ro;
    for (int i = 0; i < steps && distance(p, ro) < 10.; ++i)
    {
        vec2 res = map(p);
        if (res.x < 0.001)
            return vec3(res.x, distance(p, ro), res.y);
        p+=rd*res.x*.5;
        rd = normalize(rd-.01*normalize(p));
        accCol += getCol(p, normalize(p))*(1.-sat(res.x/.52))*.005;
    }
    return vec3(-1.);
}

vec3 rdr(vec2 uv)
{
    vec3 col = vec3(0.);
    
    float t= sin(iTime*.25);
    float d = 5.+3.*sin(iTime*.33);
    vec3 ro = vec3(sin(t)*d,-5.*sin(t*.25)*d,cos(t)*d);
    vec3 ta = vec3(0.,0.,0.);
    vec3 rd = normalize(ta-ro);
    
    rd = getCam(rd, uv);
    vec3 res = trace(ro, rd, 128);
    if (res.y > 0.)
    {
        vec3 p = ro+rd*res.y;
        vec3 n = getNorm(p, res.x);
        col = getCol(p, n);
    }
    col += accCol;
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord-.5*iResolution.xy)/iResolution.xx;
    _seed = iTime+texture(iChannel0, uv).x;
    vec3 col = rdr(uv);
    
    vec2 off = vec2(1., -1.)/(iResolution.x*1.5);

    if (false)// Not so cheap antialiasing
    {
        vec3 acc = col;
        acc += rdr(uv+off.xx);
        acc += rdr(uv+off.xy);
        acc += rdr(uv+off.yy);
        acc += rdr(uv+off.yx);
        col = acc/5.;
        
    }
    col *= 2.5/(col+1.);
    col = mix(col, texture(iChannel1, fragCoord/iResolution.xy).xyz, .2);
    col = sat(col);
    fragColor = vec4(col,1.0);
}
