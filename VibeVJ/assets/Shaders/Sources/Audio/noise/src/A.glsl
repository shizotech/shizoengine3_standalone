//@settings dtype=float32 format=rgba

#include helpers/shared.glsl

// Beat detection debug view
// Vortex pair warp from the end of the spring chain simulation is applied here

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
    vec2 pixelSize = 1. / iResolution.xy;
    vec2 aspect = vec2(1.,iResolution.y/iResolution.x);
    vec2 uv = fragCoord.xy * pixelSize;
    vec2 uv_aspect = 0.5 + (uv - 0.5)*aspect.yx;
    
    vec4 noise = (texture(iChannel2, fragCoord.xy / iChannelResolution[2].xy + fract(vec2(42,56)*iTime))-0.5)*2.;
    
    vec2 mouseV = mouseDelta(iResolution, iMouse, iChannel3);
    vec4 volume = vol(0, iChannel3);
    
    vec4 C18 = Cell(18); // last one from the Verlet integrated spring simulation support points
        
    uv = vortex_pair_warp(uv, iMouse.xy*pixelSize, mouseV, iResolution);
    uv = vortex_pair_warp(uv, 0.5 - (C18.xy-0.5), -C18.zw/128., iResolution);
    
    fragColor = BlurA( 0.5 + (uv - 0.5)*vec2(1.006,1.) + vec2(2,0)*pixelSize + vec2(0,iTime*0.0), 0, iChannel0, iChannel3)*1.0- 0./256.;
    
    vec4 v0 = Cell(0, iChannel3);
    vec4 v1 = Cell(1, iChannel3);
    vec4 v3 = Cell(3, iChannel3);
    vec2 uv_v0 =vec2(0.95, v0.w);
    vec2 uv_v3 =vec2(0.95, v3.w*4. + 0.25);
    vec4 beat_residual = Cell(4);
    float energy = (v0.w - v1.w);
    vec2 uv_v1 = vec2(0.95, energy +0.05);
    if(uv.x >= 0.95 - 1./256.){
        fragColor.z = Cell(9).x;
    }
    fragColor = mix(fragColor, vec4(0,1,0,0), circle(uv - uv_v0+0.5, aspect, 256.));
    fragColor = mix(fragColor, vec4(1,0,0,0), circle(uv - uv_v1+0.5, aspect, 256.));
    fragColor = mix(fragColor, vec4(1,1,1,0), circle(uv - uv_v3+0.5, aspect, 256.));

    vec2 uv_v4 =vec2(0.95, beat_residual.w*0.5);
    fragColor = mix(fragColor, vec4(0,1,1,0), circle(uv - uv_v4+0.5, aspect, 256.));

    vec4 last_beat_min = Cell(7, iChannel3);
    vec4 last_beat_max = Cell(8, iChannel3);

    vec2 uv_lo =vec2(0.95, last_beat_min.w*0.5);
    vec2 uv_hi =vec2(0.95, last_beat_max.w*0.5);

    fragColor = mix(fragColor, vec4(1,0,1,0), circle(uv - uv_lo+0.5, aspect, 256.));
    fragColor = mix(fragColor, vec4(1,1,0,0), circle(uv - uv_hi+0.5, aspect, 256.));

    vec4 C12 = Cell(12);
    vec4 C13 = Cell(13);
    vec2 p_bass = C12.xy;
    vec2 p_mid = C12.zw;
    vec2 p_treb = C13.xy;
    vec2 p_vol = C13.zw;
    
    float c7 = smoothcircle(uv - aspect.yx*0.5 + Cell(17, iChannel3).xy*aspect.yx, aspect, 0.0025, 800.);    
    
    float beat_relative = (beat_residual.w - last_beat_min.w)/(last_beat_max.w - last_beat_min.w);
    
    vec4 p1 = Cell(14);
    vec4 p2 = Cell(15);
    vec4 p3 = Cell(16);
    vec4 p4 = C18;
        
    float c_p1 = smoothcircle(uv_aspect - aspect.yx*0.5 + p1.xy*aspect.yx, aspect, 0.0025, 800.);
    float c_p2 = smoothcircle(uv_aspect - aspect.yx*0.5 + p2.xy*aspect.yx, aspect, 0.0025, 800.);
    float c_p3 = smoothcircle(uv_aspect - aspect.yx*0.5 + p3.xy*aspect.yx, aspect, 0.0025, 800.);
    float c_p4 = smoothcircle(uv_aspect - aspect.yx*0.5 + p4.xy*aspect.yx, aspect, 0.0025, 800.);
        
    float c_bass = circle(uv - vec2(0.8,-0.4 + volume.x*0.5)*aspect.yx, aspect, 256.);
    float c_mid = circle(uv - vec2(0.8,-0.4 + volume.y*0.5)*aspect.yx, aspect, 256.);
    float c_treb = circle(uv - vec2(0.8,-0.4 + volume.z*0.5)*aspect.yx, aspect, 256.);
    float c_vol = circle(uv - vec2(0.8,-0.4 + volume.w*0.5)*aspect.yx, aspect, 256.);
    
    fragColor =  mix(fragColor, vec4(1,0,0,0), c_p1);
    fragColor =  mix(fragColor, vec4(0,0,1,0), c_p2);
    fragColor =  mix(fragColor, vec4(.0,1,0,0), c_p3);
    fragColor =  mix(fragColor, vec4(1), c_p4);

    fragColor =  mix(fragColor, vec4(1,0,0,0), c_bass);
    fragColor =  mix(fragColor, vec4(0,1,0,0), c_mid);
    fragColor =  mix(fragColor, vec4(0,0,1,0), c_treb);
    fragColor =  mix(fragColor, vec4(1,1,1,0), c_vol);
    
    fragColor =  mix(fragColor, vec4(0,0,0,0), border(uv, 0.04));
    
    fragColor = clamp(fragColor, 0., 1.);
}