//@settings dtype=float32 format=rgba
/*
 * Flower of Life Trance
 *
 * A signed distance field of two repeating overlapping circle grids,
 * often known as the Flower of Life, slowly spin and change.
 *
 * Designed for and with ambient music:
 * Carbon Based Lifeforms - 6EQUJ5
 * https://www.youtube.com/watch?v=a6YU4O3zq_M
 */

#define SPEED 2.0

#define PI 3.1415926538

float sdRing(in vec2 p, in float r1, in float r2) {
  return abs(length(p) - r1) - r2;
}

float sdFlowerOfLife( in vec2 p, in float r1, in float r2) {
    float d = sdRing(p,r1,r2);

    d = min(d, sdRing(p+vec2(0.0,-r1),r1,r2));
    d = min(d, sdRing(p+vec2(0.0,r1),r1,r2));

    vec2 pos = vec2(r1 * cos(PI/6.0), r1 * sin(PI/6.0));
    vec2 rpos = reflect(pos, vec2(0.0,1.0));

    d = min(d, sdRing(p+pos,r1,r2));
    d = min(d, sdRing(p-pos,r1,r2));
    d = min(d, sdRing(p+rpos,r1,r2));
    d = min(d, sdRing(p-rpos,r1,r2));

    d = min(d, sdRing(p+vec2(r1*1.73,0.0),r1,r2));
    d = min(d, sdRing(p+vec2(-r1*1.73,0.0),r1,r2));
    
    vec2 pos2 = vec2(r1*1.73 * cos(PI/3.0), r1*1.73 * sin(PI/3.0));
    vec2 rpos2 = reflect(pos2, vec2(0.0,1.0));
    
    d = min(d, sdRing(p+pos2,r1,r2));
    d = min(d, sdRing(p-pos2,r1,r2));
    d = min(d, sdRing(p+rpos2,r1,r2));
    d = min(d, sdRing(p-rpos2,r1,r2));

    d = min(d, sdRing(p+vec2(r1*1.73,r1),r1,r2));
    d = min(d, sdRing(p+vec2(r1*1.73,-r1),r1,r2));
    d = min(d, sdRing(p+vec2(-r1*1.73,r1),r1,r2));
    d = min(d, sdRing(p+vec2(-r1*1.73,-r1),r1,r2));
    
    return d;
}

float sdFlowerOfLifeRepeating(in vec2 p, in float r1, in float r2) {    
    p += vec2(r1*0.865,r1);    
    p = mod(p,vec2(2.0*r1*0.865,2.0*r1))-vec2(r1*0.865,r1);
    return sdFlowerOfLife(p,r1,r2);
}

// src: https://iquilezles.org/articles/palettes/
vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d ) {
    return a + b*cos(2.0*PI*(c*t+d) );
}

vec3 pEarth(in float t) {   
    return palette(t,
        vec3(0.5, 0.5, 0.5),
        vec3(0.5, 0.5, 0.5),
        vec3(1.0, 1.0, 0.5),
        vec3(0.80, 0.90, 0.30)
    );
}

vec2 rotate(vec2 uv, float th) {
  return mat2(cos(th), sin(th), -sin(th), cos(th)) * uv;
}

// src: https://www.shadertoy.com/view/7tf3Ws
float easeInOutCubic(float x) {
    return x < .5 ? 4. * x * x * x : 1. - pow(-2. * x + 2., 3.) / 2.;
}

float triangleWave(float x) {
  return abs(( mod(x, 2.0)) - 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float time = iTime*SPEED;
    
    // Find the diviser to handle vertical and horizontal screens.
    float resolutionDiviser = min(iResolution.y,iResolution.x);
    vec2 uv = (fragCoord.xy-iResolution.xy*.5)/resolutionDiviser;

    // Zooming
    uv *= easeInOutCubic(1.0-abs(cos(time/25.0)))*1.5+1.0;
    //uv *= 2.0;
    // Spinning
    uv = rotate(uv, easeInOutCubic(cos(time/29.0))/2.0);
    // Repeating flowers
    float d = sdFlowerOfLifeRepeating(uv, 0.5, 0.00005);
    // Repeating more flowers
    uv = rotate(uv, -easeInOutCubic(sin(time/37.0))/2.0);
    d = min(d-0.005, sdFlowerOfLifeRepeating(uv, 0.3+0.4*easeInOutCubic(triangleWave(time/41.0)), 0.00005));
    // Coloring
    vec3 col = pEarth(cos(d*10.0-time/23.0));
    // Moving
	col *= 0.7 + 0.5*cos(300.0*d + time*4.0);
    vec3 lineCol = pEarth(cos(d*30.0-time/18.0)) * vec3(1.2);
	col = mix( col, lineCol, 1.0 - smoothstep(0.0, easeInOutCubic(triangleWave(time/8.0))/58.0+0.005, d));
    
    // Just black and white
    //vec3 col = vec3(smoothstep(0.0, 0.01, d));
    
    fragColor = vec4(col,1.0);
}
