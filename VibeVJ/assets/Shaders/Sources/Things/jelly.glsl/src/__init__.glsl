// License CC0: Drift
//  Companion piece to eye.glsl — a pulsing, bioluminescent jellyfish.
//  Same toolkit: 2D SDF body, domain-warped fbm, HSV palettes, fake lighting.

#define PI            3.141592654
#define TAU           (2.0*PI)
#define TIME          iTime
#define TTIME         (TAU*TIME)
#define RESOLUTION    iResolution
#define ROT(a)        mat2(cos(a), sin(a), -sin(a), cos(a))
#define BPERIOD       3.2

const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}

//@slider min=0.0 max=1.0 value=0.55
uniform float biolum;
//@slider min=0.0 max=1.0 value=0.5
uniform float drift;
//@slider min=0.0 max=1.0 value=0.5
uniform float tentacle_length;

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

vec2 toPolar(vec2 p) {
  return vec2(length(p), atan(p.y, p.x));
}

vec2 toRect(vec2 p) {
  return p.x*vec2(cos(p.y), sin(p.y));
}

float pulseAmt() {
  float s = 0.5 + 0.5*sin(TTIME/BPERIOD);
  return s*s*(3.0 - 2.0*s);
}

vec2 bellCenter() {
  return vec2(0.12*sin(TTIME*0.11),
              0.22 + 0.10*pulseAmt() + 0.25*drift*sin(TTIME*0.07));
}

// ---------------------------------------------------------------- bell

float bell_shape(vec2 p) {
  float c = pulseAmt();
  vec2  q = p - bellCenter();

  float w = mix(0.48, 0.64, c);
  float h = mix(0.66, 0.46, c);

  float d = (length(vec2(q.x/w, q.y/h)) - 1.0)*min(w, h);

  // dome = inside the ellipse and above the scalloped rim
  float rim = -0.14 - 0.05*c + 0.035*cos(14.0*q.x + 0.6*TIME);
  d = max(d, rim - q.y);

  // rounded crest on top
  d = pmin(d, length(q - vec2(0.0, h*0.55)) - h*0.55, 0.10);

  return d;
}

vec2 grad_bell(vec2 p) {
  float h  = 1.0/220.0;
  float dx = bell_shape(p + vec2(h, 0.0)) - bell_shape(p - vec2(h, 0.0));
  float dy = bell_shape(p + vec2(0.0, h)) - bell_shape(p - vec2(0.0, h));
  vec2  g  = vec2(dx, dy);
  float l  = length(g);
  return (l > 1e-7) ? g/l : vec2(0.0, 1.0);
}

// ---------------------------------------------------------------- tentacles

float tentacle_dist(vec2 p, out float depth) {
  vec2  c  = bellCenter();
  float X  = p.x - c.x;
  float Y  = p.y - c.y;

  float len = 0.90 + 1.10*tentacle_length;

  depth = -Y - 0.14;

  float x0 = X;
  mod1(x0, 0.115);

  float d = 0.0;
  float sway = 0.0;

  float k = clamp(depth/max(len, 0.2), 0.0, 1.0);
  sway = (0.10*sin(1.9*TIME + X*5.0) + 0.055*sin(4.7*TIME + X*11.0))*k*k;

  float width = 0.011*exp(-0.55*max(depth, 0.0)) + 0.0030;
  d = abs(x0 - sway) - width;

  // only below the bell rim, within the bell width, and within reach
  d = max(d, (-0.14 - 0.05*pulseAmt()) - Y);
  d = max(d, abs(X) - 0.52);
  d = max(d, depth - len);

  return d;
}

float oral_arm_dist(vec2 p) {
  vec2  c  = bellCenter();
  float X  = p.x - c.x;
  float Y  = p.y - c.y;

  float depth = -Y - 0.10;
  float x0 = X;
  mod1(x0, 0.26);

  float sway  = 0.14*sin(1.4*TIME + X*3.0)*clamp(depth, 0.0, 1.0);
  float width = 0.055*exp(-0.45*max(depth, 0.0)) + 0.010;
  width += 0.012*fbm(vec2(X*6.0, depth*3.0 - 0.4*TIME), 0.55);

  float d = abs(x0 - sway) - width;
  d = max(d, (-0.12) - Y);
  d = max(d, abs(X) - 0.30);
  d = max(d, depth - (0.80 + 0.70*tentacle_length));
  return d;
}

// ---------------------------------------------------------------- color

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

float bell_field(vec2 q, out vec2 v, out vec2 w) {
  vec2 pl = toPolar(vec2(q.x, q.y*1.25));
  pl.x = 2.0*log(1.0 + 3.0*pl.x) + 0.05*TIME;
  pl.y = pl.y + 0.20*sin(4.0*pl.y) - 0.06*TIME;
  vec2 pp = toRect(pl);

  v = vec2(fbm(pp + g_vx, 0.5), fbm(pp + g_vy, 0.5));
  w = vec2(fbm(pp + 3.0*v + g_wx, 0.5), fbm(pp + 3.0*v + g_wy, 0.5));
  return fbm(pp + 2.25*w, 0.5);
}

