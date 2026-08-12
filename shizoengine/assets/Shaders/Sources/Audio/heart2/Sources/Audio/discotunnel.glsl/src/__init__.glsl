//@settings dtype=float32 format=rgba
// Created by SHAU - 2018
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// Discotunnel - Raymarching audio-reactive tunnel shader

#define PI 3.141592
#define FAR 50.0
#define EPS 0.05
#define HASHSCALE1 .1031

#define CA vec3(0.5, 0.5, 0.5)
#define CB vec3(0.5, 0.5, 0.5)
#define CC vec3(1.0, 1.0, 1.0)
#define CD vec3(0.0, 0.33, 0.67)

#define CT u_time / 14.0

struct CubeIntersection {
    float tN;
    float tF;
    vec3 nN;
    vec3 nF;
    vec3 col;
};

struct Cubes {
    CubeIntersection near;
    CubeIntersection mid;
    CubeIntersection far;
};

uniform sampler2D A;

mat2 rot(float x) {return mat2(cos(x), sin(x), -sin(x), cos(x));}
float rand(vec2 p) {return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453);}
//IQ cosine palettes
//https://iquilezles.org/articles/palettes
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {return a + b * cos(6.28318 * (c * t + d));}
vec3 glowColour() {return palette(u_time * 0.1, CA, CB, CC, CD);}
float atten(float nft) {return 1.0 / (1.0 + nft * nft * 2.0);}

//Dave Hoskins - hash without sine
float hash13(vec3 p3) {
    p3 = fract(p3 * HASHSCALE1);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 path(float t) {
    float a = sin(t * PI / 16.0 + 1.7);
    float b = cos(t * PI / 16.0);
    return vec3(a * 2.0, b * a, t);
}

//IQs noise
float noise(vec3 rp) {
    vec3 ip = floor(rp);
    rp -= ip;
    vec3 s = vec3(7, 157, 113);
    vec4 h = vec4(0.0, s.yz, s.y + s.z) + dot(ip, s);
    rp = rp * rp * (3.0 - 2.0 * rp);
    h = mix(fract(sin(h) * 43758.5), fract(sin(h + s.x) * 43758.5), rp.x);
    h.xy = mix(h.xz, h.yw, rp.y);
    return mix(h.x, h.y, rp.z);
}

float fbm(vec3 x) {
    float r = 0.0;
    float w = 1.0;
    float s = 1.0;
    for (int i = 0; i < 5; i++) {
        w *= 0.5;
        s *= 2.0;
        r += w * noise(s * x);
    }
    return r;
}

//Eiffie
float sdHelix(vec3 rp, float r) {
    rp.xy += path(rp.z).xy * 1.1;
    rp.xy *= rot(r);

    float d = 2.0;
    float halfd = d * 0.5;

    float a = atan(rp.y, rp.x) * halfd;
    float b = mod(rp.z, PI * d) - PI * halfd;
    a = abs(a - b);
    if (a > PI * halfd) a = PI * d - a;
    return length(vec2(length(rp.xy) - 4.4, a)) - 1.0;
}

float map(vec3 rp) {
    return sdHelix(rp, 0.4 * u_time);
}

//IQ - Box functions
// https://iquilezles.org/articles/boxfunctions
CubeIntersection cubeIntersection(vec3 ro, vec3 rd, vec3 boxSize, float r1, float r2) {
    ro.zy *= rot(r1);
    rd.zy *= rot(r1);
    ro.xz *= rot(r2);
    rd.xz *= rot(r2);

    vec3 m = 1.0 / rd;
    vec3 n = m * ro;
    vec3 k = abs(m) * boxSize;

    vec3 t1 = -n - k;
    vec3 t2 = -n + k;

    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);

    //miss
    if (tN > tF || tF < 0.0) return CubeIntersection(0.0, 0.0, vec3(0.0), vec3(0.0), vec3(0.0));

    vec3 nN = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
    vec3 nF = -sign(rd) * step(t2.xyz, t2.yzx) * step(t2.xyz, t2.zxy);

    nN.zy *= rot(-r1);
    nF.zy *= rot(-r1);
    nN.xz *= rot(-r2);
    nF.xz *= rot(-r2);

    return CubeIntersection(tN, tF, nN, nF, vec3(0.0));
}

