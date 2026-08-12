// Comment out this line before going full screen for a smoother experience.
#define AA 7

float time() { return iTime; }
vec3 grey = vec3(0.21, 0.72, 0.07); // grey scale http://www.johndcook.com/blog/2009/08/24/algorithms-convert-color-grayscale/
vec2 mouse() { return (-iResolution.xy + 2.0*iMouse.xy)/iResolution.y; } // proper mouse coords.

mat2 r(float th) {  vec2 a = sin(vec2(1.5707963, 0) + th); return mat2(a, -a.y, a.x); } // cosine-less rotation.

// screen movement. Need this for formula and textures.  
void animate(inout vec2 p) {
    p *= r(time()*0.1 + mouse().x);
	p.y += time()*0.3;
	p.x += 3.0*cos(time()*0.1);
}


// fractal is drawn via orbit trapping.
vec2 orb(vec2 p) {
	animate(p);
    
	float s = 1.0;
    float m = 1.0;
	
    // appolonian gasket fractal https://en.wikipedia.org/wiki/Apollonian_gasket
    // with a bit of a twist.
	for(int i = 0; i < 3; i++) {
		p = -1.0 + 2.0*fract(0.5 - 0.5*p);
		p *= 2.3/max(dot(p, p), 0.4);
       
		s = min(s, abs(cos(p.x)));
        m = min(m, abs((p.y)));
	}
	
	return vec2(s, m);
}


// simple 2.5d bump mapping.
vec3 bump(vec2 p, float e, float z) {
	vec2 r = vec2(e, 0.0); vec2 l = r.yx;
	vec3 g = vec3(orb(p + l).x - orb(p - l).x,
			   orb(p + r).x - orb(p - r).x,
			   z); //The "z" coordinate should be between -1.0, 0.0.  The closer to zero the more pop the geometry has.
	
	return normalize(g);
}

// texture 2.5d bump mapping.
vec3 texbump(sampler2D s, vec2 p, float e) {
    vec2 r = vec2(e, 0.0); vec2 l = r.yx;
    float ce = dot(grey, texture(s, p).rgb);
    vec3 g = (grey*mat3(
        texture(s, p - r).rgb,
        texture(s, p - l).rgb,
        vec3(ce)) - ce)/e;
    
    return normalize(g);
}

vec3 render(vec2 p) {
	vec3 rd = normalize(vec3(p, 1.0)); // "ray direction. This also doubles as the light.
	vec3 sn = bump(p, 0.01, -0.7);
	vec3 col = vec3(0);
    
    vec2 ma = orb(p);
    
    float occ = ma.x;
    float tm = pow(ma.y, 10.0); //texture mask
   
    animate(p);
    
   	sn = normalize(sn + 0.2*mix(texbump(iChannel1, p, 0.001), texbump(iChannel0, p, 0.01), tm)); // add bump mapping for textures.
    vec3 re = reflect(rd, sn);
	
    // diffuse and specular.
	col += pow(clamp(dot(-rd, sn), 0.0, 1.0), 10.0);
	col += pow(clamp(dot(-rd, re), 0.0, 1.0), 32.0);
    
    col *= mix(texture(iChannel1, p).rgb, texture(iChannel0, p).rgb, tm); // material
    col *= 3.0*occ; // ambient occlusion.
    
    // emission.
    p += vec2(1, 0);
    p = mod(p + 1.0, 2.0) - 1.0;
    float mask = smoothstep(0.7, 0.71, length(p));
    
    col += vec3(4.1, 4.2, 0.2)*pow(abs(occ), 8.0)*mask
        *smoothstep(-1.0, 1.0, cos(10.0*time() + 3.0*p.y));
    
    col += vec3(0.1, 5.0, 3.5)*pow(abs(occ), 9.0)*(1.0 - mask)
        *smoothstep(-1.0, 1.0, cos(5.0*time()));
    
	return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
	
	vec2 uv = fragCoord;
	vec2 of = vec2(0.3);
    
    // small bit of anti-aliasing.
    #ifdef AA
	const float aa = float(AA);
    #else
    const float aa = 1.0;
    #endif
	
	vec3 col = render((-iResolution.xy + 2.0*gl_FragCoord.xy)/iResolution.y);
	for(float i = 0.0; i < aa - 1.0; i++) {
		// super-sample around the center of the pixel.
		vec2 p = (-iResolution.xy + 2.0*(uv + of))/iResolution.y;
		col += render(p);
		of *= r(3.14159/8.0);
	}
	
	col /= aa;
	
	//col += 0.2*clamp(col, 0.0, 0.5);
	col = pow(col, vec3(1.0/2.2));
	fragColor = vec4(col, 1);
}