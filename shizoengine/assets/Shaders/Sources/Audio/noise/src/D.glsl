//@settings dtype=float32 format=rgba

#include helpers/shared.glsl

// Vertical blur (second pass)
// Physics simulation + beat detection - stores cell data in buf D

vec4 blur_vertical_upper_left(sampler2D channel, vec2 uv)
{
    float v = 1. / iResolution.y;
    vec4 sum = vec4(0.0);
    sum += texture(channel, upper_left(vec2(uv.x, uv.y - 4.0*v)) ) * 0.0162162162;
    sum += texture(channel, upper_left(vec2(uv.x, uv.y - 3.0*v)) ) * 0.0540540541;
    sum += texture(channel, upper_left(vec2(uv.x, uv.y - 2.0*v)) ) * 0.1216216216;
    sum += texture(channel, upper_left(vec2(uv.x, uv.y - 1.0*v)) ) * 0.1945945946;
    sum += texture(channel, upper_left(vec2(uv.x, uv.y + 0.0*v)) ) * 0.2270270270;
    sum += texture(channel, upper_left(vec2(uv.x, uv.y + 1.0*v)) ) * 0.1945945946;
    sum += texture(channel, upper_left(vec2(uv.x, uv.y + 2.0*v)) ) * 0.1216216216;
    sum += texture(channel, upper_left(vec2(uv.x, uv.y + 3.0*v)) ) * 0.0540540541;
    sum += texture(channel, upper_left(vec2(uv.x, uv.y + 4.0*v)) ) * 0.0162162162;
    return sum;
}

vec4 blur_vertical_lower_left(sampler2D channel, vec2 uv)
{
    float v = 1. / iResolution.y;
    vec4 sum = vec4(0.0);
    sum += texture(channel, lower_left(vec2(uv.x, uv.y - 4.0*v)) ) * 0.0162162162;
    sum += texture(channel, lower_left(vec2(uv.x, uv.y - 3.0*v)) ) * 0.0540540541;
    sum += texture(channel, lower_left(vec2(uv.x, uv.y - 2.0*v)) ) * 0.1216216216;
    sum += texture(channel, lower_left(vec2(uv.x, uv.y - 1.0*v)) ) * 0.1945945946;
    sum += texture(channel, lower_left(vec2(uv.x, uv.y + 0.0*v)) ) * 0.2270270270;
    sum += texture(channel, lower_left(vec2(uv.x, uv.y + 1.0*v)) ) * 0.1945945946;
    sum += texture(channel, lower_left(vec2(uv.x, uv.y + 2.0*v)) ) * 0.1216216216;
    sum += texture(channel, lower_left(vec2(uv.x, uv.y + 3.0*v)) ) * 0.0540540541;
    sum += texture(channel, lower_left(vec2(uv.x, uv.y + 4.0*v)) ) * 0.0162162162;
    return sum;
}

