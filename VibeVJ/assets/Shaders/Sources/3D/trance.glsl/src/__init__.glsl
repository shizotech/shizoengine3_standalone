

//@settings dtype=float32 format=rgba

mat2 rot(float a){
    return mat2(cos(a), -sin(a),
                sin(a), cos(a));
}

void pMod1(inout float p, float size) {
	float halfsize = size*0.5;
	p = mod(p + halfsize, size) - halfsize;
}

void pMod3(inout vec3 p, vec3 size) {
	p = mod(p + size*0.5, size) - size*0.5;
}

float sphere(vec3 p, float radius){
    return length(p)-radius;

}


float map(vec3 p)
{
    vec3 q = p;

   // pMod3(q, vec3(0.75, 1., 0.8));
    pMod3(q, vec3(1., cos(iTime), 0.));
    
    
    pMod1(p.x, 1.);
    
    float s1 = sphere(p, 0.75); 
    float s2 = sphere(q, 0.5);
    float s3 = sphere(q, 0.7);
    
    float disp = 0.5 * (abs(cos(p.x*10.)) *
                       abs(cos(p.y*10.)) *
                       abs(cos(p.z*10.)) );
    	//s1 += disp;
    	s1 *= disp;
    	
    	
  	
  	float df1 = min(s1, s2); // Union
    float df2 = max(s1, s2); // Intersection
    float df3 = max(s1, -s3); // Difference
    
    return df3;
}


float trace(vec3 origin, vec3 r) 
{
  float t = 0.0;
    for (int i = 0; i < 64; ++i) {
        vec3 p = origin + r;
        float d = map(p);
        t += d;
        }
    return t;
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;
    vec3 color = vec3(cos(iTime), 0.12, 0.536);
    uv = uv *2.-1.; // Remap the space to -1. to 1.
    uv.x *= iResolution.x/iResolution.y;
    
    	
   	float FOV = 1.0;
   	vec3 ray = normalize(vec3(uv, FOV));
    
    	
    vec3 origin = vec3(iTime, sin(iTime), cos(iTime));
    float t = trace(origin, ray);
    t  *= smoothstep(0., 2., length(uv.y/uv.x)*10.);

    float expFog = 0.5 / (t*t* 0.45);
    
    vec3 fc = vec3(expFog);
    

    fragColor = vec4((fc+color),1.0);
    //fragColor = vec4(cos(fc+color),1.0);
}

