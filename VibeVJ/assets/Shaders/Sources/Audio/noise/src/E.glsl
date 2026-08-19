//@settings dtype=float32 format=rgba

#include helpers/shared.glsl

// Milkdrop 2.0 shader pipeline clone - final visualization pass

vec4 Cell(int index){
    return Cell(index, iChannel3);
}

vec4 vol(int t){
    float lo = bass(t, iChannel3);
    float mi = mid(t, iChannel3);
    float hi = treb(t, iChannel3);
    return vec4(lo, mi, hi, (lo + mi + hi)*0.333);
}

vec4 BlurA(vec2 uv, int level){
    return BlurA(uv, level, iChannel0, iChannel3);
}

vec4 BlurB(vec2 uv, int level){
    return BlurB(uv, level, iChannel1, iChannel3);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    fragColor = vec4(0);
    vec2 pixelSize = 1. / iResolution.xy;
    vec2 aspect = vec2(1.,iResolution.y/iResolution.x);
    vec2 uv = fragCoord.xy * pixelSize;
    vec2 uv_aspect = 0.5 + (uv - 0.5)*aspect.yx;

    vec4 rnd0 = Cell(10);
    vec4 rnd1 = Cell(11);
    vec4 normalizedVolume = Cell(21)*0.2 + 0.75;
    vec4 volume = vol(0, iChannel3);

    vec4 last_beat_min = Cell(7);
    vec4 last_beat_max = Cell(8);
    vec4 beat_residual = Cell(4);

    float beat_relative = (beat_residual.w - last_beat_min.w)/(last_beat_max.w - last_beat_min.w);

    float c1 = smoothcircle(uv - aspect.yx*0.5 + rnd1.xy*aspect.yx, aspect, 0.03, 600.);
    float c2 = smoothcircle(uv - aspect.yx*0.5 + rnd0.xy*aspect.yx, aspect, 0.015, 800.);
    float c3 = smoothcircle(uv - aspect.yx*0.5 + mix(rnd0.xy, rnd1.xy, beat_relative)*aspect.yx, aspect, 0.005, 1400.);

    float bassBox = unit_square(0.5 + (uv-vec2(0.125, volume.x)) * 32. * aspect);
    float midBox = unit_square(0.5 + (uv-vec2(0.5, volume.y)) * 32. * aspect);
    float trebBox = unit_square(0.5 + (uv-vec2(0.875, volume.z)) * 32. * aspect);

    fragColor =  mix(fragColor, vec4(1.,0.,0,0), bassBox);
    fragColor =  mix(fragColor, vec4(0.,1.,0,0), midBox);
    fragColor =  mix(fragColor, vec4(0.,0.,1,0), trebBox);

    bassBox = unit_square(0.5 + (uv-vec2(0.25, normalizedVolume.x)) * 128. * aspect);
    midBox = unit_square(0.5 + (uv-vec2(0.5, normalizedVolume.y)) * 128. * aspect);
    trebBox = unit_square(0.5 + (uv-vec2(0.75, normalizedVolume.z)) * 128. * aspect);

    fragColor =  mix(fragColor, vec4(1.,0.,0,0), bassBox);
    fragColor =  mix(fragColor, vec4(0.,1.,0,0), midBox);
    fragColor =  mix(fragColor, vec4(0.,0.,1,0), trebBox);

    vec4 integratedVolume = Cell(19);

    bassBox = unit_square(0.5 + (uv-vec2(0.125, integratedVolume.x)) * 64. * aspect);
    midBox = unit_square(0.5 + (uv-vec2(0.5, integratedVolume.y)) * 64. * aspect);
    trebBox = unit_square(0.5 + (uv-vec2(0.875, integratedVolume.z)) * 64. * aspect);

    vec4 fader = Cell(22)*8.;

    float bassFader = knob(0.5 + (uv-vec2(0.25,0.75))*5., aspect, 0.42, 0.5, fader.x);
    float midFader = knob(0.5 + (uv-vec2(0.5,0.75))*5., aspect, 0.42, 0.5, fader.y);
    float trebFader = knob(0.5 + (uv-vec2(0.75,0.75))*5., aspect, 0.42, 0.5, fader.z);

    fragColor =  mix(fragColor, vec4(1.,0.,0,0), bassBox);
    fragColor =  mix(fragColor, vec4(0.,1.,0,0), midBox);
    fragColor =  mix(fragColor, vec4(0.,0.,1,0), trebBox);

    bassBox = unit_square(0.5 + (uv-vec2(0.125, 1.-abs(integratedVolume.x-volume.x))) * 64. * aspect);
    midBox = unit_square(0.5 + (uv-vec2(0.5, 1.-abs(integratedVolume.y-volume.y))) * 64. * aspect);
    trebBox = unit_square(0.5 + (uv-vec2(0.875, 1.-abs(integratedVolume.z-volume.z))) * 64. * aspect);

    fragColor =  mix(fragColor, vec4(1.,0.,0,0), bassBox);
    fragColor =  mix(fragColor, vec4(0.,1.,0,0), midBox);
    fragColor =  mix(fragColor, vec4(0.,0.,1,0), trebBox);

    fragColor =  mix(fragColor, vec4(1.,0.,0,0), bassFader);
    fragColor =  mix(fragColor, vec4(0.,1.,0,0), midFader);
    fragColor =  mix(fragColor, vec4(0.,0.,1,0), trebFader);

    float speed = 0.0225;
    vec2 rotate_uv = rotozoom(uv, -2.*fader.y*speed, 1., aspect);
    vec2 bipolar_uv = uv_bipolar(0.5 + (rotate_uv-0.5)*2.33*aspect , vec2(0.5,0.), vec2(0.0,0.5), 2., 0.3, fader.xz*speed);
    bipolar_uv = wrap_flip(bipolar_uv);

    fragColor =  mix(fragColor, vec4(1), BlurA(uv, 0));
    int n = 2;
    for(int i = 0; i < n; i++){
        rotate_uv = rotozoom(bipolar_uv, fader.y*speed, 1., vec2(1));
        bipolar_uv = uv_bipolar(0.5 + (rotate_uv-0.5)*2.33*aspect , vec2(0.5,0.), vec2(0.0,0.5), 2., 0.3, fader.xz*speed);
        bipolar_uv = wrap_flip(bipolar_uv);
        fragColor =  mix(fragColor, vec4(1), BlurA(bipolar_uv, 0));
    }

    vec4 C12 = Cell(12);
    vec4 C13 = Cell(13);
    vec2 s0 = C12.xy;
    vec2 s1 = C12.zw;
    vec2 s2 = C13.xy;
    vec2 s = C13.zw;

    bassBox = unit_square(0.5 + (uv+s1) * 64. * aspect);
    midBox = unit_square(0.5 + (uv+s0) * 64. * aspect);
    trebBox = unit_square(0.5 + (uv+s2) * 64. * aspect);
    fragColor =  mix(fragColor, vec4(1.,0.,0,0), bassBox);
    fragColor =  mix(fragColor, vec4(0.,1.,0,0), midBox);
    fragColor =  mix(fragColor, vec4(0.,0.,1,0), trebBox);

    vec4 C25 = Cell(25);
    float box = unit_square((uv-vec2(0.95, 0.5 + C25.x)) * 64. * aspect);
    fragColor =  mix(fragColor, vec4(0.,1.,1,0), box);
    box = unit_square((uv-vec2(0.93, 0.5 + C25.y)) * 64. * aspect);
    fragColor =  mix(fragColor, vec4(0.,1.,1,0), box);
    box = unit_square((uv-vec2(0.91, 0.5 + C25.z)) * 64. * aspect);
    fragColor =  mix(fragColor, vec4(0.,1.,1,0), box);
    box = unit_square((uv-vec2(0.89, 0.5 + C25.w)) * 64. * aspect);
    fragColor =  mix(fragColor, vec4(0.,1.,1,0), box);
    float puller = (integratedVolume.x - integratedVolume.z)/2.;
    box = unit_square((uv-vec2(0.97, 0.5 + puller)) * 64. * aspect);
    fragColor =  mix(fragColor, vec4(0.,1.,1,0), box);

    fragColor = mix(fragColor, vec4(1), rainbowSpectra(uv, iChannel3)*((1.-beat_relative)*0.75+0.25));

    vec4 vol = Cell(9);
    float beat = vol.x;
    vec4 C22 = Cell(22);
    vec4 C23 = Cell(23);
    vec2 p_bass = C12.xy;
    vec2 p_mid = C12.zw;
    vec2 p_treb = C13.xy;
    vec2 p_vol = C13.zw;

    float c4 = smoothcircle(uv_aspect - aspect.yx*0.5 + p_bass*aspect.yx, aspect, 0.0025, 800.);
    float c5 = smoothcircle(uv_aspect - aspect.yx*0.5 + p_mid*aspect.yx, aspect, 0.0025, 800.);
    float c6 = smoothcircle(uv_aspect - aspect.yx*0.5 + p_treb*aspect.yx, aspect, 0.0025, 800.);

    float c8 = smoothcircle(uv, aspect, 0.25, 800.)*0.;

    fragColor =  mix(fragColor, vec4(1), c8*0.166);

    vec4 C26 = Cell(26);
    vec2 fractalSwimmerUv = fract(0.5 + (uv-0.5)*1. + C26.xy);
    fragColor =  mix(fragColor, vec4(1.15), BlurB(fractalSwimmerUv, 0).y*0.66 * unit_square(fractalSwimmerUv));
    fragColor =  mix(fragColor, vec4(1), - BlurB(fractalSwimmerUv, 2).y* unit_square(fractalSwimmerUv)*1.33);

    fragColor =  mix(fragColor, vec4(1.-c8), c1*0.5);
    fragColor =  mix(fragColor, vec4(1.-c8), c2*0.66);
    fragColor =  mix(fragColor, vec4(1.-c8), c3*0.75);

    fragColor =  mix(fragColor, vec4(1,1,0,0), c4);
    fragColor =  mix(fragColor, vec4(1,0,1,0), c5);
    fragColor =  mix(fragColor, vec4(0,1,1,0), c6);

    vec4 p1 = Cell(14);
    vec4 p2 = Cell(15);
    vec4 p3 = Cell(16);
    vec4 p4 = Cell(18);

    float c_p1 = smoothcircle(uv_aspect - aspect.yx*0.5 + p1.xy*aspect.yx, aspect, 0.0025, 800.);
    float c_p2 = smoothcircle(uv_aspect - aspect.yx*0.5 + p2.xy*aspect.yx, aspect, 0.0025, 800.);
    float c_p3 = smoothcircle(uv_aspect - aspect.yx*0.5 + p3.xy*aspect.yx, aspect, 0.0025, 800.);
    float c_p4 = smoothcircle(uv_aspect - aspect.yx*0.5 + p4.xy*aspect.yx, aspect, 0.0025, 800.);

    fragColor =  mix(fragColor, vec4(1,0,0,0), c_p1);
    fragColor =  mix(fragColor, vec4(0,0,1,0), c_p2);
    fragColor =  mix(fragColor, vec4(0,1,0,0), c_p3);
    fragColor =  mix(fragColor, vec4(1), c_p4);

    fragColor =  mix(fragColor, fragColor*vec4(2.,1.,0,0), beat*0.);

    overlaySpline(fragColor, uv, vec4(1,1,0,0.618), p_bass.xy, p1.xy, p2.xy, iResolution);
    overlaySpline(fragColor, uv, vec4(1,0,1,0.618), p_mid.xy, p1.xy, p2.xy, iResolution);
    overlaySpline(fragColor, uv, vec4(0,1,1,0.618), p_treb.xy, p1.xy, p2.xy, iResolution);
    overlaySpline(fragColor, uv, vec4(1,1,1,0.618), p2.xy, p3.xy, p4.xy, iResolution);
}