vec4 blur_vertical_left_column(vec2 uv, int depth)
{
    float v = pow(2., float(depth)) / iResolution.y;

    vec2 uv1, uv2, uv3, uv4, uv5, uv6, uv7, uv8, uv9;

    uv1 = fract(vec2(uv.x, uv.y - 4.0*v) * 2.);
    uv2 = fract(vec2(uv.x, uv.y - 3.0*v) * 2.);
    uv3 = fract(vec2(uv.x, uv.y - 2.0*v) * 2.);
    uv4 = fract(vec2(uv.x, uv.y - 1.0*v) * 2.);
    uv5 = fract(vec2(uv.x, uv.y + 0.0*v) * 2.);
    uv6 = fract(vec2(uv.x, uv.y + 1.0*v) * 2.);
    uv7 = fract(vec2(uv.x, uv.y + 2.0*v) * 2.);
    uv8 = fract(vec2(uv.x, uv.y + 3.0*v) * 2.);
    uv9 = fract(vec2(uv.x, uv.y + 4.0*v) * 2.);

    if(uv.x < 0.5)
    {
        if(uv.y > 0.5)
        {
            uv1 = upper_left(uv1);
            uv2 = upper_left(uv2);
            uv3 = upper_left(uv3);
            uv4 = upper_left(uv4);
            uv5 = upper_left(uv5);
            uv6 = upper_left(uv6);
            uv7 = upper_left(uv7);
            uv8 = upper_left(uv8);
            uv9 = upper_left(uv9);
        }
        else
        {
            uv1 = lower_left(uv1);
            uv2 = lower_left(uv2);
            uv3 = lower_left(uv3);
            uv4 = lower_left(uv4);
            uv5 = lower_left(uv5);
            uv6 = lower_left(uv6);
            uv7 = lower_left(uv7);
            uv8 = lower_left(uv8);
            uv9 = lower_left(uv9);
        }
    }
    else
    {
        vec2 uv_s = upper_right(uv*2.)*2.;
        uv1 = clamp(vec2(uv_s.x, uv_s.y - 4.0*v), 0., 1.);
        uv2 = clamp(vec2(uv_s.x, uv_s.y - 3.0*v), 0., 1.);
        uv3 = clamp(vec2(uv_s.x, uv_s.y - 2.0*v), 0., 1.);
        uv4 = clamp(vec2(uv_s.x, uv_s.y - 1.0*v), 0., 1.);
        uv5 = clamp(vec2(uv_s.x, uv_s.y + 0.0*v), 0., 1.);
        uv6 = clamp(vec2(uv_s.x, uv_s.y + 1.0*v), 0., 1.);
        uv7 = clamp(vec2(uv_s.x, uv_s.y + 2.0*v), 0., 1.);
        uv8 = clamp(vec2(uv_s.x, uv_s.y + 3.0*v), 0., 1.);
        uv9 = clamp(vec2(uv_s.x, uv_s.y + 4.0*v), 0., 1.);
        depth--;
        uv1 = upper_right(uv1);
        uv2 = upper_right(uv2);
        uv3 = upper_right(uv3);
        uv4 = upper_right(uv4);
        uv5 = upper_right(uv5);
        uv6 = upper_right(uv6);
        uv7 = upper_right(uv7);
        uv8 = upper_right(uv8);
        uv9 = upper_right(uv9);
    }
    for(int level = 0; level < 8; level++)
    {
        if(level > depth)
        {
            break;
        }

        uv1 = lower_right(uv1);
        uv2 = lower_right(uv2);
        uv3 = lower_right(uv3);
        uv4 = lower_right(uv4);
        uv5 = lower_right(uv5);
        uv6 = lower_right(uv6);
        uv7 = lower_right(uv7);
        uv8 = lower_right(uv8);
        uv9 = lower_right(uv9);
    }

    vec4 sum = vec4(0.0);
    if(uv.x > 0.5 && uv.y > 0.5)
    {
        sum += texture(iChannel3, uv1) * 0.0162162162;
        sum += texture(iChannel3, uv2) * 0.0540540541;
        sum += texture(iChannel3, uv3) * 0.1216216216;
        sum += texture(iChannel3, uv4) * 0.1945945946;
        sum += texture(iChannel3, uv5) * 0.2270270270;
        sum += texture(iChannel3, uv6) * 0.1945945946;
        sum += texture(iChannel3, uv7) * 0.1216216216;
        sum += texture(iChannel3, uv8) * 0.0540540541;
        sum += texture(iChannel3, uv9) * 0.0162162162;
    }
    else
    {
        sum += texture(iChannel2, uv1) * 0.0162162162;
        sum += texture(iChannel2, uv2) * 0.0540540541;
        sum += texture(iChannel2, uv3) * 0.1216216216;
        sum += texture(iChannel2, uv4) * 0.1945945946;
        sum += texture(iChannel2, uv5) * 0.2270270270;
        sum += texture(iChannel2, uv6) * 0.1945945946;
        sum += texture(iChannel2, uv7) * 0.1216216216;
        sum += texture(iChannel2, uv8) * 0.0540540541;
        sum += texture(iChannel2, uv9) * 0.0162162162;
    }
    return sum;
}

void set_cell(inout vec4 bufD, vec2 uv, int index, vec4 value)
{
    // map the index to the cell in the array
    float x = mod(float(index), N) / N;
    float y = floor(float(index) / N) / N;

    // compartmentalization
    vec2 cell_size = (p2 - p1) / N;
    vec2 center = p1 + cell_size*0.5 + (p2-p1)*vec2(x,y);

    // store
    if(abs(uv - center).x <= cell_size.x*0.5 && abs(uv - center).y <= cell_size.y*0.5)
    {
        bufD = value;
    }
}

void spring(float force, inout vec4 p1, inout vec4 p2) {
    vec2 f = (p2.xy-p1.xy) * force;
    p1.zw += f;
    p2.zw -= f;
}

void resist(float friction, inout vec4 p){
    float dampeningFactor = 0.9;
    // hit right border
    if(p.x > 1. && p.z > 0.){
        p.z = - p.z * dampeningFactor;
    }
    // hit left border
    if(p.x < 0. && p.z < 0.){
        p.z = - p.z * dampeningFactor;
    }
    // hit lower border
    if(p.y < 0. && p.w < 0.){
        p.w = - p.w * dampeningFactor;
    }
    // hit upper border
    if(p.y > 1. && p.w > 0.){
        p.w = - p.w * dampeningFactor;
    }

    friction = max(0., 1. - length(p.zw)*friction);
    p.zw *= friction;
}

