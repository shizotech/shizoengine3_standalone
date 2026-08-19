//@settings dtype=float32 format=rgba

// Cube - Raymarching SDF scene with audio-reactive FFT input

// Hue to RGB function from Fabrice's shadertoyunofficial blog:
#define hue2rgb(hue) 0.6 + 0.6 * cos(6.3 * hue + vec3(0.0, 23.0, 21.0))

float mapScene(in vec3 p) {

    
    float o1 = texture(iChannel1, vec2(.4)).x * .7,
          o2 = texture(iChannel1, vec2(.7)).x * .7;
          
    float r = iTime;
    float c = cos(r + o1), s = sin(r + o1);
    mat2 rmat1 = mat2(c, -s, s, c);
    
    float c2 = cos(r + o2), s2 = sin(r + o2);
    mat2 rmat2 = mat2(c2, -s2, s2, c2);

    p.yz *= rmat1;
    p.xz *= rmat2;

    float w = texture(iChannel1, vec2(.04)).x;
    vec3 q = abs(p) - 0.1 - w ;
    float box = max(q.x, max(q.y, q.z));

    box = max(box, -max(q.x, q.y) - 0.03);
    box = max(box, -max(q.x, q.z) - 0.03);
    box = max(box, -max(q.y, q.z) - 0.03);

    return box;
}

vec3 getNormal(in vec3 p) {
    return normalize(vec3(mapScene(p + vec3(0.001, 0.0, 0.0)) - mapScene(p - vec3(0.001, 0.0, 0.0)),
                          mapScene(p + vec3(0.0, 0.001, 0.0)) - mapScene(p - vec3(0.0, 0.001, 0.0)),
                          mapScene(p + vec3(0.0, 0.0, 0.001)) - mapScene(p - vec3(0.0, 0.0, 0.001))));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 screenCenter = 0.5 * iResolution.xy;
    vec2 uv = (fragCoord - screenCenter) / iResolution.y;
    
    float w = texture(iChannel1, vec2(.35)).x;
                
    fragColor = texture(iChannel0, (fragCoord - screenCenter) * clamp((0.89 + w / 6.), 0.96, 1.02) / iResolution.xy + 0.5);

    vec3 ro = vec3(0.0, 0.0, 5.0);
    vec3 rd = normalize(vec3(uv, -1.0));

    float t = 0.0;
    for (int iter=0; iter < 150; iter++) {
        vec3 p = ro + rd * t;
        float d = mapScene(p);
        if (d < 0.001) {
            vec3 n = getNormal(p);
            fragColor.rgb += hue2rgb(iTime * 0.5) * 0.5;
            break;
        }

        if (t > 100.0) {
            break;
        }

        t += d;
    }
    
    fragColor = fragColor * 0.9;
}
