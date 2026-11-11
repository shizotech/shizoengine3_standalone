//@settings dtype=float32 format=rgba rendersize=(32,8)
// --- pass L: the path of the light beam through the glass, one column per wavelength of the fan (400 .. 700 nm).
// Rows 0 .. 6: the points where the path enters, bends or reflects (xyz) with the light left after them (w);
// row 7: (wavelength, number of points, index of refraction, -). Every pixel traces the whole path of its column:
// it marches the same shapes as pass A (and goes on into the next copy of the grid) ---
#include lib/common.glsl

uniform sampler2D S;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    int j = int(fragCoord.x), row = int(fragCoord.y);
    vec4 lv = texelFetch(S, ivec2(ST_LEVELS, 0), 0);
    vec4 sp = texelFetch(S, ivec2(ST_SPRING, 0), 0);
    setupScene(iTime, lv.y * react * 4.0, sp.x);
    float lnm = fanWavelength(j);
    float eta = iorAt(lnm, 1.0 + lv.z * react * 0.6);
    vec3 p, d;
    beamStart(p, d);
    vec4 pts[7];
    for (int i = 0; i < 7; i++)
        pts[i] = vec4(0.0);
    pts[0] = vec4(p, 1.0);
    int count = 1;
    float thr = 1.0;
    bool inside = false;
    float off = 0.003 * gS;
    for (int seg = 0; seg < 6; seg++) {
        if (!inside) {
            float th;
            if (!marchScene(p, d, 80.0, 140, th)) {
                // out into the room: until the floor, or far away
                float len = 40.0;
                if (d.y < -1e-4)
                    len = min(len, (floorY - p.y) / d.y);
                p += d * len;
                pts[count] = vec4(p, thr);
                count++;
                break;
            }
            p += d * th;
            // the beam comes from far away, where the march stops further from the glass: onto the surface
            for (int k = 0; k < 3; k++)
                p += d * localDist(p);
            vec3 n = localNormal(p);
            float F = fresnelDielectric(max(-dot(d, n), 0.0), 1.0, eta);
            thr *= 1.0 - F;
            d = refract(d, n, 1.0 / eta);
            p -= n * off;
            inside = true;
        } else {
            float tt = marchInside(p, d, 80);
            if (tt < 0.0)
                break;
            p += d * tt;
            thr *= exp(-absorption * tt);
            vec3 n = localNormal(p);
            vec3 rr = refract(d, -n, eta);
            if (dot(rr, rr) < 1e-6) {
                d = reflect(d, n);      // total internal reflection
                p -= n * off;
            } else {
                float F = fresnelDielectric(max(dot(d, n), 0.0), eta, 1.0);
                thr *= 1.0 - F;
                d = rr;
                p += n * off;
                inside = false;
            }
        }
        pts[count] = vec4(p, thr);
        count++;
    }
    if (row < 7)
        fragColor = pts[row];
    else
        fragColor = vec4(lnm, float(count), eta, 0.0);
}
