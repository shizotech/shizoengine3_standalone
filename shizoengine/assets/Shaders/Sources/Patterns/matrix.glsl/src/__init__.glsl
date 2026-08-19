

//@settings dtype=float32 format=rgba

vec2 hash22(vec2 p)
{
    p = vec2( dot(p,vec2(127.1,311.7)),
              dot(p,vec2(269.5,183.3)));

    return -1.0 + 2.0 * fract(sin(p)*43758.5453123);
}

const float F2 = 0.5f *(sqrt(3.0) - 1.0);
const float G2 = (3.0-sqrt(3.0))/6.0;

float simplex_noise_2d(vec2 p) 
{
    float n0, n1, n2; 
    
    float s = (p.x + p.y) * F2; 
    vec2 pi = floor(p + vec2(s));
    float t = (pi.x + pi.y) * G2;
    vec2 pf = p - (pi - vec2(t));

    vec2 dp;
    if(pf.x > pf.y) {dp.x=1.; dp.y=0.;}
    else {dp.x = 0.; dp.y=1.;}      
    vec2 pf1 = pf - dp + vec2(G2);
    vec2 pf2 = pf - vec2(1.0 - 2.0 * G2);

    float t0 = 0.5 - pf.x * pf.x - pf.y * pf.y;
    if(t0<0.) n0 = 0.0;
    else {
      t0 *= t0;
      n0 = t0 * t0 * dot(hash22(pi), pf);
    }
    float t1 = 0.5 - pf1.x * pf1.x - pf1.y * pf1.y;
    if(t1 < 0.) n1 = 0.0;
    else {
      t1 *= t1;
      n1 = t1 * t1 * dot(hash22(pi + dp), pf1);
    }
    float t2 = 0.5 - pf2.x * pf2.x -pf2.y * pf2.y;
    if(t2<0.) n2 = 0.0;
    else {
      t2 *= t2;
      n2 = t2 * t2 * dot(hash22(pi + vec2(1.0)), pf2);
    }
    return 70.0 * (n0 + n1 + n2);
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // making colorful lines
    float lines = float(int(fragCoord.x) / 20);
    float blackLines = step(10.1, float(int(fragCoord.x) % 20));
    float seed = sin(lines + iTime);
    // may better way to transform float to RGB instead?
    vec3 color = vec3(seed, 4. * seed * (1. - seed), 1. - seed) * seed * blackLines;
    
    float noise = mix(0., 1., simplex_noise_2d(vec2(lines, 2.)));
    float another_noise = mix(0., .5, simplex_noise_2d(vec2(lines, 3.)));
   
    float maxLen = 1.;
    // edit to change line falling speed
    float fallSpeed = .3;
    // randomize line start position and move line start position down by time
  	float lineStart = fract(noise - iTime * fallSpeed) * maxLen;
    // randomize line end position
    float lineEnd = .4 + another_noise;
    
    vec2 uv = fragCoord/iResolution.xy;
    float len = uv.y;
    float upper = step(len, lineStart);
    float deltaLen = abs(len - lineStart);
    // distance from current y to line start
    deltaLen = upper * (maxLen - deltaLen) + (1. - upper) * deltaLen;
    // interpolate attenuation by distance 
    float attenuation = mix(1., 0., min(deltaLen, lineEnd) / lineEnd);
    color *= attenuation;
    
    fragColor = vec4(color, 1.);
}