float boxDensity(vec3 wro, vec3 wrd, vec3 r, float dbuffer, float r1, float r2) {
    wro.zy *= rot(r1);
    wrd.zy *= rot(r1);
    wro.xz *= rot(r2);
    wrd.xz *= rot(r2);

    vec3 d = (vec4(wrd,0.0)).xyz;
    vec3 o = (vec4(wro,1.0)).xyz;

    // ray-box intersection in box space
    vec3 m = 1.0/d;
    vec3 n = m*o;
    vec3 k = abs(m)*r;
    vec3 ta = -n - k;
    vec3 tb = -n + k;
    float tN = max( max( ta.x, ta.y ), ta.z );
    float tF = min( min( tb.x, tb.y ), tb.z );
    if( tN > tF || tF < 0.0) return 0.0;

    // not visible (behind camera or behind dbuffer)
    if( tF<0.0 || tN>dbuffer ) return 0.0;

    // clip integration segment from camera to dbuffer
    tN = max( tN, 0.0 );
    tF = min( tF, dbuffer );

    // move ray to the intersection point
    o += tN*d; tF=tF-tN; tN=0.0;

    // density calculation. density is of the form
    //
    // d(x,y,z) = [1-(x/rx)^2] * [1-(y/ry)^2] * [1-(z/rz)^2];
    //
    // this can be analytically integrable (it's a degree 6 polynomial):

    vec3 a = 1.0 -     (o*o)/(r*r);
    vec3 b =     - 2.0*(o*d)/(r*r);
    vec3 c =     -     (d*d)/(r*r);

    float t1 = tF;
    float t2 = t1*t1;
    float t3 = t2*t1;
    float t4 = t2*t2;
    float t5 = t2*t3;
    float t6 = t3*t3;
    float t7 = t3*t4;

    float f = (t1/1.0) *(a.x*a.y*a.z) +
              (t2/2.0) *(a.x*a.y*b.z + a.x*b.y*a.z + b.x*a.y*a.z) +
              (t3/3.0) *(a.x*a.y*c.z + a.x*b.y*b.z + a.x*c.y*a.z + b.x*a.y*b.z + b.x*b.y*a.z + c.x*a.y*a.z) +
              (t4/4.0) *(a.x*b.y*c.z + a.x*c.y*b.z + b.x*a.y*c.z + b.x*b.y*b.z + b.x*c.y*a.z + c.x*a.y*b.z + c.x*b.y*a.z) +
              (t5/5.0) *(a.x*c.y*c.z + b.x*b.y*c.z + b.x*c.y*b.z + c.x*a.y*c.z + c.x*b.y*b.z + c.x*c.y*a.z) +
              (t6/6.0) *(b.x*c.y*c.z + c.x*b.y*c.z + c.x*c.y*b.z) +
              (t7/7.0) *(c.x*c.y*c.z);

    return f;
}

//modified from IQs voxel marching
Cubes drawCubes(vec3 ro, vec3 rd) {
    CubeIntersection near = CubeIntersection(0.0, 0.0, vec3(0.0), vec3(0.0), vec3(0.0));
    CubeIntersection mid = CubeIntersection(0.0, 0.0, vec3(0.0), vec3(0.0), vec3(0.0));
    CubeIntersection far = CubeIntersection(0.0, 0.0, vec3(0.0), vec3(0.0), vec3(0.0));

    vec4 sound = texture(A, vec2(0.5) / iResolution.xy);

    float nHits = 0.0;

    vec3 pos = floor(ro);
    vec3 ri = 1.0 / rd;
    vec3 rs = sign(rd);
    vec3 dis = (pos - ro + 0.5 + rs * 0.5) * ri;

    vec3 mm = vec3(0.0);
    for (int i = 0; i < 128; i++) {

        float r = hash13(pos);
        float r1 = r + u_time + pos.z;
        float r2 = r1 * 2.0 + pos.y;
        vec3 col = palette(r * 1.6, CA * sound.x * 0.4, CB * sound.z * 0.5, CC * sound.y * 0.5, CD) * sound.w * 1.6;

        if (map(pos) < EPS) {

            vec3 cube = vec3(clamp(r * 0.5, 0.1, 0.3));
            CubeIntersection ci = cubeIntersection(ro - (pos + vec3(0.5)), rd, cube, r1, r2);
            col *= boxDensity(ro - (pos + vec3(0.5)), rd, cube, FAR, r1, r2);

            if (ci.tN > 0.0) {

                if (nHits == 0.0) {

                    near.tN = ci.tN;
                    near.tF = ci.tF;
                    near.nN = ci.nN;
                    near.nF = ci.nF;
                    near.col = col;

                } else if (nHits == 1.0) {

                    mid.tN = ci.tN;
                    mid.tF = ci.tF;
                    mid.nN = ci.nN;
                    mid.nF = ci.nF;
                    mid.col = col;

                } else if (nHits == 2.0) {

                    far.tN = ci.tN;
                    far.tF = ci.tF;
                    far.nN = ci.nN;
                    far.nF = ci.nF;
                    far.col = col;
                }

                nHits += 1.0;
                if (nHits > 2.0) break;
            }
        }

        mm = step(dis.xyz, dis.yxy) * step(dis.xyz, dis.zzx);
        dis += mm * rs * ri;
        pos += mm * rs;
    }

    return Cubes(near, mid, far);
}

