// License CC0: Accretion
//  Black hole seen through a bent ray integration: lensed accretion disk,
//  photon ring, relativistic jets and a warped starfield — the "space side"
//  of eye.glsl turned into its own thing.

#define PI            3.141592654
#define TAU           (2.0*PI)
#define TIME          iTime
#define TTIME         (TAU*TIME)
#define RESOLUTION    iResolution
#define ROT(a)        mat2(cos(a), sin(a), -sin(a), cos(a))

#define RS            0.30   // event horizon radius
#define LENS          0.25   // bending strength

//@slider min=0.0 max=3.0 value=1.2
uniform float disk_gain;
//@slider min=0.0 max=2.0 value=0.7
uniform float spin;
//@slider min=0.0 max=1.0 value=0.35
uniform float jets;

const float DISK_IN  = 0.42;
const float DISK_OUT = 2.60;

// https://iquilezles.org/articles/colormaps (black body-ish)
vec3 blackbody(float t) {
  t   = clamp(t, 0.0, 1.0);
  vec3 col = mix(vec3(0.50, 0.05, 0.00), vec3(1.00, 0.55, 0.10), smoothstep(0.00, 0.50, t));
  col  = mix(col, vec3(1.00, 0.92, 0.72), smoothstep(0.45, 0.85, t));
  col  = mix(col, vec3(1.00, 1.00, 1.00), smoothstep(0.85, 1.00, t));
  return col;
}

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

vec2 mod2(inout vec2 p, vec2 size) {
  vec2 c = floor((p + size*0.5)/size);
  p = mod(p + size*0.5, size) - size*0.5;
  return c;
}

vec3 toSpherical(vec3 p) {
  float r  = length(p);
  float t  = acos(clamp(p.z/r, -1.0, 1.0));
  float ph = atan(p.y, p.x);
  return vec3(r, t, ph);
}

// ---------------------------------------------------------------- background

vec3 starfield(vec3 rd) {
  vec3 sp = toSpherical(rd);
  vec2 pg = sp.yz;
  pg.y += 0.01*TIME;

  float aa = 0.004;
  vec2  ng = mod2(pg, vec2(TAU/16.0, PI/10.0));
  float dg = min(abs(ng.x), abs(ng.y));
  vec3  grid = vec3(0.08, 0.12, 0.20)*(1.0 - smoothstep(0.0, aa, dg));

  float neb  = fbm(pg*3.0 + vec2(0.02*TIME, 0.0), 0.6);
  float stars = smoothstep(0.86, 0.98, fbm(pg*22.0, 0.5));

  vec3 col = vec3(0.010, 0.012, 0.022);
  col += 0.35*grid;
  col += 0.10*vec3(0.35, 0.20, 0.55)*smoothstep(0.35, 0.95, neb);
  col += 0.70*vec3(0.85, 0.90, 1.0)*stars;
  return col;
}

// ---------------------------------------------------------------- disk

vec3 diskColor(vec2 d, vec3 rd) {
  float rho = length(d);
  float ph  = atan(d.y, d.x);

  // Keplerian shear: inner rings lap the outer ones
  float rot = spin*TIME*1.3/pow(max(rho, 0.45), 1.5);
  vec2  q   = ROT(-rot)*d;

  float dens = clamp(0.35 + 1.15*fbm(q*2.2 + vec2(0.0, 0.08*TIME), 0.55), 0.0, 1.0);
  float temp = clamp(1.25*(DISK_OUT - rho)/(DISK_OUT - DISK_IN), 0.0, 1.0);

  // Doppler beaming: the side moving toward the camera lights up
  vec3  tang = normalize(vec3(-d.y, 0.0, d.x));
  float beta = clamp(0.45/sqrt(max(rho, 0.50)), 0.0, 0.85);
  float dop  = clamp(1.0 + dot(tang, -rd)*beta*2.2, 0.30, 2.30);

  vec3 col = blackbody(temp)*dens*pow(dop, 3.0);

  float innerEdge = smoothstep(DISK_IN, DISK_IN*1.30, rho);
  float outerEdge = 1.0 - smoothstep(DISK_OUT*0.72, DISK_OUT, rho);
  col *= innerEdge*outerEdge;

  // hot inner rim
  col += 0.6*blackbody(1.0)*exp(-24.0*pow(max(rho - DISK_IN, 0.0), 2.0))*dens;

  return col*disk_gain;
}

