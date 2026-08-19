//@settings dtype=float32 format=rgba

#define sat(a) clamp(a, 0., 1.)
#define PI acos(-1.)

mat2 r2d(float a) {
    float c = cos(a), s = sin(a); return mat2(c, -s, s, c);
}

float lenny(vec2 v)
{
    return abs(v.x)+abs(v.y);
}

vec3 rdrCirc(vec2 uv, float t)
{
    vec3 col = vec3(0.275,0.145,0.027)*1.5;
    vec2 ouv = uv;
    float rep = .03;
    float id = floor((uv.y+rep*.5)/rep);
    uv.y = mod(uv.y+rep*.5,rep)-rep*.5;
    uv.x += id;
    float cl = .1;
    float h = clamp(asin(sin(uv.x*5.)), -cl, cl)/cl;
    float line = abs(uv.y-h*0.01)-.001;
    vec3 rgb = mix(vec3(1.000,0.533,0.220), vec3(0.902,0.667,0.396), sat(sin(id)));
    rgb *= 1.-sat((abs(ouv.x+(fract(id*.1)-.5)+mod(t*.75+.5*id,4.)-2.)-.2)*4.);
    col += .8*rgb*(1.-sat(line*80.));
    return col;
}
vec3 rdrCircuit(vec2 uv)
{
    vec3 col = rdrCirc(uv, iTime);
    col += rdrCirc(uv+vec2(0.,.2), iTime*.7);
    col += .5*rdrCirc(2.*uv+vec2(0.,.1), iTime*.5);
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord-.5*iResolution.xy)/iResolution.xx;
    vec3 col = rdrCircuit(uv);
    fragColor = vec4(col,1.0);
}
