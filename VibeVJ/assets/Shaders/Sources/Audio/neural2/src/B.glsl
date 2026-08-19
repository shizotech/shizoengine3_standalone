//@settings dtype=float32 format=rgba

// Visualization of neural2 buffer data
// Fork of "Buffer computed points." by patu. https://shadertoy.com/view/XllBRj
// Reads data from the first pass (A pass), auto-bound as iChannel0

float SqDistancePtSegment(vec2 a, vec2 b, vec2 p)
{
    vec2
        pa = p - a,
        ba = b - a,
        d = pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);

    return dot(d, d);
}

void mainImage(out vec4 F, in vec2 fragCoord)
{
	vec2 uv = fragCoord.xy / iResolution.xy;

    uv.x -= .5;
    uv.x *= iResolution.x / iResolution.y;
    uv.x += .75;

	F = vec4(0.0);

    vec2 u = uv;

    for (int y = 0; y < 64; y++) {
        vec4 c1 = texelFetch(iChannel0, ivec2(0, y), 0); // data from pass A 1st column
        vec4 c2 = texelFetch(iChannel0, ivec2(1, y), 0); // data from pass A 2nd column

        // pass A column 3 contains volume data
        float volc = round(pow(texelFetch(iChannel0, ivec2(2, y), 0).r, 4.) * 1.7) * c2.w * 2.;

        F = mix(F, abs(c1.xyzx) * 1.1 * volc, smoothstep(0., 1., 1. / length(uv - c1.xy) * .008));
        F = mix(F, abs(c2.xyzx) * 1.1 * volc, smoothstep(0., 1., 1. / length(uv - c2.xy) * .005));

        F += abs(c1.xyzx) * .4 * volc * smoothstep(0., 1., 1. / length(uv - c1.xy) * .15) * .1;

        // segment
        F = mix(F, abs(mix(c1.xyzw, c2.xyzx, .5)) * volc, (1. - smoothstep(0.0, .00001, SqDistancePtSegment(c1.xy, c2.xy, uv))) * 1.);
    }
}
