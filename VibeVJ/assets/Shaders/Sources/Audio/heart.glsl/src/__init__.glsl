
// BUFFER A (0.1) of Fork of "It is alive..."
// Original by coledea at https://www.shadertoy.com/view/ctcGR8
// mainly added auto-vj capabilities
//
// - use with music in iChannel0 of Buffer A -

// I adapted the procedural texture from https://twigl.app/?ol=true&ss=-NNIajM4aEzy75lqtAUd

#define DETAIL 20.0
#define BASE_COLOR vec4(4, 2, 1, 0)
#define ANIMATION_SPEED 2.0
#define BRIGHTNESS 0.2
#define STRUCTURE_SMOOTHNESS 1.2   // how washed out the result looks regarding structure
#define SATURATION 0.2      // how crisp the result looks regarding colors/thickness of black lines

#define aTime 2.133333*iTime
vec4 fft, ffts; //compressed frequency amplitudes


mat2 rotate2D(float r){
    return mat2(cos(r), sin(r), -sin(r), cos(r));
}

void compressFft(){ //v1.2, compress sound in iChannel0 to simplified amplitude estimations by frequency-range
    fft = vec4(0), ffts = vec4(0);

	// Sound (assume sound texture with 44.1kHz in 512 texels, cf. https://www.shadertoy.com/view/Xds3Rr)
    for (int n=0;n<3;n++) fft.x  += texelFetch( iChannel0, ivec2(n,0), 0 ).x*1.2; //bass, 0-517Hz, reduced to 0-258Hz
    for (int n=6;n<8;n++) ffts.x  += texelFetch( iChannel0, ivec2(n,0), 0 ).x*1.2 ; //speech I, 517-689Hz
    for (int n=8;n<14;n+=2) ffts.y  += texelFetch( iChannel0, ivec2(n,0), 0 ).x*1.2 ; //speech II, 689-1206Hz
    for (int n=14;n<24;n+=4) ffts.z  += texelFetch( iChannel0, ivec2(n,0), 0 ).x*1.2 ; //speech III, 1206-2067Hz
    for (int n=24;n<95;n+=10) fft.z  += texelFetch( iChannel0, ivec2(n,0), 0 ).x*1.2 ; //presence, 2067-8183Hz, tenth sample
    for (int n=95;n<512;n+=100) fft.w  += texelFetch( iChannel0, ivec2(n,0), 0 ).x*1.2 ; //brilliance, 8183-44100Hz, tenth2 sample
    fft.y = dot(ffts.xyz,vec3(1)); //speech I-III, 517-2067Hz
    ffts.w = dot(fft.xyzw,vec4(1)); //overall loudness
    fft /= vec4(3,8,8,5); ffts /= vec4(2,3,3,23); //normalize
	
	//for (int n=0;n++<4;) fft[n] *= 1. + .3*pow(fft[n],5.); fft = clamp(fft,.0,1.); //limiter? workaround attempt for VirtualDJ
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    compressFft(); //initializes fft, ffts
    
    vec2 p = (fragCoord.xy - 0.5 * iResolution.xy) / iResolution.y; // center (0,0) and handle aspect ratio
    float dist_squared = dot(p,p);
    float S = 9.0;
    mat2 m = rotate2D(5.0);
    
    float a;
    vec2 n,q;
    
    for(float j = 0.0; j++ < DETAIL;){
      p *= m;
      n *= m;
      q = p * S + iTime *fft.x*0.01 * .15 * ANIMATION_SPEED + 1.8*sin((aTime/2. + fft.z*1.) * ANIMATION_SPEED - dist_squared * 6.0) * 0.8 + j + n;
      a += dot(cos(q) / S, vec2(SATURATION));
      n -= sin(q);
      S *= STRUCTURE_SMOOTHNESS;
    }
    
    float result = 0.2 * ((a + BRIGHTNESS) + a + a); 
    fragColor = vec4(result);
    
    if (fragCoord.y<1.)
        if (fragCoord.x<8.)
            fragColor.a = (fragCoord.x<4.)? fft[int(fragCoord.x)] : ffts[int(fragCoord.x)]; //save compressed amplitudes
}
