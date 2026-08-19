// Shared functions for noise shader pipeline
// Based on original audio_noise_shared.ogl

#define pi2_inv 0.159154943091895335768883763372
#define pi 3.14159265359

vec2 lower_left(vec2 uv)
{
    return fract(uv * 0.5);
}

vec2 lower_right(vec2 uv)
{
    return fract((uv - vec2(1, 0.)) * 0.5);
}

vec2 upper_left(vec2 uv)
{
    return fract((uv - vec2(0., 1)) * 0.5);
}

vec2 upper_right(vec2 uv)
{
    return fract((uv - 1.) * 0.5);
}

vec4 BlurA(vec2 uv, int level, sampler2D bufA, sampler2D bufD)
{
    if(level <= 0)
    {
        return texture(bufA, fract(uv));
    }

    uv = upper_left(uv);
    for(int depth = 1; depth < 8; depth++)
    {
        if(depth >= level)
        {
            break;
        }
        uv = lower_right(uv);
    }

    return texture(bufD, uv);
}

vec4 BlurB(vec2 uv, int level, sampler2D bufB, sampler2D bufD)
{
    if(level <= 0)
    {
        return texture(bufB, fract(uv));
    }

    uv = lower_left(uv);
    for(int depth = 1; depth < 8; depth++)
    {
        if(depth >= level)
        {
            break;
        }
        uv = lower_right(uv);
    }

    return texture(bufD, uv);
}

vec2 GradientA(vec2 uv, vec2 d, vec4 selector, int level, sampler2D bufA, sampler2D bufD){
    vec4 dX = BlurA(uv + vec2(1.,0.)*d, level, bufA, bufD) - BlurA(uv - vec2(1.,0.)*d, level, bufA, bufD);
    vec4 dY = BlurA(uv + vec2(0.,1.)*d, level, bufA, bufD) - BlurA(uv - vec2(0.,1.)*d, level, bufA, bufD);
    return vec2( dot(dX, selector), dot(dY, selector) );
}

vec2 GradientB(vec2 uv, vec2 d, vec4 selector, int level, sampler2D bufB, sampler2D bufD){
    vec4 dX = BlurB(uv + vec2(1.,0.)*d, level, bufB, bufD) - BlurB(uv - vec2(1.,0.)*d, level, bufB, bufD);
    vec4 dY = BlurB(uv + vec2(0.,1.)*d, level, bufB, bufD) - BlurB(uv - vec2(0.,1.)*d, level, bufB, bufD);
    return vec2( dot(dX, selector), dot(dY, selector) );
}

float unit_square(vec2 uv, vec2 aspect){
    uv = 0.5 + (uv - 0.5)/aspect.yx;
    return (uv.x > 0. && uv.x < 1. && uv.y > 0. && uv.y < 1. ) ? 1. : 0.;
}

vec2 rot90(vec2 vector){
    return vector.yx*vec2(1,-1);
}

vec2 wrap_flip(vec2 uv){
    return vec2(1.)-abs(fract(uv*.5)*2.-1.);
}

vec2 complex_mul(vec2 factorA, vec2 factorB){
    return vec2( factorA.x*factorB.x - factorA.y*factorB.y, factorA.x*factorB.y + factorA.y*factorB.x);
}

vec2 rotozoom(vec2 uv, float ang, float zoom, vec2 aspect){
    vec2 rot = vec2(cos(ang), sin(ang))*zoom;    
    return 0.5 + complex_mul((uv - 0.5)*aspect, rot)/aspect;
}

vec2 spiralzoom(vec2 domain, vec2 center, float n, float spiral_factor, float zoom_factor, vec2 pos){
    vec2 uv = domain - center;
    float d = length(uv);
    return vec2( atan(uv.y, uv.x)*n*pi2_inv + d*spiral_factor, -log(d)*zoom_factor) + pos;
}

vec2 complex_div(vec2 numerator, vec2 denominator){
    return vec2( numerator.x*denominator.x + numerator.y*denominator.y,
                numerator.y*denominator.x - numerator.x*denominator.y)/
        vec2(denominator.x*denominator.x + denominator.y*denominator.y);
}

vec2 mobius(vec2 domain, vec2 zero_pos, vec2 asymptote_pos){
    return complex_div( domain - zero_pos, domain - asymptote_pos);
}

// see https://stackoverflow.com/a/26070411
float atan2(in float y, in float x)
{
    bool s = (abs(x) > abs(y));
    return mix(pi/2.0 - atan(x,y), atan(y,x), s);
}

vec2 uv_polar(vec2 domain, vec2 center){
   vec2 c = domain - center;
   float rad = length(c);
   float ang = atan2(c.y, c.x);
   return vec2(ang, rad);
}

