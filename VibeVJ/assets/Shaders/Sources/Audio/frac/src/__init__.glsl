//@settings dtype=float32 format=rgba

#define PI 3.141592654
vec3 pow3(vec3 a, float b) {
    return vec3(pow(a.x, b),pow(a.y, b),pow(a.z, b));}
float Hash21(vec2 p)
{
    vec3 a = fract(p.xyx*vec3(123.34, 234.34, 345.65));
    a += dot(a, a+34.45);
    return fract(a.y*a.z*a.x);
}
vec2 Hash22(vec2 p)
{
    vec2 a = fract(p.xy*vec2(13.34, 24.34));
    a += dot(a, a+34.45);
    vec2 b = fract(p.xy*vec2(78.86, 134.21));
    b += dot(b, b+113.45);
    return vec2(fract(a.x*a.y), fract(b.x*b.y));
}
float Dist(vec2 a, vec2 b)
{
    return sqrt(pow(a.x-b.x,2.) + pow(a.y-b.y,2.));
}
vec3 lum(vec3 col)
{
    float gray = 0.2989 * col.x + 0.5870 * col.y + 0.1140 * col.z;
    return vec3(gray);
}
float backstarsf(vec2 UV, float mult)
{
    float backstars = 0.;
    vec2 backstarsuv = UV;
    backstarsuv.y *= -1.;
    backstarsuv *= mult;
    vec2 gv = fract(backstarsuv) - 0.5 ;
    vec2 id = floor(backstarsuv);
    vec2 hash = Hash22(id);
    vec2 circlepos = hash;
    float circle = Dist(vec2(gv),circlepos);
    float circler = 0.05;
    float star;
    if(circle < circler)
    {
        star = smoothstep(circler,circler - 0.05, circle);
        backstars += star;
    }
    return backstars;
}
mat2 Rot(float a) {
    float s=sin(a), c=cos(a);
    return mat2(c, -s, s, c);
}
vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord-0.5*iResolution.xy)/iResolution.y;
    uv *= 1.4;
    
    vec2 uv_orig = uv;
    vec2 mou = (iMouse.xy-0.5*iResolution.xy)/iResolution.y;
    
    float angmul = PI;
    for(int i = 0; i < 3; i++)
    {
        uv = abs(uv);
        angmul *= 0.25;
        uv *= Rot(angmul+mou.y*4.);
    }
    
    float click = iMouse.z > 0.? 1.:0.;
    uv = mix(uv_orig, uv, click);

    float time = iTime*(1.-0.*click) + click*mou.x*15.;
    float soundWave = texture(iChannel2, vec2(0.,0.)).x;
    
    float a = uv.x;
    float b = uv.y;
    float ca;
    float cb;
    float golden = 1.6180339887;

    ca = -0.74 + 0.0019*sin(time*0.951) ;
    cb = 0.006 + 0.105*sin(time*0.448*0.2 + soundWave*0.02) + 0.005*cos(time*0.4);
    
    float aa;
    float bb;

    float n = 0.;
    float maxiter = 100.;
    float m= 0.;
    float m2 = 0.;
    float r = 50.;
    float r2 = r*r;

    float pa;
    float pb;
    vec2 z;
    vec2 pz;
    float leavesSpeed = 0.;
    while(n < maxiter && m==0.)
    {
        aa = a*a - b*b;
        bb = 2.*a*b;
        pa = a;
        pb = b;
        pz = vec2(pa*cos(leavesSpeed*0.5) - pb*sin(leavesSpeed*0.5),pa*sin(leavesSpeed*0.5) + pb*cos(leavesSpeed*0.5));
        a = aa + ca;
        b = bb + cb;
        z = vec2(a,b);

        if(sqrt(a*a + b*b) > r)
        {
            m = 1.;
        }
        if(sqrt(a*a + b*b) > r2)
        {
        }
        else
        {
            n++;
        }
    }
    
    float dist = sqrt(a*a + b*b);
    float fraciter = (dist - r) / (r2 - r);
    fraciter = log2(log(dist) / log(r)) ;
    n -= fraciter;
    
    vec3 leavesCol=vec3(0.5 + 0.5*sin(n*1. + 0.751*time + soundWave*0.4),
                 0.0,
                 0.5 + 0.5*cos(n*1. + 0.384*time + soundWave*0.4));
    
    float angle = mix(atan(z.x, z.y), atan(z.x, pz.y), 1. );
    
    float rotspeed = sin(time*0.4);
    vec2 uvrot = uv;
    uvrot *= Rot(rotspeed);
    float backstars1 = backstarsf(uvrot + 0.1*time + 123., 50.)*1.;
    float backstars2 = backstarsf(uvrot + 0.12*time + 321., 20.)*1.;
    float backstars3 = backstarsf(uvrot + 0.14*time + 12., 10.)*1.;
    float backstars4 = backstarsf(uvrot + 0.16*time + 233., 7.)*1.;
    float backstars = backstars1 + backstars2 + backstars3 + backstars4;
    
    vec2 rs2,rs0,rss;
    vec2 uv_temp = uv;
    uv = uvrot;
    uv-=vec2(0.,0.);
    rs0.x = atan(uv.x, uv.y)/3.1416*2.;
    rs0.y = .05/(length (uv));
    rss = vec2(rs0.x,rs0.y + time*0.1 + soundWave*0.02);
    rss *= mat2x2(.7,.7,-.7,.7);
    vec3 noise = texture(iChannel1, rss/5.).xyz - 0.7;
    rss = abs(fract(rss*8.)-.5);
    vec3 dots = vec3(0.);
    dots = vec3( clamp( 0.06/length(rss), 0., 1.) ) * lum(noise);
    dots += dots*noise*0.7;

    
    rss = vec2 (rs0.x*0.7,rs0.y*.4 + time*0.05);
    rss *= mat2x2(.3,.3,-.3,.3);
    noise = texture(iChannel1, rss/10.).xyz - 0.7;
    rss = abs(fract(rss*8.)-.5);
    vec3 dots2 = clamp( 0.04/length(rss), 0., 1.)  * lum(noise);
    dots2 += dots2*noise*0.7;
    
    dots = dots*13. + dots2*20.;
    
    vec3 col;
    if(m == 1.)
    {
        col = leavesCol;
        float q = smoothstep(1.4, 0.,fraciter);
        col *= q;
        float lln = 4.;
        float lloff = 0.6;
        float t = 0.5 + 0.5*sin(n*1. + lloff + 1.*angle + 0.751*time + soundWave*0.4);
        vec3 a1 = vec3(0.5, 0.5, 0.5)*0.4;
        vec3 b1 = vec3(0.5, 0.5, 0.5);
        vec3 c1 = vec3(1., 1., 1.)*0.77;
        vec3 d1 = vec3(0., 0.1, 0.2);
        vec3 a2 = vec3(0.5, 0.5, 0.5)*0.3;
        vec3 b2 = vec3(0.5, 0.5, 0.5);
        vec3 c2 = vec3(1., 1., 1.);
        vec3 d2 = vec3(1., 1.0, 0.9);
        float mixTime = 0.;
        vec3 a = mix(a1, a2, mixTime);
        vec3 b = mix(b1, b2, mixTime);
        vec3 c = mix(c1, c2, mixTime);
        vec3 d = mix(d1, d2, mixTime);
        col.x *= 0.5 + 0.5*sin(angle*lln + leavesSpeed*lln + lloff + n*1. + 0.751*time + soundWave*0.4);
        col.z *= 0.5 + 0.5*cos(angle*lln + leavesSpeed*lln + lloff + n*1. + 0.384*time + soundWave*0.4);
        col *= 0.8;
    }
    else if(m2 == 1.)
    {
        col = vec3(0., 0., 0.);
    }
    else
    {
        col = vec3(0);
        vec2 sunpos = vec2(0.);
        float circle = Dist(uv,sunpos);
        float sunr = 0.18;

        if(circle < sunr)
        {
            vec3 sun = 5.*texture(iChannel0, (uv + 0.5 + time*.01)).xyz * vec3(1.,0.6,0.4);
            sun *= smoothstep(sunr,sunr-0.0645, circle);
            col += sun*sun*sun*0.7;
        }
        
        col = clamp(col, 0.,1.);
        
        float circler = 2.;
        if(circle < circler)
        {
            float dist = Dist(uv, vec2(0.));
            vec3 sun = vec3(0.5 + 0.5*cos(time*0.771 + dist*10.),0.1, 0.5 + 0.5*sin(time*0.471 + dist*10.));
            sun *= smoothstep(circler,circler-0.045, circle);
            dots += 0.5*sun;
        }
        col += clamp(dots, 0., 1.);
        col += 0.5*vec3(backstars);
    }
    
    fragColor = vec4(col,1.0);
}
