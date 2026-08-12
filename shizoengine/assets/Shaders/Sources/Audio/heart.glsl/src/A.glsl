uniform sampler2D A;

// Fork (0.2.230716) of "It is alive..."
// Original by coledea at https://www.shadertoy.com/view/ctcGR8
// mainly added auto-vj capabilities
//
// - use with music in A of Buffer A -

#define PI 3.14159265359
#define aTime 2.133333*iTime

const int MAX_MARCHING_STEPS = 80;
const float MARCHING_EPSILON = 0.0001;
const float DERIVATIVE_EPSILON = 0.001;

// LIGHTING
const vec3 ALBEDO_INNER = vec3(3.0, 0.02, 0.03);
const vec3 ALBEDO_OUTER = vec3(0.3, 0.0, 0.0);
const vec3 ALBEDO_CREASES = vec3(0.0, 0.0, 0.01);

// SCENE
const vec3 SPHERE_CENTER = vec3(0.0);
const float SPHERE_RADIUS = .4;
vec4 fft, ffts; //compressed frequency amplitudes


//======================================
// HELPER FUNCTIONS
//======================================

void compressFft(){ //here just reads compressed amplitudes from buffer
    for (int n=0;n<4;n++)
        fft[n] = texelFetch( A, ivec2(n,0), 0 ).a,
        ffts[n] = texelFetch( A, ivec2(n+4,0), 0 ).a;
}

vec2 spherical_mapping(vec2 normal)
{
    //return normal / 2.0 + 0.5;  // simpler approximation, leads to distortions at the poles
    return vec2(asin(normal.x), asin(normal.y)) / PI + 0.5;
}

// From: https://iquilezles.org/articles/smin/
float smin( float a, float b, float k )
{
    float h = max( k-abs(a-b), 0.0 )/k;
    return min( a, b ) - h*h*k*(1.0/4.0);
}


vec3 hash(vec3 p) {
  return fract(
      sin(vec3(dot(p, vec3(1.0, 57.0, 113.0)), 
              dot(p, vec3(57.0, 113.0, 1.0)),
               dot(p, vec3(113.0, 1.0, 57.0)))) *
      43758.5453);
}

// From: https://github.com/MaxBittker/glsl-voronoi-noise
vec3 voronoi3d(const in vec3 x) {
  vec3 p = floor(x);
  vec3 f = fract(x);

  float id = 0.0;
  vec2 res = vec2(100.0);
  for (int k = -1; k <= 1; k++) {
    for (int j = -1; j <= 1; j++) {
      for (int i = -1; i <= 1; i++) {
        vec3 b = vec3(float(i), float(j), float(k));
        vec3 r = vec3(b) - f + hash(p + b);
        float d = dot(r, r);

        float cond = max(sign(res.x - d), 0.0);
        float nCond = 1.0 - cond;

        float cond2 = nCond * max(sign(res.y - d), 0.0);
        float nCond2 = 1.0 - cond2;

        id = (dot(p + b, vec3(1.0, 57.0, 113.0)) * cond) + (id * nCond);
        res = vec2(d, res.x) * cond + res * nCond;

        res.y = cond2 * d + nCond2 * res.y;
      }
    }
  }

  return vec3(sqrt(res), abs(id));
}


//======================================
// SCENE DEFINITION
//======================================

float organic_displacement(vec2 normal)
{   
    vec2 uv = spherical_mapping(normal);
    return texture(A, uv).x;
}

float distToSphere(vec3 center, float radius, vec3 queryPoint)
{
    return length(center - queryPoint) - radius;
}

// returns distance to scene and displacement value from texture
vec2 distToScene(vec3 queryPoint)
{
    float displacement = organic_displacement(normalize(queryPoint - SPHERE_CENTER).xy);
    float dist = length(SPHERE_CENTER - queryPoint) - (SPHERE_RADIUS + displacement);     // big sphere
    
    float sinTime = sin(iTime + fft.x*PI) * 0.2;
    float cosTime = cos(aTime/4. + fft.y*PI) * 0.2;
    dist = smin(dist, distToSphere(vec3(sinTime * sinTime, cosTime, sinTime), 0.5*fft.x, queryPoint), 0.4+ffts.x*.3); // first small sphere
    dist = smin(dist, distToSphere(vec3(sinTime, sinTime * cosTime, cosTime), 0.3*fft.y, queryPoint), 0.3+.3*ffts.y); // second small sphere
    dist = smin(dist, distToSphere(vec3(cosTime * cosTime, sinTime, sinTime * cosTime), 0.2*fft.z, queryPoint), 0.2+.2*ffts.z); // third small sphere
    return vec2(dist, displacement);
}

//======================================
// GENERAL LIGHTING
//======================================
vec3 normal(vec3 p)
{
    const vec2 k = vec2(1,-1);
    return normalize( k.xyy * distToScene(p + k.xyy * DERIVATIVE_EPSILON).x + 
                      k.yyx * distToScene(p + k.yyx * DERIVATIVE_EPSILON).x + 
                      k.yxy * distToScene(p + k.yxy * DERIVATIVE_EPSILON).x + 
                      k.xxx * distToScene(p + k.xxx * DERIVATIVE_EPSILON).x);
}


//======================================
// PBR from  https://learnopengl.com/PBR/Lighting
//======================================