vec2 uv_polar_logarithmic(vec2 domain, vec2 center, float fins, float log_factor, vec2 coord){
   vec2 polar = uv_polar(domain, center) * vec2(pi2_inv, 1);
   return vec2(polar.x * fins + coord.x, log_factor*log(polar.y) + coord.y);
}

vec2 uv_bipolar(vec2 domain, vec2 northPole, vec2 southPole, float fins, float log_factor, vec2 coord){
   vec2 help_uv = mobius(domain, northPole, southPole);
   return uv_polar_logarithmic(help_uv, vec2(0.5), fins, log_factor, coord);
}

float circle(vec2 uv, vec2 aspect, float scale){
    return clamp( 1. - length((uv-0.5)*aspect*scale), 0., 1.);
}

float sigmoid(float x) {
    return 2./(1. + exp2(-x)) - 1.;
}

float smoothcircle(vec2 uv, vec2 aspect, float radius, float ramp){
    return 0.5 - sigmoid( ( length( (uv - 0.5) * aspect) - radius) * ramp) * 0.5;
}

float knob(vec2 domain, vec2 aspect, float innerRadius, float outerRadius, float angle){
    float knob =  sigmoid((circle(domain, aspect, 2./outerRadius) - circle(domain, aspect, 2./innerRadius))/(outerRadius-innerRadius));
    knob = mix(knob, 1., circle(domain + vec2(sin(angle), cos(angle))*0.4*aspect.yx, aspect, 8./outerRadius));
    return knob;
}

float conetip(vec2 uv, vec2 pos, float size, float min, vec3 iResolution)
{
    vec2 aspect = vec2(1.,iResolution.y/iResolution.x);
    return max( min, 1. - length((uv - pos) * aspect / size) );
}

float warpFilter(vec2 uv, vec2 pos, float size, float ramp, vec3 iResolution)
{
    return 0.5 + sigmoid( conetip(uv, pos, size, -16., iResolution) * ramp) * 0.5;
}

vec2 vortex_warp(vec2 uv, vec2 pos, float size, float ramp, vec2 rot, vec3 iResolution)
{
    vec2 aspect = vec2(1.,iResolution.y/iResolution.x);

    vec2 pos_correct = 0.5 + (pos - 0.5);
    vec2 rot_uv = pos_correct + complex_mul((uv - pos_correct)*aspect, rot)/aspect;
    float _filter = warpFilter(uv, pos_correct, size, ramp, iResolution);
    return mix(uv, rot_uv, _filter);
}

vec2 vortex_pair_warp(vec2 uv, vec2 pos, vec2 vel, vec3 iResolution)
{
    vec2 aspect = vec2(1.,iResolution.y/iResolution.x);
    float ramp = 20.;

    float d = 0.075;

    vel *= aspect;
    float l = length(vel);
    vec2 p1 = pos;
    vec2 p2 = pos;

    if(l > 0.){
        vec2 normal = normalize(rot90(vel))/aspect;
        p1 = pos + normal * d / 2.;
        p2 = pos - normal * d / 2.;
    }

    float w = l*32.;

    // two overlapping rotations that would annihilate if they were not displaced.
    vec2 circle1 = vortex_warp(uv, p1, d, ramp, vec2(cos(w),sin(w)), iResolution);
    vec2 circle2 = vortex_warp(uv, p2, d, ramp, vec2(cos(-w),sin(-w)), iResolution);
    return (circle1 + circle2) / 2.;
}

float border(vec2 domain, float thickness){
   vec2 uv = fract(domain-vec2(0.5));
   uv = min(uv,1.-uv)*2.;
   return clamp(max(uv.x,uv.y)-1.+thickness,0.,1.)/(thickness);
}

// Buf D contains an N x N array
float N = 32.;

// in the rectangle region between 2 points
vec2 p1 = vec2(0.75);
vec2 p2 = vec2(1.);

vec4 Cell(int index, sampler2D bufD)
{    
    // map the index to the cell in the array
    float x = mod(float(index), N) / N;
    float y = floor(float(index) / N) / N;
    
    // compartmentalization
    vec2 cell_size = (p2 - p1) / N;
    vec2 center = p1 + cell_size*0.5 + (p2-p1)*vec2(x,y);
    
    return texture(bufD, center);
}

vec2 mouseDelta(vec3 iResolution, vec4 iMouse, sampler2D bufD){
    vec2 pixelSize = 1. / iResolution.xy;
    vec4 oldMouse = Cell(2, bufD);
    vec4 nowMouse = vec4(iMouse.xy * pixelSize.xy, iMouse.zw * pixelSize.xy);
    if(oldMouse.z > pixelSize.x && oldMouse.w > pixelSize.y && 
       nowMouse.z > pixelSize.x && nowMouse.w > pixelSize.y)
    {
        return nowMouse.xy - oldMouse.xy;
    }
    return vec2(0.);
}

