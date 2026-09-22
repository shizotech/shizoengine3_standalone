// License CC0: Psychedelic mouth
//  Companion piece to eye.glsl — same toolkit (2D SDF body, domain-warped fbm,
//  HSV palettes, fake lip lighting), applied to a breathing / talking mouth.

#define PI            3.141592654
#define TAU           (2.0*PI)
#define TIME          iTime
#define TTIME         (TAU*TIME)
#define RESOLUTION    iResolution
#define ROT(a)        mat2(cos(a), sin(a), -sin(a), cos(a))
#define BPERIOD       4.8

// https://stackoverflow.com/questions/15095909/from-rgb-to-hsv-in-opengl-glsl
const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}

//@slider min=0.0 max=1.0 value=0.5
uniform float breath;
//@slider min=0.0 max=1.0 value=0.4
uniform float chatter;
//@slider min=0.0 max=2.0 value=0.8
uniform float throat_glow;
//@slider min=0.0 max=1.0 value=0.35
uniform float lip_glow;

vec2 g_vx = vec2(0.0);
vec2 g_vy = vec2(3.2, 1.3);
vec2 g_wx = vec2(1.7, 9.2);
vec2 g_wy = vec2(8.3, 2.8);

float noise(vec2 p) {
  float a = sin(p.x);
  float b = sin(p.y);
  float c = 0.5 + 0.5*cos(p.x + p.y);
  return mix(a, b, c);
}

// https://iquilezles.org/articles/fbm
float fbm(vec2 p, float aa) {
  const mat2 frot = mat2(0.80, 0.60, -0.60, 0.80);

  float f = 0.0;
  float a = 1.0;
  float s = 0.0;
  float m = 2.0;
  for (int x = 0; x < 4; ++x) {
    f += a*noise(p);
    p  = frot*p*m;
    m  += 0.01;
    s  += a;
    a  *= aa;
  }
  return f/s;
}

// https://iquilezles.org/articles/smin
float pmin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5*(b-a)/k, 0.0, 1.0);
  return mix(b, a, h) - k*h*(1.0-h);
}

float pmax(float a, float b, float k) {
  return -pmin(-a, -b, k);
}

// https://mercury.sexy/hg_sdf/
float mod1(inout float p, float size) {
  float halfsize = size*0.5;
  float c = floor((p + halfsize)/size);
  p = mod(p + halfsize, size) - halfsize;
  return c;
}

