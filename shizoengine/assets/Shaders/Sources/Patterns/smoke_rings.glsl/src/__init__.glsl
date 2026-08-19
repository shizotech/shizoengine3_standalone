

//@settings dtype=float32 format=rgba

const float falloffPower = 0.3;
float halfWidth = pow(0.03, falloffPower);
const float radius = 0.38;
const vec2 noiseSampleDirection = vec2(1.0, 0.319);

float waves(vec2 coord, vec2 coordMul1, vec2 coordMul2, vec2 phases, vec2 timeMuls) {
    return 0.5 * (sin(dot(coord, coordMul1) + timeMuls.x * iTime + phases.x) + cos(dot(coord, coordMul2) + timeMuls.y * iTime + phases.y));
}

float ringMultiplier(vec2 coord, float distortAmount, float phase, float baseXOffset) {
    vec2 sampleLocation1 = noiseSampleDirection * phase;
    vec2 sampleLocation2 = vec2(1.0, 0.8) - noiseSampleDirection * phase;
    vec3 noise1 = texture(iChannel0, sampleLocation1).rgb;
    vec3 noise2 = texture(iChannel0, sampleLocation2).rgb;
    
    float distortX = baseXOffset + 0.6 * waves(coord, vec2(1.9 + 0.4 * noise1.r, 1.9 + 0.4 * noise1.g) * 3.3, vec2(5.7 + 1.4 * noise1.b, 5.7 + 1.4 * noise2.r) * 2.8, vec2(noise1.r - noise2.r, noise1.g + noise2.b) * 5.0, vec2(1.1));
    float distortY = 0.5 + 0.7 * waves(coord, vec2(-1.7 - 0.9 * noise2.g, 1.7 + 0.9 * noise2.b) * 3.1, vec2(5.9 + 0.8 * noise1.g, -5.9 - 0.8 * noise1.b) * 3.7, vec2(noise1.g + noise2.g, noise1.b - noise2.r) * 5.0, vec2(-0.9));
    float amount = 0.2 + 0.3 * (abs(distortX) + abs(distortY));
    vec2 distortedCoord = coord + normalize(vec2(distortX, distortY)) * amount * distortAmount * 0.2;
    return smoothstep(-halfWidth,halfWidth, pow(abs(length(distortedCoord) - radius), falloffPower));
}

#define RING_COUNT 30

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = vec2(0.5) - fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;
    vec3 accumulatedColor = vec3(1.0);
    const vec3 tint1 = vec3(0.1, 0.5, 0.4);
    const vec3 tint2 = vec3(0.4, 0.7, 0.2);
    
    float baseXOffset = 0.5 * (0.6 * cos(iTime * 0.3 + 1.1) + 0.4 * cos(iTime * 1.2));
    for (int i = 0; i < RING_COUNT; i++) {
        float ringsFraction = float(i) / float(RING_COUNT);
        float amount = ringMultiplier(uv, 0.1 + pow(ringsFraction, 3.0) * 0.7, pow(1.0 - ringsFraction,0.3) * 0.09 + iTime * 0.0001, baseXOffset);
        accumulatedColor *= mix(mix(tint1, tint2, pow(ringsFraction, 3.0)), vec3(1.0), pow(amount, 2.0));
    }
	fragColor = vec4(accumulatedColor, 1.0);
}