// sampling from spectrogram

float spectrum(float domain, int t, int level, sampler2D bufD)
{
    float sixty_fourth = 1./32.;
    vec2 uv = vec2(float(t)*3.*sixty_fourth + sixty_fourth, domain);
    uv = upper_right(uv); level++;
    for(int depth = 1; depth < 8; depth++)
    {
        if(depth >= level)
        {
            break;
        }
        uv = lower_right(uv);
    }

    return texture(bufD, uv).x;
}

float spectrum2D(vec2 uv, float thickness, int level, sampler2D bufD)
{
    float val = spectrum(uv.x, 0, level, bufD);
    return (abs(uv.y - val) < thickness/2.) ? (1.-abs(uv.y - val)*2./thickness) : 0.;
}

vec4 rainbowSpectra(vec2 uv, sampler2D bufD)
{
    float thickness = 0.015;
    // make this a loop?
    vec4 spectra =         vec4(0.25,0,0.5,0)* spectrum2D(uv, thickness, 7, bufD);
    spectra = mix(spectra, vec4(0.5,0,1.,0), spectrum2D(uv, thickness, 6, bufD));
    spectra = mix(spectra, vec4(0,0.5,1,0), spectrum2D(uv, thickness, 5, bufD));
    spectra = mix(spectra, vec4(0,1.,0.5,0), spectrum2D(uv, thickness, 4, bufD));
    spectra = mix(spectra, vec4(1,1,0,0), spectrum2D(uv, thickness, 3, bufD));
    spectra = mix(spectra, vec4(0.6,0.25,0,0), spectrum2D(uv, thickness, 2, bufD));
    spectra = mix(spectra, vec4(0.85,0,0,0), spectrum2D(uv, thickness, 1, bufD));
    spectra = mix(spectra, vec4(1), spectrum2D(uv, thickness, 0, bufD));
    
    return spectra*unit_square(uv);
}

float bass(int t, sampler2D bufD){
    return spectrum(0.125, t, 3, bufD);
}

float mid(int t, sampler2D bufD){
    return spectrum(0.5, t, 3, bufD);
}

float treb(int t, sampler2D bufD){
    return spectrum(0.875, t, 3, bufD);
}

vec4 vol(int t, sampler2D bufD){
    float lo = bass(t, bufD);
    float mi = mid(t, bufD);
    float hi = treb(t, bufD);
    return vec4(lo, mi, hi, (lo + mi + hi)*0.333);
}

vec4 BlurSpectrogram(vec2 uv, int level, sampler2D bufD)
{
    uv = upper_right(uv);
    for(int depth = 1; depth < 8; depth++)
    {
        if(depth >= level)
        {
            break;
        }
        uv = lower_right(uv);
    }

    return texture(bufD, uv);
}

// Quadratic Bezier Stroke functions
float det(vec2 a, vec2 b) { return a.x*b.y-b.x*a.y; }

vec2 closestPointInSegment( vec2 a, vec2 b )
{
  vec2 ba = b - a;
  return a + ba*clamp( -dot(a,ba)/dot(ba,ba), 0.0, 1.0 );
}

vec2 get_distance_vector(vec2 b0, vec2 b1, vec2 b2) {
  
  float a=det(b0,b2), b=2.0*det(b1,b0), d=2.0*det(b2,b1);
  
  if( abs(2.0*a+b+d) < 1000.0 ) return closestPointInSegment(b0,b2);
  
  float f=b*d-a*a;
  vec2 d21=b2-b1, d10=b1-b0, d20=b2-b0;
  vec2 gf=2.0*(b*d21+d*d10+a*d20);
  gf=vec2(gf.y,-gf.x);
  vec2 pp=-f*gf/dot(gf,gf);
  vec2 d0p=b0-pp;
  float ap=det(d0p,d20), bp=2.0*det(d10,d0p);
  float t=clamp((ap+bp)/(2.0*a+b+d), 0.0 ,1.0);
  return mix(mix(b0,b1,t),mix(b1,b2,t),t);

}

float approx_distance(vec2 p, vec2 b0, vec2 b1, vec2 b2) {
  return length(get_distance_vector(b0-p, b1-p, b2-p));
}

vec4 overlaySpline(inout vec4 rgba, vec2 uv, vec4 strokeCol, vec2 p1, vec2 p2, vec2 p3, vec3 iResolution){
    float d = approx_distance((1. - uv)*iResolution.xy, p1*iResolution.xy, p2*iResolution.xy, p3*iResolution.xy);
    float thickness = 1.0;
    float a;
    if(d < thickness) {
      a = 1.;
    } else {
      a = 1. - smoothstep(d, thickness, thickness+0.5);
    }
    rgba = mix(rgba, strokeCol, a * strokeCol.a); 
    return rgba;
}