vec4 vol(int t){
    float lo = bass(t, iChannel3);
    float mi = mid(t, iChannel3);
    float hi = treb(t, iChannel3);
    return vec4(lo, mi, hi, (lo + mi + hi)*0.333);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 pixelSize = 1./iResolution.xy;
    vec2 uv = fragCoord.xy * pixelSize;
    vec2 uv_orig = uv;
    vec2 uv_half = fract(uv*2.);
    if(uv.x < 0.5)
    {
        if(uv.y > 0.5)
        {
            fragColor = blur_vertical_upper_left(iChannel2, uv_half);
        }
        else
        {
            fragColor = blur_vertical_lower_left(iChannel2, uv_half);
        }
    }
    else
    {
        for(int level = 0; level < 8; level++)
        {
            if((uv.x > 0.5 && uv.y >= 0.5) || (uv.x < 0.5))
            {
                break;
            }
            vec2 uv_half = fract(uv*2.);
            fragColor = blur_vertical_left_column(uv_half, level);
            uv = uv_half;
        }
        uv_half = fract(uv_orig*2.);

        if(uv_orig.y > 0.5)
        {
            if(uv_half.x < pixelSize.x *128.)
            {
                fragColor = texture(iChannel1, uv_half.yx);
            }else{
                fragColor = texture(iChannel3, uv_orig - vec2(64.,0.) * pixelSize);
            }
        }
    }

    // volume from current frame and one frame ago
    vec4 v0 = vol(0, iChannel3);
    vec4 v0_prev = Cell(20, iChannel3);
    vec4 v1 = vol(1);

    set_cell(fragColor, uv, 0, v0);
    set_cell(fragColor, uv, 1, v1);
    set_cell(fragColor, uv, 2, vec4(iMouse.xy * pixelSize, iMouse.zw * pixelSize));

    vec4 v2 = vol(2);
    vec4 attack = v2 + v0 - 2.*v1;
    set_cell(fragColor, uv, 3, attack);

    vec4 old_beat_residual = Cell(4, iChannel3);
    vec4 beat_residual = old_beat_residual*0.96 + max(attack*4., 0.);
    set_cell(fragColor, uv, 4, beat_residual);
    set_cell(fragColor, uv, 5, old_beat_residual);

    attack = beat_residual - old_beat_residual;
    set_cell(fragColor, uv, 6, attack );

    vec4 last_beat_min = Cell(7, iChannel3);
    vec4 last_beat_max = Cell(8, iChannel3);

    float frames_since_last_beat = Cell(9, iChannel3).y;
    bool beat = (v0.w-v0_prev.w)*2. > 4./frames_since_last_beat;
    beat = beat && (frames_since_last_beat > 15.);

    vec4 noise = texture(iChannel0, fragCoord.xy / iChannelResolution[0].xy + fract(vec2(42,56)*iTime));

    if(beat)
    {
        set_cell(fragColor, uv, 7, old_beat_residual);
        set_cell(fragColor, uv, 8, beat_residual);
        set_cell(fragColor, uv, 11, Cell(11, iChannel3));
        set_cell(fragColor, uv, 10, noise);
        frames_since_last_beat = 1.;
    }
    else
    {
        set_cell(fragColor, uv, 7, min(last_beat_min, beat_residual));
        set_cell(fragColor, uv, 8, max(last_beat_max, beat_residual));
        set_cell(fragColor, uv, 10, Cell(10, iChannel3));
        set_cell(fragColor, uv, 11, Cell(11, iChannel3));
        frames_since_last_beat += 1.;
    }

    set_cell(fragColor, uv, 9, vec4(beat, frames_since_last_beat, 0, 0));

    // #puller
    vec4 integratedVolume = Cell(19, iChannel3);
    vec4 v = integratedVolume * 0.5;
    vec2 c = vec2( 0.5, 0.5 );
    vec2 s0 = c + vec2(v.x + v0.x*0.25, +v.x - v.z- v.y);
    vec2 s1 = c + vec2(v.x - v.z, - v.y*0.5 - v0.y*0.5);
    vec2 s2 = c + vec2(-v.z - v0.z*0.25, -v.z + v.x- v.y);

    vec4 p_bass = vec4(s0, 0, 0);
    vec4 p_mid = vec4(s1, 0, 0);
    vec4 p_treb = vec4(s2, 0, 0);
    vec4 p_vol = vec4((s0 + s1 + s2)/3., 0, 0);

    set_cell(fragColor, uv, 12, vec4(p_bass.xy, p_mid.xy));
    set_cell(fragColor, uv, 13, vec4(p_treb.xy, p_vol.xy));

    vec4 p0 = Cell(17, iChannel3);
    vec4 p1 = Cell(14, iChannel3);
    vec4 p2 = Cell(15, iChannel3);
    vec4 p3 = Cell(16, iChannel3);
    vec4 p4 = Cell(18, iChannel3);

    float force = 1.;
    float friction = 0.0005;
    float speed = 0.0075;
    float grav = 0.05;

    float impactfactor = 128.;
    spring(force * impactfactor, p0, p_bass);
    spring(force * impactfactor, p0, p_mid);
    spring(force * impactfactor, p0, p_treb);
    spring(force, p0, p1);
    spring(force, p1, p2);
    spring(force, p2, p3);
    spring(force, p3, p4);

    resist(friction, p0);
    resist(friction, p1);
    resist(friction, p2);
    resist(friction, p3);
    resist(friction, p4);

    p1.w += grav;
    p2.w += grav;
    p3.w += grav;
    p4.w += grav;

    // Verlet integration
    p0.xy += p0.zw * speed;
    p1.xy += p1.zw * speed;
    p2.xy += p2.zw * speed;
    p3.xy += p3.zw * speed;
    p4.xy += p4.zw * speed;

    if(iFrame < 2){
        p0.xy = p_vol.xy;
        p1.xy = p_vol.xy;
        p2.xy = p_vol.xy;
        p3.xy = p_vol.xy;
        p4.xy = p_vol.xy;
    }

    set_cell(fragColor, uv, 17, p0);
    set_cell(fragColor, uv, 14, p1);
    set_cell(fragColor, uv, 15, p2);
    set_cell(fragColor, uv, 16, p3);
    set_cell(fragColor, uv, 18, p4);

    set_cell(fragColor, uv, 19, integratedVolume*0.92 + v0*0.1);
    set_cell(fragColor, uv, 20, v0);

    float volMin = min(integratedVolume.x, min(integratedVolume.y, integratedVolume.z));
    float volMax = max(integratedVolume.x, max(integratedVolume.y, integratedVolume.z));

    vec4 normalizedVolume = (integratedVolume - volMin*vec4(1))/(volMax - volMin);
    if(volMax - volMin != 0.){
        set_cell(fragColor, uv, 21, normalizedVolume);
        set_cell(fragColor, uv, 22, Cell(22, iChannel3) - (normalizedVolume-0.5)*1.33*iTimeDelta);
    }

    set_cell(fragColor, uv, 23, vec4(s1,s0));
    set_cell(fragColor, uv, 24, vec4(s0,s2));

    vec4 C25 = Cell(25, iChannel3); // 1D spring <s0, v0, v1, s1>
    float ff = iTimeDelta*0.75; // force factor
    float vf = 0.25; // velocity factor
    float puller = (integratedVolume.x - integratedVolume.z)/2.;
    C25.yz *= 0.99; // dampen
    // accelerate
    C25.y += (C25.w - C25.x * 2. + puller) * ff;
    C25.z += (C25.x - C25.w) * ff;
    // Verlet integration
    C25.x += C25.y * vf;
    C25.w += C25.z * vf;

    set_cell(fragColor, uv, 25, C25);

    vec4 C26 = Cell(26, iChannel3); // fractal swimmer <x, y, bending, orientation>
    vec4 C27 = Cell(27, iChannel3); // previous frame fractal swimmer
    set_cell(fragColor, uv, 27, C26);

    // now we can update C26

    float rollMoment = C26.w - C27.w;
    vec2 velocity = C26.xy - C27.xy;
    float bendForce = C26.z- C27.z;
    float forwardFriction = 0.99;
    float turnFriction = 0.99;

    float inputForce = -abs(C25.w - puller)*iTimeDelta*24.;

    vec2 velocityPolar = uv_polar(velocity, vec2(0)); // <ang, rad>

    velocityPolar.y = velocityPolar.y * forwardFriction;
    velocity = vec2(cos(velocityPolar.x), sin(velocityPolar.x)) * velocityPolar.y;

    float w = C26.w;
    velocity += vec2(cos(w), sin(w))*inputForce/256.;

    float spineBending = -(C25.x * 0.5 + C25.w* 0.5 - puller) * 2.;
    C26.z = spineBending;
    C26.xy += velocity;
    C26.w += rollMoment * turnFriction - velocityPolar.y * C26.z * 2.;

    set_cell(fragColor, uv, 26, C26);
}