// Fresnel-Schlick approximation
vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}  

// normal distribution (for depicting roughness)
float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a      = roughness*roughness;
    float a2     = a*a;
    float NdotH  = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;
	
    float num   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
	
    return num / denom;
}

// self-occlusion
float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float num   = NdotV;
    float denom = NdotV * (1.0 - k) + k;
	
    return num / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2  = GeometrySchlickGGX(NdotV, roughness);
    float ggx1  = GeometrySchlickGGX(NdotL, roughness);
	
    return ggx1 * ggx2;
}

vec3 lightPBR(vec3 point, vec3 lightPositions[2], vec3 lightColors[2], vec3 eye, float material)
{
   // doesn't work for some reason
   /* vec2 materialDerivatives = vec2(dFdx(material), dFdy(material));
    float materialChange = 10000.0 * (materialDerivatives.x + materialDerivatives.y);
    vec3 albedo = vec3(materialChange);*/

    vec3 albedo = mix(ALBEDO_OUTER, ALBEDO_INNER, smoothstep(0.05, 0.08, material));
    //albedo = mix(ALBEDO_CREASES, albedo, step(0.01, material));

    //float metallic = 0.1 * smoothstep(0.05, 0.08, material);
    float metallic = .0;
    float roughness = 0.1 + 0.4 * (1.0 - smoothstep(0.07, 0.08, material)); //0.5;
    float ao = smoothstep(0.05, 0.09, material);

    vec3 N = normal(point); 
    N = normalize(N);
    vec3 V = normalize(eye - point);

    vec3 F0 = vec3(0.04); // approximate base reflectivity for dielectrics
    F0 = mix(F0, albedo, metallic);
		    
    // reflectance equation
    vec3 Lo = vec3(0.0);
    
    for(int i = 0; i < 2; ++i) 
    {
        // calculate per-light radiance
        vec3 L = normalize(lightPositions[i] - point);
        vec3 H = normalize(V + L);
        float distance    = length(lightPositions[i] - point);
        float attenuation = 1.0 / (distance * distance);
        vec3 radiance     = lightColors[i] * attenuation;        
	
        // cook-torrance brdf
        float NDF = DistributionGGX(N, H, roughness);        
        float G   = GeometrySmith(N, V, L, roughness);      
        vec3 F    = fresnelSchlick(max(dot(H, V), 0.0), F0);       
	
        vec3 kS = F;
        vec3 kD = vec3(1.0) - kS;
        kD *= 1.0 - metallic;	  // metallic surfaces do not have diffuse reflection (refraction)
	
        vec3 numerator    = NDF * G * F;
        float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
        vec3 specular     = numerator / denominator;  
		    
        // add to outgoing radiance Lo
        float NdotL = max(dot(N, L), 0.0);                
        Lo += (kD * albedo / PI + specular) * radiance * NdotL; 
    }  
  
    // add ambient term
    vec3 ambient = vec3(0.03) * albedo * ao;
    vec3 color = ambient + Lo;
	
    // HDR tone mapping and gamma correction
    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0/2.2));  
   
    return color;
}

//======================================
// RAYMARCHING
//======================================

vec3 getRayDirection(vec3 eye, vec2 fragCoord) {
    vec2 p = (2.0 * fragCoord-iResolution.xy) / iResolution.y;
    vec3 ww = normalize(vec3(0.0) - eye);
    vec3 uu = normalize(cross( vec3(0.0,1.0,0.0), ww ));
    vec3 vv = normalize(cross(ww,uu));
    return normalize( p.x*uu + p.y*vv + 2.5*ww );

}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{       
    compressFft(); //initializes fft, ffts
    
    vec3 eye = vec3(sin(iTime * 0.05 + pow(sin(aTime/16.),9.)*PI) * 0.5 + 0.1, 0.0, 1.8);
    vec3 ray = getRayDirection(eye, fragCoord);
    
    vec3 lightPos[2] = vec3[2](vec3(2.0, 0.0, 0.0), vec3(0.0, 1.0, 1.0));
    vec3 lightColors[2] = vec3[2](vec3(1.0), vec3(1.0));
    
    vec3 p = eye;
    for(int i = 0; i < MAX_MARCHING_STEPS; i++){
        
        vec2 queryResult = distToScene(p);
        float dist = queryResult.x;
        float displacement = queryResult.y;
        
        if(dist < MARCHING_EPSILON){
            fragColor = vec4(lightPBR(p, lightPos, lightColors, eye, displacement), 1.0);
            return;
        }
        
        p += ray * dist;
    }
    
    // background
    vec2 uv = fragCoord/iResolution.xy;
    float organic = texture(A, uv).x;
    uv.x *= iResolution.x / iResolution.y;
    uv = sin(iTime * 0.25) + uv * 6.0;
    vec3 voronoi = voronoi3d(vec3(-6.0, uv))*.1*(1.+5.*fft.w);
    float final = pow(voronoi.r * 3.0, organic * 10.0 * (1.+2.*fft.y));
    uv = (2.*fragCoord-iResolution.xy) / max(iResolution.x, iResolution.y)*1.2;
    final *= length(uv)*length(uv); //vignette
    fragColor = vec4(final * .5 * ffts.w, 0., 0.015, 1.0);
}
