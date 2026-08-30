// ==== Custom Uniform Controls ====

//@enum options=(Radial,Linear)
uniform int clone_mode;

//@int min=1 max=64 value=8
uniform int clone_count;

//@float min=-360.0 max=360.0 value=45.0
uniform float rotation_step;

//@float min=0.5 max=2.0 value=1.0
uniform float scale_step;

//@vec2 min=(-1.0,-1.0) max=(1.0,1.0) value=(0.2,0.0)
uniform vec2 linear_offset;

//@vec2 min=(0.0,0.0) max=(1.0,1.0) value=(0.5,0.5)
uniform vec2 pivot;

//@float min=0.0 max=1.0 value=0.9
uniform float fadeout;

//@float min=-360.0 max=360.0 value=0.0
uniform float base_rotation;

//@int min=0 max=1 value=0
uniform int blend_mode;

//@float min=0.1 max=5.0 value=1.0
uniform float input_zoom;

//@float min=0.0 max=1.0 value=0.0
uniform float clone_scale_jitter;

//@float min=0.0 max=1.0 value=0.0
uniform float clone_rotation_jitter;

//@float min=0.0 max=1.0 value=0.0
uniform float clone_opacity_randomness;

//@enum options=(None,Horizontal,Vertical,Both)
uniform int mirror_clones;

//@float min=-2.0 max=2.0 value=0.0
uniform float animate_rotation;

//@enum options=(Clamp,Repeat)
uniform int texture_repeat;

//@float min=0.0 max=2.0 value=1.0
uniform float input_gain;

//@float min=0.0 max=2.0 value=0.0
uniform float vignette_strength;

//@enum options=(Uniform,Offset)
uniform int rotation_mode;

//@enum options=(Spiral,Symmetrical)
uniform int radial_mode;

#define PI 3.14159265359

mat2 rotate(float angle) {
    float s = sin(angle), c = cos(angle);
    return mat2(c, -s, s, c);
}

// Simple hash to generate randomness per clone
float hash(float n) {
    return fract(sin(n * 91.3458) * 47453.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 center = pivot;

    vec4 color = vec4(0.0);
    float baseRot = radians(base_rotation + animate_rotation * iTime);

    for (int i = 0; i < 128; i++) {
        if (i >= clone_count) break;

        float t = float(i);

        // Jitter and randomness
        float randSeed = hash(t);
        float scaleJitter = 1.0 + (hash(t + 1.0) - 0.5) * clone_scale_jitter;
        float rotJitter = (hash(t + 2.0) - 0.5) * clone_rotation_jitter;
        float alphaRand = mix(1.0, hash(t + 3.0), clone_opacity_randomness);

        float alpha = pow(fadeout, t) * alphaRand;

        vec2 transformedUV = (uv - center) / input_zoom;

        float angle;
        if (radial_mode == 0) {
            angle = radians(t * rotation_step + rotJitter);
        } else {
            angle = radians(360.0 * t / float(clone_count)) + rotJitter;
        }

        if (rotation_mode == 0) {
            angle += baseRot;
        } else {
            angle += baseRot + radians(float(i) * 5.0); // Slight offset per clone
        }

        float scale = pow(scale_step, t) * scaleJitter;

        if (clone_mode == 0) {
            // Radial mode
            transformedUV *= rotate(angle);
        } else {
            // Linear mode
            transformedUV += t * linear_offset;
        }

        transformedUV /= scale;

        // Mirror
        if (mirror_clones == 1 || mirror_clones == 3) transformedUV.x = abs(transformedUV.x);
        if (mirror_clones == 2 || mirror_clones == 3) transformedUV.y = abs(transformedUV.y);

        transformedUV += center;

        // Apply clamping or wrapping
        if (texture_repeat == 0) {
            if (any(lessThan(transformedUV, vec2(0.0))) || any(greaterThan(transformedUV, vec2(1.0)))) continue;
        } else {
            transformedUV = fract(transformedUV);
        }

        vec4 sample = texture(iChannel0, transformedUV) * input_gain;

        // Apply vignette per sample
        if (vignette_strength > 0.0) {
            vec2 dist = transformedUV - vec2(0.5);
            float vignette = smoothstep(0.75, vignette_strength + 0.75, length(dist) * sqrt(2.0));
            sample.rgb *= 1.0 - vignette;
        }

        if (blend_mode == 0) {
            color = mix(color, sample, alpha);
        } else {
            color += sample * alpha;
        }
    }

    if (blend_mode == 1) color = clamp(color, 0.0, 1.0);

    fragColor = color;
}