//Moody clouds from Patu
//https://www.shadertoy.com/view/4tVXRV
vec3 clouds(vec3 rd) {
    vec2 uv = rd.xz / (rd.y + 0.6);
    float nz = fbm(vec3(uv.yx * 1.4 + vec2(CT, 0.0), CT)) * 1.5;
    return clamp(pow(vec3(nz), vec3(4.0)) * rd.y, 0.0, 1.0);
}

vec4 colourSurface(vec3 ro, vec3 rd, CubeIntersection cube) {

    vec4 pc = vec4(0.0);

    vec3 lp = vec3(0.0, 0.0, u_time * 4.0);
    lp.xy -= path(lp.z).xy;

    //near face
    vec3 rp = ro + rd * cube.tN;
    vec3 ld = normalize(lp - rp);
    float lt = length(lp - rp);
    float ltatten = 1.0 / (1.0 + lt * lt * 0.005);

    float spec = pow(max(dot(reflect(-ld, cube.nN), -rd), 0.0), 32.0) * ltatten;
    float fres = pow(clamp(dot(cube.nN, rd) + 1.0, 0.0, 1.0), 64.0) * ltatten;
    pc.xyz += clouds(reflect(rd, cube.nN)) * glowColour() * fres;
    pc.xyz += vec3(1.0) * spec;

    float nft = cube.tF - cube.tN;

    //glow
    pc.xyz += cube.col * 2.0 * ltatten;

    //far face
    rp = ro + rd * cube.tF;
    ld = normalize(lp - rp);
    lt = length(lp - rp);
    ltatten = 1.0 / (1.0 + lt * lt * 0.005);

    spec = pow(max(dot(reflect(-ld, cube.nF), -rd), 0.0), 32.0) * ltatten;
    fres = pow(clamp(dot(cube.nF, rd) + 1.0, 0.0, 1.0), 64.0) * ltatten;
    pc.xyz += clouds(reflect(rd, cube.nF)) * glowColour() * fres * atten(nft) * 0.6;
    pc.xyz += vec3(1.0) * spec * atten(nft) * 0.6;

    return pc;
}

vec3 colourScene(vec3 ro, vec3 rd, Cubes cubes) {

    vec3 bgc = clouds(rd) * glowColour();
    vec3 pc = bgc;

    if (cubes.near.tN > 0.0) {

        vec4 nc = colourSurface(ro, rd, cubes.near);
        pc = nc.xyz;

        if (cubes.mid.tN > 0.0) {

            vec4 mc = colourSurface(ro, rd, cubes.mid);
            pc += mc.xyz * atten(nc.w) * 0.3;

            if (cubes.far.tN > 0.0) {

                vec4 fc = colourSurface(ro, rd, cubes.far);
                pc += fc.xyz * atten(nc.w + mc.w) * 0.1;

            } else {
                pc += bgc * atten(nc.w + mc.w) * 0.1;
            }

        } else {
            pc += bgc * atten(nc.w) * 0.3;
        }
    }

    return pc;
}

void setupCamera(vec2 fragCoord, inout vec3 ro, inout vec3 rd) {

    vec2 uv = (fragCoord.xy - iResolution.xy * 0.5) / iResolution.y;

    vec3 lookAt = vec3(0.0, 0.0, u_time * 4.0);
    ro = lookAt + vec3(0.0, 0.0, -1.0);

    lookAt.xy -= path(lookAt.z).xy * 1.1;
    ro.xy -= path(ro.z).xy * 1.1;

    float FOV = PI / 3.0;
    vec3 forward = normalize(lookAt - ro);
    vec3 right = normalize(vec3(forward.z, 0.0, -forward.x));
    vec3 up = cross(forward, right);

    rd = normalize(forward + FOV * uv.x * right + FOV * uv.y * up);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {

    vec3 ro, rd;
    setupCamera(fragCoord, ro, rd);

    Cubes cubes = drawCubes(ro, rd);
    //fragColor = vec4(sqrt(clamp(colourScene(ro, rd, cubes), 0.0, 1.0)), 1.0);
    fragColor = vec4(colourScene(ro, rd, cubes), 1.0);
}
