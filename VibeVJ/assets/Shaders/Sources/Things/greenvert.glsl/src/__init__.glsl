
//@settings dtype=float32 format=rgb

//@slider min=0.0 max=1.0 value=0.5
uniform float interval;

//@slider min=0.0 max=1.0 value=0.5
uniform float cycle;
//@slider min=0.0 max=4.0 value=2
uniform float gradient;
//@slider min=0.0 max=2.0 value=1
uniform float speed;

//@rgb value=(0.5,0.2,0.1)
uniform vec3 base_color;

//@enum options=(Test 1, Test2, Test 3)
uniform int test_enum;

const float angle = radians(135.);

const vec3 color = vec3(0.3, 1., 0.2);

#define RADIAL 1
#define SOLID 0

void mainImage( out vec4 frag_color, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.x;
    
    float r = angle;
    vec2 dir = normalize(vec2(sin(r), cos(r)));
    vec2 p = vec2(0.5, 0.5 * (iResolution.y / iResolution.x));
  
    float m = gradient;
    float b = mod(iTime * speed, interval);
    
#if RADIAL
    float x = -distance(uv, p);
#else 
    float x = -dot(uv, dir);
#endif
    
    float y = (m * x) + b;
    y = mod(y, interval) * (1./cycle);
    
#if SOLID
    y = round(y);
#endif
    // Output to screen
    frag_color = vec4(base_color + (color - y), 1.0);
	//frag_color.x = interval;
	
	frag_color.x += test_enum;
}