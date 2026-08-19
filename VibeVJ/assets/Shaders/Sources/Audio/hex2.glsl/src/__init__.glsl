//@settings dtype=float32 format=rgba

const float PI = 3.14159;
const float cos60 = cos(PI / 3.);
const float sin60 = sin(PI / 3.);
const float root3 = sqrt(3.);
const float root3_3 = sqrt(3.) / 3.;


// Hexagon coordinate funcs from http://www.redblobgames.com/grids/hexagons/
vec2 cube_to_hex(vec3 h)
{
    return h.xz;
}

vec3 hex_to_cube(vec2 h)
{
    return vec3(h.x, -h.x - h.y, h.y);
}

vec3 cube_round(vec3 h)
{
    float rx = round(h.x);
    float ry = round(h.y);
    float rz = round(h.z);

    float x_diff = abs(rx - h.x);
    float y_diff = abs(ry - h.y);
    float z_diff = abs(rz - h.z);

    if (x_diff > y_diff && x_diff > z_diff)
    {
        rx = -ry-rz;
    }
    else if (y_diff > z_diff)
    {
        ry = -rx-rz;
    }
    else
    {
        rz = -rx-ry;
    }

    return vec3(rx, ry, rz);
}

vec2 hex_round(vec2 h)
{
    return cube_to_hex(cube_round(hex_to_cube(h)));
}

float hex_distance(vec2 a, vec2 b)
{
    return (abs(a.x - b.x) 
          + abs(a.x + a.y - b.x - b.y)
          + abs(a.y - b.y)) / 2.;
}


// Hexagon SDF from IQ: https://iquilezles.org/articles/distfunctions
float hexagon( vec2 p, float h )
{
    vec2 q = abs(p);
    return max((q.y*0.866025+q.x*0.5),q.x)-h;
}

float scene(vec2 p)
{
    float width = 60.;
    
    mat2 T = mat2(root3_3, 0., -1./3., 2./3.);
    mat2 invT = mat2(root3, 0., root3 * 0.5, 3./2.);
    
    vec2 h = hex_round(T * p / width);
    
    vec2 center = width * invT * h;
    
    float d_hex = (hex_distance(h, vec2(0.))) / (iResolution.x / (2. * width));
    float d_true = length(p) / (iResolution.x / (2.));
	float fft_hex  = texture(iChannel0, vec2(d_hex, 0.25)).x;
	float fft_true  = texture(iChannel0, vec2(d_true, 0.25)).x;
    
    return clamp(1. - float(hexagon(p - center, ((fft_hex + fft_true*0.3) * (width + 2.) - 1.) * sin60)), 0., 1.);
}


// Palette code from IQ: https://iquilezles.org/articles/palettes
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = (fragCoord.xy - (iResolution.xy * 0.5));
    
    mat2 R = mat2(cos60, sin60, -sin60, cos60);
    
	float r = (length(uv) / iResolution.x) + 0.15;

    float fft  = texture( iChannel0, vec2(0,0.25) ).x;
    
    vec2 radius = vec2(pow(fft, 6.) * 8., 0.);
    
    vec2 off0 = radius;
    vec2 off1 = off0 * R * R;
    vec2 off2 = off1 * R * R;
    
    vec3 color = vec3(scene(uv + off0),
                      scene(uv + off1), 
                      scene(uv + off2));
    
    vec3 vignette = palette(0.75 + r, vec3(0.5), vec3(0.5), vec3(1.), vec3(0.0, 0.1, 0.2)) + 0.1;
    
	fragColor = vec4(pow(color * vignette, vec3(0.5)), 1.);
}