// ---------------------------------------------------------------- integration

vec3 traceRay(vec3 ro, vec3 rd0) {
  vec3 rd  = rd0;
  vec3 pos = ro;

  float prevY = pos.y;
  float b     = length(cross(rd0, normalize(ro)));

  vec3  col   = vec3(0.0);
  int   state = 0;   // 0 = escaped, 1 = disk hit, 2 = captured

  for (int i = 0; i < 30; ++i) {
    float r = length(pos);
    if (r < RS) { state = 2; break; }

    // bend the ray toward the hole
    vec3  dir = normalize(pos);
    float k   = min(LENS/(r*r + 1e-2), 2.0);
    float dt  = 0.10 + 0.14*r;
    rd        = normalize(rd - dir*k*dt);

    // volumetric relativistic jet along the spin axis
    if (jets > 0.001) {
      float dAx = length(vec2(pos.x, pos.z));
      float hy  = max(pos.y, 0.0);
      col += jets*vec3(0.30, 0.50, 1.0)*exp(-9.0*dAx*dAx)*exp(-0.85*hy)*dt*1.5;
    }

    vec3 npos = pos + rd*dt;

    // crossing the equatorial plane -> possible disk hit
    if (prevY > 0.0 && npos.y <= 0.0) {
      float tt  = prevY/(prevY - npos.y);
      vec3  hp  = pos + rd*(dt*tt);
      float rho = length(hp.xz);
      if (rho > DISK_IN && rho < DISK_OUT) {
        col += diskColor(hp.xz, rd);
        state = 1;
        break;
      }
    }

    prevY = npos.y;
    pos   = npos;
    if (r > 7.0) break;
  }

  if (state == 0) {
    col += starfield(rd);
  }

  if (state != 1) {
    // photon ring hugging the shadow
    col += vec3(1.00, 0.72, 0.38)*exp(-26.0*pow(max(b - RS*1.45, 0.0), 2.0))*0.9;
    col += vec3(0.55, 0.35, 0.90)*exp(-7.0*pow(max(b - RS*1.45, 0.0), 2.0))*0.10;
  }

  return col;
}

vec3 render(vec2 p) {
  vec3 ro = vec3(0.0, 0.95, 2.55);
  vec3 la = vec3(0.0, 0.0, 0.0);

  vec3 ww = normalize(la - ro);
  vec3 uu = normalize(cross(vec3(0.0, 1.0, 0.0), ww));
  vec3 vv = normalize(cross(ww, uu));

  float fov = 2.1;
  vec3  rd  = normalize(p.x*uu + p.y*vv + fov*ww);

  return traceRay(ro, rd);
}

vec3 postProcess(vec3 col, vec2 q) {
  col = 1.0 - exp(-1.25*max(col, vec3(0.0)));
  col = pow(col, vec3(1.0/2.2));
  col = mix(col, col.zyx*vec3(1.05, 0.95, 1.10), 0.15);
  col *= 0.5 + 0.5*pow(19.0*q.x*q.y*(1.0-q.x)*(1.0-q.y), 0.7);
  return clamp(col, 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 q = fragCoord/iResolution.xy;
  vec2 p = -1.0 + 2.0*q;
  p.x *= RESOLUTION.x/RESOLUTION.y;

  // slow orbital sway of the camera
  p.xy *= ROT(0.04*sin(TTIME/90.0));

  vec3 col = render(p);
  col = mix(vec3(0.0), col, smoothstep(0.4, 3.5, TIME));
  col = postProcess(col, q);

  fragColor = vec4(col, 1.0);
}
