//@settings dtype=float32 format=rgba
const float PI = 3.1415926535897932384626433832795;
const float PI2 = 6.283185307179586476925286766559;
const float PI05 = 1.5707963267948966192313216916398;
const float PI025 = 0.78539816339744830961566084581988;

vec2 rotate(vec2 v, float a)
{
    return vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a));
}


float dir(vec2 a, vec2 b, vec2 c)
{
	return (a.x - c.x) * (b.y - c.y) - (b.x - c.x) * (a.y - c.y);
}

bool insideTri(vec2 p, vec2 a, vec2 b, vec2 c)
{
	bool b1 = dir(p, a, b) < 0.0;
	bool b2 = dir(p, b, c) < 0.0;
	bool b3 = dir(p, c, a) < 0.0;
  	return ((b1 == b2) && (b2 == b3));
}

bool insideQuad(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d)
{
	bool b1 = dir(p, a, b) < 0.0;
	bool b2 = dir(p, b, c) < 0.0;
	bool b3 = dir(p, c, d) < 0.0;
	bool b4 = dir(p, d, a) < 0.0;
  	return ((b1 == b2) && (b2 == b3) && (b3 == b4));
}

bool insideTriStar(vec2 p, float s, float r)
{
    float d = s * 0.70710678118654752440084436210485;
    vec2 a = vec2(-d, -s - d);
    vec2 b = vec2(-d, d);
    vec2 c = vec2(s + d, d);
    
    for(int i = 0; i < 4; i++)
    {
        float r = float(i) * PI05 + r;
    	if (insideTri(p, rotate(a, r), rotate(b, r), rotate(c, r))) return true;
    }
    
    return false;
}

bool insideSquare(vec2 p, vec2 pos, float size, float rot)
{
    vec2 _ = vec2(-0.5*size, 0.5*size);
    vec2 a = rotate(_.xx, rot) + pos;
    vec2 b = rotate(_.yx, rot) + pos;
    vec2 c = rotate(_.yy, rot) + pos;
    vec2 d = rotate(_.xy, rot) + pos;
    return insideQuad(p, a, b, c, d);    
}


vec3 scene(vec2 p)
{
    vec3 col = vec3(1.0);
    
    float rot = - iTime;
    float r = 0.64;

    if (int(floor(iTime / PI025)) % 2 == 0) 
    {
        for(int i = 0; i < 8; i++)
        {
            float a = rot + float(i) * PI025;
            vec2 pos = vec2(r * cos(a), r * sin(a));        
            if (insideSquare(p, pos, 0.38, iTime + float((i + 1) % 2) * PI025)) col = vec3(0.);    
        }
    }
    else
    {
    	if (insideSquare(p, vec2(0.), 1.285, 0.)) col = vec3(0.);
    	if (insideSquare(p, vec2(0.), 1.285, PI025)) col = vec3(0.);
    	if (insideTriStar(p, 0.38, rot)) col = vec3(1.);
    }
    
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (fragCoord.xy * 2.0 - iResolution.xy) / iResolution.y;
    fragColor = vec4(scene(p), 1.0);
}
