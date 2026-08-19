//@settings dtype=float32 format=rgba

// Original by coledea at https://www.shadertoy.com/view/ctcGR8
// Compressed FFT data pass for heart shader

#define aTime 2.133333*iTime

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Compress sound from iChannel0 to simplified amplitude estimations by frequency-range
    vec4 fft = vec4(0), ffts = vec4(0);

    // Sound (assume sound texture with 44.1kHz in 512 texels)
    for (int n=0;n<3;n++) fft.x  += texelFetch( iChannel0, ivec2(n,0), 0 ).x*1.2; //bass, 0-517Hz
    for (int n=6;n<8;n++) ffts.x  += texelFetch( iChannel0, ivec2(n,0), 0 ).x*1.2 ; //speech I, 517-689Hz
    for (int n=8;n<14;n+=2) ffts.y  += texelFetch( iChannel0, ivec2(n,0), 0 ).x*1.2 ; //speech II, 689-1206Hz
    for (int n=14;n<24;n+=4) ffts.z  += texelFetch( iChannel0, ivec2(n,0), 0 ).x*1.2 ; //speech III, 1206-2067Hz
    for (int n=24;n<95;n+=10) fft.z  += texelFetch( iChannel0, ivec2(n,0), 0 ).x*1.2 ; //presence, 2067-8183Hz
    for (int n=95;n<512;n+=100) fft.w  += texelFetch( iChannel0, ivec2(n,0), 0 ).x*1.2 ; //brilliance, 8183-44100Hz
    fft.y = dot(ffts.xyz,vec3(1)); //speech I-III, 517-2067Hz
    ffts.w = dot(fft.xyzw,vec4(1)); //overall loudness
    fft /= vec4(3,8,8,5); ffts /= vec4(2,3,3,23); //normalize

    // Save compressed amplitudes
    if (fragCoord.y < 1.0) {
        if (fragCoord.x < 8.0) {
            float val;
            if (fragCoord.x < 4.0) {
                val = fft[int(fragCoord.x)];
            } else {
                val = ffts[int(fragCoord.x) - 4];
            }
            fragColor = vec4(val, val, val, val);
        }
    }
}
