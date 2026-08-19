//@settings dtype=float32 format=rgba
#define PI 3.1415926535897932384626433832795
#define MAX_MARCHING_STEPS 100
#define EPSILON 0.0001
#define start 0.1
#define end 100.0

uniform sampler2D input1;
//@rgb
uniform vec3 bug;

float sphere_func(in vec3 pos, in float r)
{
    return length(pos) - r;
}

float box( vec3 p, vec3 b )
{
  vec3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d, vec3(0.0)));
}

float soundSphere(vec3 pos, float r)
{
    float ry = atan(pos.x / pos.z);
    float rx = atan(pos.y / pos.z);
    
    int a = int(fract((ry / PI / 4. + .5) * 3.) * 512.);
    int b = int(fract((rx / PI / 4. + .5) * 3.) * 512.);
    
    float freq = texture(input1, vec2(0.0, 0.0)).x; 
    float wave = texture(input1, vec2(0.0, 1.0)).x;
    float disp = wave / 10. + freq;
    
    return length(pos) - r - disp;
}


void intersect(inout float distA, float distB)
{
    distA = max(distA, distB);
}

void combine(inout float distA, float distB)
{
    distA = min(distA, distB);
}

void difference(inout float distA, float distB)
{
    distA = max(-distA, distB);
}

//pos, layer direction, layer gap, laver offet, ball size
float layer(vec3 p, vec3 d, vec3 g, vec3 o, float s)
{
    p += mod(d * iTime + o, g);
    vec3 q = mod(p, vec3(g))-0.5*vec3(g);
    return sphere_func(q, s);
}

float sdf(vec3 pos)
{
    float b = 10000.;
    float u = .4;
    float s = .33;
    float k = .5;
    
    combine(b, layer(pos, vec3( 0., 0., s ), vec3(u*3.), vec3(0., u , 0.), k));
    combine(b, layer(pos, vec3( 0., s , 0.), vec3(u*3.), vec3(u , 0., 0.), k));
    combine(b, layer(pos, vec3( s , 0., 0.), vec3(u*3.), vec3(0., 0., u ), k));
    combine(b, layer(pos, vec3( 0., 0.,-s ), vec3(u*3.), vec3(0., -u, 0.), k));
    combine(b, layer(pos, vec3( 0.,-s , 0.), vec3(u*3.), vec3(-u, 0., 0.), k));
    combine(b, layer(pos, vec3(-s , 0., 0.), vec3(u*3.), vec3(0., 0., -u), k));
    
    difference(b, soundSphere(pos, 1.));
    return b;
}

float ray(vec3 eye, vec3 dir)
{
    float depth = start;
	for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        
        float dist = sdf(eye + depth * dir);
        
        if (dist < EPSILON) {
            return depth;
        }
        depth += dist;

        if (depth >= end) {
            return end;
        }
    }
    return end;
}

vec3 estimateNormal(vec3 p)
{
    return normalize(vec3(
        sdf(vec3(p.x + EPSILON, p.y, p.z)) - sdf(vec3(p.x - EPSILON, p.y, p.z)),
        sdf(vec3(p.x, p.y + EPSILON, p.z)) - sdf(vec3(p.x, p.y - EPSILON, p.z)),
        sdf(vec3(p.x, p.y, p.z  + EPSILON)) - sdf(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

mat4 viewMatrix(vec3 eye, vec3 center, vec3 up)
{
	vec3 f = normalize(center - eye);
	vec3 s = normalize(cross(f, up));
	vec3 u = cross(s, f);
	return mat4(
		vec4(s, 0.0),
		vec4(u, 0.0),
		vec4(-f, 0.0),
		vec4(0.0, 0.0, 0.0, 1)
	);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = vec2(fragCoord.x / iResolution.y, fragCoord.y / iResolution.y);
    uv.x += (1. - iResolution.x / iResolution.y) / 2.;
    vec2 st = uv - vec2(.5);
    
    vec3 eye = vec3(sin(iTime)*7., cos(iTime)*5., 4.);
    vec3 dir = vec3(st / 2., -1.);
    
    mat4 mat = viewMatrix(eye, vec3(0.), vec3(0., 1., 0.));
    dir = (mat * vec4(dir, 1.)).xyz;
    
    float depth = ray(eye, dir);
    if(!(depth >= end - EPSILON))
    {
        vec3 hit = eye + dir * depth;
    	vec3 norm = estimateNormal(hit);
        
        fragColor = vec4(norm+vec3(.5), 1.);
    }
    else
    {
        fragColor = vec4(0);
    }
    fragColor.rgb += bug;
}