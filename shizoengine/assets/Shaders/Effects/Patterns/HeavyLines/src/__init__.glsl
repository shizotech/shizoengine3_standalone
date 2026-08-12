//@settings dtype=float32 format=rgba

float hash11(float p) {
    p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash12(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
    p3  = fract(p3 * .1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float hash14(vec4 p4) {
    p4 = fract(p4  * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.x + p4.y) * (p4.z + p4.w));
}

vec2 hash21(float p) {
    vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}

vec2 hash23(vec3 p3) {
    p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}

vec3 hash31(float p) {
    vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.xxy+p3.yzz)*p3.zyx);
}

vec3 hash32(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy+p3.yzz)*p3.zyx);
}

vec3 hash33(vec3 p3) {
    p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy + p3.yxx)*p3.zyx);
}

vec4 hash41(float p) {
    vec4 p4 = fract(vec4(p) * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);
}

vec4 hash42(vec2 p) {
    vec4 p4 = fract(vec4(p.xyxy) * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);
}

vec4 hash43(vec3 p) {
    vec4 p4 = fract(vec4(p.xyzx)  * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);
}

vec4 hash44(vec4 p4) {
    p4 = fract(p4  * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);
}

mat2 rotate(float a) {
    return mat2(sin(a), cos(a),
               -cos(a), sin(a));
}

// Variant A: Object pattern overlay
//@slider min=1.0 max=8.0 value=8.0
uniform float maxIterations = 8.0;
//@slider min=0.0 max=1.0 value=0.15
uniform float overlayStrength = 0.15;
//@slider min=0.0 max=2.0 value=1.0
uniform float timeMultiplier = 1.0;

void mainImage( out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord/iResolution.xy;
    vec2 p = (2.0 * uv - 1.0) * vec2(iResolution.x/iResolution.y, 1.0);

    vec3 color = vec3(0.0);
    float t = iTime * timeMultiplier;
    int iterations = int(min(t + 1.0, maxIterations));
    for (int i = 1; i < iterations; i++) {
        float id = float(i);
        float radius = hash11(id);
        float objTime = t + hash11(id * 321.0 + 123.0);
        vec2 offset = 4.0 * (vec2(hash11(floor(objTime) + id), 0.0) - vec2(0.5, 0.0));
        vec2 position = p + offset;
        position *= rotate(hash11(floor(objTime) * 3.256) + id + floor(objTime));
        float objShape = abs(position.x);
        float lifeTime = mod(objTime, 1.0);
        float objSize = (smoothstep(0.0, 0.05, lifeTime) * smoothstep(1.0, 0.0, lifeTime)) * 0.05;
        float objMask = step(objShape, objSize);
        vec3 objColor = 0.5 * vec3(0.25, 0.5, 0.25) + hash31(id) * vec3(1.0, 0.1, 0.75);
        color = mix(color, objColor, objMask);
    }
    fragColor = texture(iChannel0, uv) * overlayStrength + vec4(color, 1.0);
}
