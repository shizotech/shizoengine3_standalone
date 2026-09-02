// ==== Radial_Line: weiße Balken rotieren um einen Endpunkt (Bildschirmmitte) ====
//@slider min=0.002 max=0.2 value=0.02
uniform float bar_width;
//@int min=1 max=64 value=12
uniform int bar_count;
//@slider min=0.0 max=1.0 value=0.0
uniform float distribution_randomness;
//@slider min=0.0 max=1.0 value=0.0
uniform float softness;
//@slider min=-1.0 max=1.0 value=0.0
uniform float curvature;
//@enum options=(wave, arc)
uniform int line_shape;

// deterministischer Hash pro Balken
float hash1(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// Abstand Punkt -> Liniensegment
float pointSegDist(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
    vec2 proj = a + t * ab;
    return length(p - proj);
}

// Zeichnet einen einzelnen (gekrümmten) Balken und gibt die Sichtbarkeit zurück.
float drawBar(vec2 p, int idx, float time) {
    float n = float(bar_count);
    // gleichmäßig verteilte Grundwinkel über 2π
    float baseAngle = (float(idx) / n) * 6.28318;
    // Randomness: pro-Balken Jitter in Winkel und Länge (skalierend mit distribution_randomness)
    float jitA = (hash1(float(idx) + 10.0) - 0.5) * distribution_randomness * 1.5;
    float jitL = (hash1(float(idx) + 20.0) - 0.5) * distribution_randomness;
    baseAngle += jitA;

    // Globale Rotation über die Zeit
    float ang = baseAngle + time;

    float r0 = 0.0;              // Innen-Endpunkt liegt exakt am Drehpunkt (0,0)
    float r1 = 1.0 + jitL * 0.15; // Außen-Endpunkt (geht über den Bildschirmrand hinaus)

    vec2 dir  = vec2(cos(ang), sin(ang));
    vec2 perp = vec2(-sin(ang), cos(ang));

    vec2 A = dir * r0;
    vec2 B = dir * r1;

    // Bézier-Steuerpunkt (nur bei arc relevant), radial versetzt und mit curvature skaliert
    vec2 mid = (A + B) * 0.5;
    vec2 radialDir = normalize(mid + vec2(1e-6));
    vec2 C = mid + radialDir * curvature * (r1 - r0) * 0.5;

    // Kurve in Segmente aufteilen und minimale Punkt-Segment-Distanz sammeln
    float best = 1e9;
    const int SEGS = 12;
    vec2 prev = A;
    for (int s = 1; s <= SEGS; s++) {
        float t  = float(s) / float(SEGS);
        float t1 = 1.0 - t;
        vec2 pt;
        if (line_shape == 0) {
            // Wellenlinie: Sinus-Offset senkrecht zur Balkenrichtung, Amplitude aus |curvature|
            float r   = r0 + t * (r1 - r0);
            float amp = abs(curvature) * 0.12;
            float wave = sin(t * 6.28318 * 2.0);
            pt = dir * r + perp * (wave * amp);
        } else {
            // Bogen: quadratische Bézier mit einem Steuerpunkt C
            pt = t1 * t1 * A + 2.0 * t1 * t * C + t * t * B;
        }
        best = min(best, pointSegDist(p, prev, pt));
        prev = pt;
    }

    // Breite des Balkens aus der bar_width-Einstellung
    float w = bar_width;
    // Weichheit: harte Kante -> weiche Kante interpolieren
    float hardEdge = smoothstep(w, w * 0.4, best);
    float softEdge = smoothstep(w * 0.5, w * 0.1, best);
    return mix(hardEdge, softEdge, softness);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float time = iTime * 0.5;
    vec3 color = vec3(0.0);
    for (int i = 0; i < 64; i++) {
        if (i < bar_count) {
            color += vec3(1.0) * drawBar(p, i, time);
        }
    }
    color = min(color, vec3(1.0));
    fragColor = vec4(color, 1.0);
}
