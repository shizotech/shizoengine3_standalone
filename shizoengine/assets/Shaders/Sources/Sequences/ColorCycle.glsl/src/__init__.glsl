 // ColorCycle - Full RGB color cycling animation
// Animates through the color spectrum using multiple patterns:
// HSL Wheel, Rainbow, Fade, Pulse
//
// ==== Custom Uniform Controls ====

//@float min=0.01 max=3.0 value=0.5
uniform float speed;

//@enum options=(HSL Wheel, Rainbow, Fade, Pulse)
uniform int pattern;

// Standard hash function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Convert HSL to RGB
// h: hue (0.0-1.0), s: saturation (0.0-1.0), l: lightness (0.0-1.0)
vec3 hsl2rgb(float h, float s, float l) {
    vec3 rgb = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return l + s * (rgb - 0.5) * (1.0 - abs(2.0 * l - 1.0));
}

// Pattern 1: HSL Wheel - smoothly rotates through the entire hue spectrum
vec3 pattern_hsl_wheel(float t) {
    float hue = fract(t); // 0.0 to 1.0 cycles through full hue wheel
    float sat = 0.8 + 0.2 * sin(t * 3.14159);
    float lit = 0.5 + 0.3 * sin(t * 1.5708);
    return hsl2rgb(hue, sat, lit);
}

// Pattern 2: Rainbow - classic rainbow gradient cycling
vec3 pattern_rainbow(float t) {
    // Classic rainbow: red(0), yellow(0.16), green(0.33), cyan(0.5), blue(0.66), magenta(0.83)
    float hue = fract(t);
    vec3 color;
    if (hue < 0.166) {
        color = mix(vec3(1.0, 0.0, 0.0), vec3(1.0, 1.0, 0.0), hue / 0.166);
    } else if (hue < 0.333) {
        color = mix(vec3(1.0, 1.0, 0.0), vec3(0.0, 1.0, 0.0), (hue - 0.166) / 0.167);
    } else if (hue < 0.5) {
        color = mix(vec3(0.0, 1.0, 0.0), vec3(0.0, 1.0, 1.0), (hue - 0.333) / 0.167);
    } else if (hue < 0.666) {
        color = mix(vec3(0.0, 1.0, 1.0), vec3(0.0, 0.0, 1.0), (hue - 0.5) / 0.166);
    } else if (hue < 0.833) {
        color = mix(vec3(0.0, 0.0, 1.0), vec3(1.0, 0.0, 1.0), (hue - 0.666) / 0.167);
    } else {
        color = mix(vec3(1.0, 0.0, 1.0), vec3(1.0, 0.0, 0.0), (hue - 0.833) / 0.167);
    }
    return color;
}

// Pattern 3: Fade - smoothly fades between primary and secondary colors
vec3 pattern_fade(float t) {
    float phase = sin(t * 3.14159) * 0.5 + 0.5; // 0.0 to 1.0

    // Blend between primary colors in a cycle: red -> green -> blue -> red
    vec3 color;
    if (phase < 0.333) {
        color = mix(vec3(1.0, 0.2, 0.2), vec3(0.2, 1.0, 0.2), phase / 0.333);
    } else if (phase < 0.666) {
        color = mix(vec3(0.2, 1.0, 0.2), vec3(0.2, 0.4, 1.0), (phase - 0.333) / 0.333);
    } else {
        color = mix(vec3(0.2, 0.4, 1.0), vec3(1.0, 0.2, 0.2), (phase - 0.666) / 0.334);
    }

    // Add a subtle brightness pulse
    float brightness = 0.8 + 0.2 * sin(t * 6.28318);
    return color * brightness;
}

// Pattern 4: Pulse - energetic pulsing color effect
vec3 pattern_pulse(float t) {
    // Fast pulsing between vibrant colors
    float pulse_phase = fract(t * 0.5); // Slower overall cycle
    float pulse_speed = sin(t * 12.566) * 0.5 + 0.5; // Fast pulse

    // Generate pulsing hue
    float hue = fract(t * 0.2) + pulse_speed * 0.1;
    hue = fract(hue);

    vec3 base = hsl2rgb(hue, 0.9, 0.5);

    // Apply sharp pulse effect
    float pulse = pow(pulse_speed, 3.0); // Sharpen the pulse
    return mix(base * 0.4, base, pulse);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalize coordinates
    vec2 uv = fragCoord / iResolution.xy;

    // Calculate animation parameter based on time and speed
    float anim_time = iTime * speed;

    // Select pattern based on enum value
    vec3 final_color;
    if (pattern == 0) {
        final_color = pattern_hsl_wheel(anim_time);
    } else if (pattern == 1) {
        final_color = pattern_rainbow(anim_time);
    } else if (pattern == 2) {
        final_color = pattern_fade(anim_time);
    } else {
        final_color = pattern_pulse(anim_time);
    }

    // Fill the entire screen with the cycling color
    fragColor = vec4(final_color, 1.0);
}