float rbox(vec2 p, vec2 b, float r) {
  vec2 d = abs(p) - b + r;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

// Based on: https://iquilezles.org/articles/distfunctions2d
float vesica(vec2 p, vec2 sz) {
  if (sz.x < sz.y) {
    sz = sz.yx;
  } else {
    p  = p.yx;
  }
  vec2 sz2 = sz*sz;
  float d  = (sz2.x - sz2.y)/(2.0*sz.y);
  float r  = sqrt(sz2.x + d*d);
  float b  = sz.x;
  p = abs(p);
  return ((p.y-b)*d > p.x*b) ? length(p-vec2(0.0,b))
                             : length(p-vec2(-d,0.0))-r;
}

float clampf(float v) { return clamp(v, 0.0, 1.0); }

// ---------------------------------------------------------------- shape

float openAmt() {
  float a    = 0.5 + 0.5*sin(TTIME/BPERIOD);
  float talk = 0.5 + 0.5*sin(TTIME*0.53)*sin(TTIME*1.71 + 0.9);
  float o    = mix(a*a, a*talk, clamp(chatter, 0.0, 1.0));
  return clamp(0.05 + 0.95*o*(0.35 + 1.3*breath), 0.0, 1.0);
}

float mouth_shape(vec2 p) {
  float o = openAmt();
  float h = mix(0.028, 0.60, o);
  return vesica(p, vec2(1.30, h));
}

float gum_up(float x) { return  0.30 - 0.35*x*x; }
float gum_dn(float x) { return -0.27 + 0.33*x*x; }

float teeth_up(vec2 p, float dm) {
  float x0   = p.x;
  mod1(p.x, 0.150);
  float base = gum_up(x0);
  float hh   = 0.088 + 0.030*sin(6.5*x0) - 0.012*smoothstep(0.20, 0.80, abs(x0));
  float d    = rbox(vec2(p.x, p.y - (base - hh)), vec2(0.055, hh), 0.016);
  return max(d, dm);
}

float teeth_dn(vec2 p, float dm) {
  float x0   = p.x;
  mod1(p.x, 0.142);
  float base = gum_dn(x0);
  float hh   = 0.066 + 0.022*sin(5.5*x0 + 1.3);
  float d    = rbox(vec2(p.x, p.y - (base + hh)), vec2(0.050, hh), 0.014);
  return max(d, dm);
}

float tongue_dist(vec2 p, float dm) {
  vec2 q = p - vec2(0.04*sin(TTIME*0.29), -0.30 + 0.05*sin(TTIME*1.03));
  q /= vec2(0.66, 0.32);
  float d = (length(q) - 1.0)*0.32;
  d -= 0.035*fbm(p*2.6 + vec2(0.0, 0.12*TIME), 0.55);
  return max(d, dm);
}

float palate_dist(vec2 p, float dm) {
  float g = gum_up(p.x) + 0.006*sin(9.0*p.x);
  return max(p.y - g, dm);
}

float gingiva_dist(vec2 p, float dm) {
  float g = gum_dn(p.x) - 0.006*sin(8.0*p.x);
  return max(g - p.y, dm);
}

vec2 grad_mouth(vec2 p) {
  float h  = 1.0/220.0;
  float dx = mouth_shape(p + vec2(h, 0.0)) - mouth_shape(p - vec2(h, 0.0));
  float dy = mouth_shape(p + vec2(0.0, h)) - mouth_shape(p - vec2(0.0, h));
  vec2  g  = vec2(dx, dy);
  float l  = length(g);
  return (l > 1e-7) ? g/l : vec2(0.0, 1.0);
}

// ---------------------------------------------------------------- interior

void compute_globals() {
  vec2 vx = vec2(0.0, 0.0);
  vec2 vy = vec2(3.2, 1.3);

  vec2 wx = vec2(1.7, 9.2);
  vec2 wy = vec2(8.3, 2.8);

  vx *= ROT(TTIME/1000.0);
  vy *= ROT(TTIME/900.0);

  wx *= ROT(TTIME/800.0);
  wy *= ROT(TTIME/700.0);

  g_vx = vx;
  g_vy = vy;
  g_wx = wx;
  g_wy = wy;
}

// The throat is a warped fbm field sampled in polar coordinates which slowly
// flows inwards — it reads as an endless tunnel at the back of the mouth.
float interior_field(vec2 p, out vec2 v, out vec2 w) {
  float r = length(p*vec2(0.72, 1.35));
  float a = atan(p.y, p.x);

  vec2 q = vec2(2.2*log(1.0 + 4.0*r) - 0.30*TIME,
                1.8*a + 0.35*sin(3.0*a) + 0.08*TIME);

  v = vec2(fbm(q + g_vx, 0.5), fbm(q + g_vy, 0.5));
  w = vec2(fbm(q + 3.0*v + g_wx, 0.5), fbm(q + 3.0*v + g_wy, 0.5));
  return fbm(q + 2.25*w, 0.5);
}

vec3 interior_color(vec2 p, float dm) {
  vec2  v = vec2(0.0);
  vec2  w = vec2(0.0);
  float f = interior_field(p, v, w);
  float r = length(p);

  vec3 col = hsv2rgb(vec3(fract(0.008 + 0.10*f + 0.055*w.x),
                          clamp(0.95 - 0.20*f, 0.45, 1.0),
                          clamp(0.30 + 0.95*f*f + 0.25*abs(v.y), 0.0, 1.6)));

  // hot core at the back of the throat + glowing rim just inside the lips
  col += throat_glow*0.45*vec3(1.0, 0.25, 0.10)*exp(-4.0*max(r - 0.05, 0.0));
  col *= mix(0.12, 1.0, smoothstep(0.0, 0.55, r));
  col += 0.35*exp(-14.0*max(-dm, 0.0))*vec3(1.0, 0.5, 0.3);
  return col;
}

vec3 tongue_color(vec2 p) {
  float n = fbm(p*4.5 + vec2(0.10*TIME, 0.05*TIME), 0.55);
  vec3  col = mix(vec3(0.45, 0.08, 0.10), vec3(0.78, 0.26, 0.28),
                  clamp(0.35 + 0.75*n, 0.0, 1.0));
  float gloss = exp(-40.0*pow(p.x - 0.06*sin(TTIME*0.30), 2.0));
  col += 0.18*gloss*vec3(1.0, 0.80, 0.80);
  col *= 0.60 + 0.50*smoothstep(-0.45, 0.10, p.y);
  return col;
}

vec3 gum_color(vec2 p, float up) {
  float n     = fbm(p*7.0 + vec2(0.0, 0.05*TIME), 0.5);
  float veins = 0.5 + 0.5*sin(p.x*22.0 + 3.0*n + mix(0.0, PI, up));
  vec3  col   = mix(vec3(0.40, 0.09, 0.11), vec3(0.62, 0.22, 0.24),
                    clamp(0.45 + 0.55*n, 0.0, 1.0));
  col = mix(col, vec3(0.76, 0.30, 0.34), 0.30*veins);
  col *= mix(0.65, 1.0, up);
  return col;
}

vec3 teeth_color(vec2 p, float gumline, float up) {
  float X      = p.x;
  float lp     = mod(X + 0.075, 0.150) - 0.075;
  float groove = 1.0 - 0.45*smoothstep(0.012, 0.052, abs(lp));
  float v      = mix(gumline - p.y, p.y - gumline, up);
  float s      = clamp(v/0.17, 0.0, 1.0);

  vec3 col = vec3(0.93, 0.90, 0.82)*groove*(0.45 + 0.55*s);
  col += 0.22*exp(-700.0*lp*lp)*smoothstep(0.50, 0.95, s)*vec3(1.0, 0.98, 0.94);
  col *= 1.0 - 0.40*smoothstep(0.50, 0.95, abs(X));
  return col;
}

vec3 lips_color(vec2 p, float dm, float lipW) {
  float s  = clamp(dm/lipW, -1.0, 1.0);
  vec2  g  = grad_mouth(p);
  float zz = sqrt(max(1.0 - s*s, 0.0));
  vec3  n  = normalize(vec3(g*s*1.6, zz + 0.35));

  vec3  L  = normalize(vec3(0.30, 0.62, 0.72));
  float dif = max(dot(n, L), 0.0);
  vec3  H   = normalize(L + vec3(0.0, 0.0, 1.0));
  float spe = pow(max(dot(n, H), 0.0), 40.0);

  float vein = 0.5 + 0.5*sin(p.x*28.0 + 6.0*fbm(p*9.0, 0.6));
  vec3  base = mix(vec3(0.28, 0.05, 0.07), vec3(0.54, 0.14, 0.15),
                   clamp(0.40 + 0.45*vein, 0.0, 1.0));

  vec3 col = base*(0.22 + 0.95*dif);
  col += spe*vec3(1.0, 0.92, 0.88)*0.9;
  col += 0.10*exp(-6.0*abs(s))*vec3(1.0, 0.40, 0.35);
  return col;
}

vec3 background(vec2 p) {
  float r = length(p*vec2(0.55, 1.0));
  vec3  col = mix(vec3(0.10, 0.055, 0.050), vec3(0.015, 0.010, 0.014),
                  smoothstep(0.20, 1.40, r));
  col *= 0.85 + 0.30*fbm(p*4.0 + vec2(0.0, 0.02*TIME), 0.6);
  col += 0.03*vec3(1.0, 0.60, 0.50)*exp(-3.0*abs(p.y - 0.90));
  return col;
}

// ---------------------------------------------------------------- compose

vec3 effect(vec2 p) {
  compute_globals();

  float aa   = 2.0/RESOLUTION.y;
  float lipW = 0.085;

  vec3  col = background(p);

  float dm = mouth_shape(p);

  float inside = 1.0 - smoothstep(-2.0*aa, 2.0*aa, dm);
  col = mix(col, interior_color(p, dm), inside);

  float dt = tongue_dist(p, dm);
  col = mix(col, tongue_color(p), 1.0 - smoothstep(-aa, aa, dt));

  float dg = gingiva_dist(p, dm);
  col = mix(col, gum_color(p, 0.0), 1.0 - smoothstep(-aa, aa, dg));

  float dp = palate_dist(p, dm);
  col = mix(col, gum_color(p, 1.0), 1.0 - smoothstep(-aa, aa, dp));

  float dtu = teeth_up(p, dm);
  col = mix(col, teeth_color(p, gum_up(p.x), 1.0), 1.0 - smoothstep(-aa, aa, dtu));

  float dtd = teeth_dn(p, dm);
  col = mix(col, teeth_color(p, gum_dn(p.x), 0.0), 1.0 - smoothstep(-aa, aa, dtd));

  float dl = abs(dm) - lipW;
  col = mix(col, lips_color(p, dm, lipW), 1.0 - smoothstep(-aa, aa, dl));

  col += lip_glow*exp(-6.0*max(dm, 0.0))*vec3(0.90, 0.25, 0.20);

  return col;
}

vec3 postProcess(vec3 col, vec2 q) {
  col = clamp(col, 0.0, 1.0);
  col = pow(col, vec3(1.0/2.2));
  col = col*0.6 + 0.4*col*col*(3.0 - 2.0*col);
  col = mix(col, vec3(dot(col, vec3(0.33))), -0.35);
  col *= 0.5 + 0.5*pow(19.0*q.x*q.y*(1.0-q.x)*(1.0-q.y), 0.7);
  return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 q = fragCoord/iResolution.xy;
  vec2 p = -1.0 + 2.0*q;
  p.x *= RESOLUTION.x/RESOLUTION.y;

  vec3 col = effect(p);
  col = mix(vec3(0.0), col, smoothstep(0.4, 3.5, TIME));
  col = postProcess(col, q);

  fragColor = vec4(col, 1.0);
}
