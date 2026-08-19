//@settings dtype=float32 format=rgba

#include helpers/shared.glsl

// Reaction-diffusion in red
// L-system fern fractal in green (https://en.wikipedia.org/wiki/Affine_transformation)

vec4 vol(int t){
    return vol(t, iChannel3);
}

vec4 BlurA(vec2 uv, int level)
{
    return BlurA(uv, level, iChannel0, iChannel3);
}

vec4 BlurB(vec2 uv, int level)
{
    return BlurB(uv, level, iChannel1, iChannel3);
}

vec4 Cell(int index){
    return Cell(index, iChannel3);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 noise = texture(iChannel2, fragCoord.xy / iChannelResolution[2].xy + fract(vec2(42,56)*iTime));
    vec4 normalizedVolume = Cell(13)*0.2 + 0.75;
    vec4 integratedVolume = Cell(19);
    vec4 fader = Cell(22)*8.;
    
    if(iFrame<16)
    {
        fragColor = noise;
        return;
    }
    
    vec2 pixelSize = 1./iResolution.xy;
    vec2 mouseV = mouseDelta(iResolution, iMouse, iChannel3);
    vec2 aspect = vec2(1.,iResolution.y/iResolution.x);
    vec4 C18 = Cell(18);
    vec4 volume = vol(0);

    float c8 = smoothcircle(uv, aspect, 0.25, 256.);

    float time = iTime;
    uv = uv + (1.-c8)*vec2(sin(time*0.1 + uv.x*2. +1.) - sin(time*0.214 + uv.y*2. +1.), sin(time*0.168 + uv.x*2. +1.) - sin(time*0.115 +uv.y*2. +1.))*pixelSize*0.5;

    vec4 C25 = Cell(25);
    vec4 C26 = Cell(26);
    vec4 C27 = Cell(27);
    float puller = (integratedVolume.x - integratedVolume.z)/2.;
    float spineBending = C26.z;
    
    float w = C26.w - spineBending - time*4.*asin(1.)/60.*0. - fader.a*2.*0. + asin(1.)*2.*0.5 - (volume.x-volume.y-volume.z*0.25)*0.;
    vec2 rot = vec2(sin(w),-cos(w));
    vec2 rot_uv = 0.5 + complex_mul((uv-0.5)*aspect*1.618, vec2(cos(w),-sin(w)))/aspect;

    fragColor.x = BlurB(mix(uv, rot_uv, c8), 0).x;
    fragColor.x += ((BlurB(uv, 1).x - BlurB(uv, 2).x)*1.5 + (noise.x-0.5) * 0.04); 

    vec4 last_beat_min = Cell(7);
    vec4 last_beat_max = Cell(8);
    vec4 beat_residual = Cell(4);
    
    float beat_relative = (beat_residual.w - last_beat_min.w)/(last_beat_max.w - last_beat_min.w);

    fragColor.y = smoothcircle(uv - 6./32.*rot/aspect, aspect, 2./32. - beat_relative/64.*0. + abs(spineBending)/40., 256.);
    
    float l = 3.;
    vec2 o = vec2(0.33, 0.26);
    
    w = -asin(1.)/1.5;
    float angle = w + spineBending*0.;
    vec2 uv_left = 0.5 + complex_mul((uv - 0.5)*aspect*l + rot90(rot)*o.x - rot*o.y, vec2(cos(angle),-sin(angle)))/aspect;
    
    angle = -w - spineBending*0.;
    vec2 uv_right = 0.5 + complex_mul((uv - 0.5)*aspect*l - rot90(rot)*o.x - rot*o.y, vec2(cos(angle),-sin(angle)))/aspect;
    
    angle = spineBending;
    vec2 uv_main = 0.5 + complex_mul((uv - 0.5)*aspect*1.33 + rot*0.09, vec2(cos(angle),-sin(angle)))/aspect;
    
    float square_main = unit_square(uv_main, aspect);
    float square_left = unit_square(uv_left, aspect);
    float square_right = unit_square(uv_right, aspect);
    fragColor.y = mix(fragColor.y, 1., square_main*BlurB(uv_main, 0).y);
    fragColor.y = mix(fragColor.y, 1., square_left*BlurB(uv_left, 0).y);
    fragColor.y = mix(fragColor.y, 1., square_right*BlurB(uv_right, 0).y);

    float c = circle(uv, aspect, 1./8.);
    fragColor.z = square_right*0.;

    fragColor = clamp(fragColor, 0., 1.);
}