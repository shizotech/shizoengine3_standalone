// Shader that generates a dynamic visual effect
// Audio-reactive using iChannel0 for frequency data

// Frequency values for different layers
float frequencies[16];
const vec2 zeroOne = vec2(0.0, 1.0);
const float PI = 3.141592653589793238;

// Rotate 2D vector by an angle
mat2 rotate2d(float angle) {
    return mat2(cos(angle), -sin(angle),
                sin(angle), cos(angle));
}

// 2D Hash function
float hash2d(vec2 uv) {
    float f = uv.x + uv.y * 47.0;
    return fract(cos(f * 3.333) * 100003.9);
}

// 3D Hash function
float hash3d(vec3 uv) {
    float f = uv.x + uv.y * 37.0 + uv.z * 521.0;
    return fract(cos(f * 3.333) * 100003.9);
}

// Smoothly interpolate between two values
float smoothInterpolation(float f0, float f1, float a) {
    return mix(f0, f1, a * a * (3.0 - 2.0 * a));
}

// 2D Perlin noise function
float noise2d(vec2 uv) {
    vec2 fractUV = fract(uv.xy);
    vec2 floorUV = floor(uv.xy);
    float h00 = hash2d(floorUV);
    float h10 = hash2d(floorUV + zeroOne.yx);
    float h01 = hash2d(floorUV + zeroOne);
    float h11 = hash2d(floorUV + zeroOne.yy);
    return smoothInterpolation(
        smoothInterpolation(h00, h10, fractUV.x),
        smoothInterpolation(h01, h11, fractUV.x),
        fractUV.y
    );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord / iResolution.xy) * 2.0 - 1.0;
    float aspectRatio = iResolution.x / iResolution.y;
        
    if (aspectRatio > 1.0) {
       // Landscape orientation
       uv.x *= aspectRatio;
       uv.xy *= iResolution.y / iResolution.x;
    } else {
       // Portrait orientation
       uv.y /= aspectRatio;
       uv.xy *= iResolution.x / iResolution.y;
    }
    
    vec2 uv2 = uv;
    uv2.xy *= 4.5;

    float time = iTime + (2.0 * frequencies[0]);

    vec3 color = vec3(0.0);
    vec3 color2 = vec3(0.0);

    for (int i = 0; i < 16; i++) {
        frequencies[i] = clamp(1.75 * pow(texture(iChannel0, vec2(0.05 + 0.5 * float(i) / 16.0, 0.25)).x, 4.0), 0.0, 1.0);

        float wave = sqrt(sin((-(frequencies[i] * noise2d(uv * 3.5 + vec2(rotate2d(iTime)).xy)) * PI) + ((uv2.x * uv2.x) + (uv2.y * uv2.y))));

        vec2 rotatedUV = rotate2d(iTime) * (uv * 1.75);

        wave = smoothstep(0.8, 1.0, wave);
        color2 += wave * (vec3(rotatedUV.x, rotatedUV.y, 1.7 - rotatedUV.y * rotatedUV.x) * 0.08) * frequencies[i];

        wave = smoothstep(0.99999, 1.0, wave);
        color2 += wave * vec3(0.2);
    }

    fragColor = vec4(color2, 1.0);
}