vec3 bell_color(vec2 p, float d) {
  vec2  c  = bellCenter();
  vec2  q  = p - c;

  vec2  v  = vec2(0.0);
  vec2  w  = vec2(0.0);
  float f  = bell_field(q, v, w);

  // radial canals
  float ang   = atan(q.y, q.x);
  float canal = 0.5 + 0.5*cos(ang*16.0 + 2.5*f + 0.4*TIME);

  // fake dome shading
  vec2  g    = grad_bell(p);
  float th   = clamp(-d/0.30, 0.0, 1.0);
  float zz   = sqrt(max(th, 0.0));
  vec3  n    = normalize(vec3(g*(1.0 - th)*1.4, zz + 0.35));
  vec3  L    = normalize(vec3(-0.25, 0.75, 0.60));
  vec3  H    = normalize(L + vec3(0.0, 0.0, 1.0));
  float dif  = max(dot(n, L), 0.0);
  float spe  = pow(max(dot(n, H), 0.0), 26.0);

  float hue = fract(0.72 + 0.09*f + 0.05*w.x + 0.02*p.y);
  vec3  col = hsv2rgb(vec3(hue, clamp(0.65 - 0.20*canal, 0.30, 0.95),
                           clamp(0.35 + 0.75*canal + 0.35*f, 0.0, 1.2)));

  col *= 0.35 + 0.85*dif;
  col += 0.35*spe*vec3(0.85, 0.95, 1.0);
  col += 0.20*canal*vec3(0.35, 0.85, 1.0)*th;

  // pulsing bioluminescent rim
  col += biolum*(0.4 + 0.6*pulseAmt())*exp(-4.5*abs(d))*vec3(0.30, 0.90, 1.0);
  return col;
}

vec3 tentacle_color(vec2 p, float depth) {
  float n   = fbm(vec2(p.x*9.0, depth*3.0 - 0.35*TIME), 0.55);
  vec3  col = hsv2rgb(vec3(fract(0.78 + 0.10*n - 0.03*depth), 0.75, 0.55 + 0.45*n));
  col *= exp(-0.65*max(depth, 0.0)) + 0.10;
  col += 0.25*biolum*exp(-3.0*max(depth, 0.0))*vec3(0.25, 0.80, 1.0);
  return col;
}

vec3 arm_color(vec2 p, float depth) {
  float n   = fbm(p*4.0 + vec2(0.15*TIME, -0.2*TIME), 0.6);
  vec3  col = hsv2rgb(vec3(fract(0.86 + 0.12*n), 0.55, 0.45 + 0.55*n));
  col *= 0.55 + 0.45*exp(-0.5*max(depth, 0.0));
  return col;
}

vec3 background(vec2 p) {
  vec3 col = mix(vec3(0.030, 0.070, 0.110), vec3(0.002, 0.006, 0.016),
                 smoothstep(0.9, -1.1, p.y));

  // god rays
  float ray = 0.5 + 0.5*sin(p.x*6.0 + 0.7*sin(p.x*2.3 + TIME*0.15));
  col += 0.06*vec3(0.35, 0.70, 0.85)*pow(ray, 3.0)*smoothstep(-0.4, 1.2, p.y);

  // drifting motes
  float m = smoothstep(0.94, 0.99, fbm(p*12.0 + vec2(0.0, -0.10*TIME), 0.5));
  col += 0.35*m*vec3(0.55, 0.80, 0.90);

  return col;
}

// ---------------------------------------------------------------- compose

vec3 effect(vec2 p) {
  compute_globals();

  float aa = 2.0/RESOLUTION.y;

  vec3  col = background(p);

  float dd = oral_arm_dist(p);
  float dA = -0.10 - (p.y - bellCenter().y);
  col = mix(col, arm_color(p, dA), 1.0 - smoothstep(-aa, aa, dd));

  float depth = 0.0;
  float dt = tentacle_dist(p, depth);
  col = mix(col, tentacle_color(p, depth), 1.0 - smoothstep(-aa, aa, dt));

  float db = bell_shape(p);
  col = mix(col, bell_color(p, db), 1.0 - smoothstep(-aa, aa, db));

  // water haze / soft outer glow
  col += 0.25*biolum*exp(-3.0*max(db, 0.0))*vec3(0.20, 0.55, 0.80);

  return col;
}

vec3 postProcess(vec3 col, vec2 q) {
  col = clamp(col, 0.0, 1.0);
  col = pow(col, vec3(1.0/2.2));
  col = col*0.6 + 0.4*col*col*(3.0 - 2.0*col);
  col = mix(col, vec3(dot(col, vec3(0.33))), -0.30);
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
