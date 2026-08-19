//@settings dtype=float32 format=rgba
#define DISCO 1
#define time iTime*.05+300.
#define tau 6.2831
vec2 hash( vec2 p )
{
    //p = mod(p, 4.0); // tile
    p = vec2(dot(p,vec2(127.1,311.7)),
             dot(p,vec2(269.5,183.3)));
    
    return fract(sin(p)*18.5453);
}




// Compact, self-contained version of IQ's 2D value noise function.
float n2D(vec2 p){
   
    // Setup.
    // Any random integers will work, but this particular
    // combination works well.
    const vec2 s = vec2(1, 113);
    // Unique cell ID and local coordinates.
    vec2 ip = floor(p); p -= ip;
    // Vertex IDs.
    vec4 h = vec4(0., s.x, s.y, s.x + s.y) + dot(ip, s);
   
    // Smoothing.
    p = p*p*(3. - 2.*p);
    //p *= p*p*(p*(p*6. - 15.) + 10.); // Smoother.
   
    // Random values for the square vertices.
    h = fract(sin(h)*43758.5453);
   
    // Interpolation.
    h.xy = mix(h.xy, h.zw, p.y);
    return mix(h.x, h.y, p.x); // Output: Range: [0, 1].
}
// FBM -- 4 accumulated noise layers of modulated amplitudes and frequencies.
float fbm(vec2 p){ return n2D(p)*.533 + n2D(p*2.)*.267 + n2D(p*4.)*.133 + n2D(p*8.)*.067; }


// return distance, and cell id
vec2 voronoi( in vec2 x )
{
    vec2 n = floor( x );
    vec2 f = fract( x );

	vec3 m = vec3( 8.0 );
    for( int j=-1; j<=1; j++ )
    for( int i=-1; i<=1; i++ )
    {
        vec2  g = vec2( float(i), float(j) );
        vec2  o = hash( n + g );
      //vec2  r = g - f + o;
	    vec2  r = g - f + (0.5+0.5*sin(time+tau*o));
		float d = dot( r, r );
        if( d<m.x )
            m = vec3( d, o );
    }

    return vec2( sqrt(m.x), m.y+m.z );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = fragCoord.xy/max(iResolution.x,iResolution.y);
    p-=20.;
    p.x+=22.*sin(0.1*iTime)/15.;
    p.y+=22.*cos(0.1*iTime)/15.;
    p *= .9;
    //p.y+=.45;
    // compute voronoi patterm
    vec2 c = p/20.*voronoi( (8.0+2.0*sin(0.2*time))*p*fbm(p) );
    //c = c-voronoi( (8.0+2.0*sin(0.2*time))*p*fbm(p) );

    vec2 stt =  vec2(atan(c.x,p.y), length(p));
    #if DISCO
    stt = stt+voronoi( (1.0+2.0*sin(0.2*time))*p*fbm(p) );
    #endif
    // colorize
    //vec3 col =  vec3(c.y,c.x,1.-p.x) ;	
    vec3 col = 0.5 + 0.5*cos( stt.y*stt.x*6.2831 + vec3(0.0,smoothstep( 0.08, 0.7, fbm(stt)),smoothstep( 0.7, 0.9, fbm(stt))) );	
    // gradient
    //col *= clamp(1.0 - 0.4*c.x*c.x,0.0,1.0);
    col *= vec3(0.5+0.5*cos(44.*time),0.5+0.5*sin(22.*time),0.5+0.5*sin(11.*time));
    // dots
    //col -= (1.0-smoothstep( 0.08, 0.09, c.x));
    
    // the matrix color effect
    col.r = pow(col.r,3./2.);
    col.g = pow(col.g,4./5.);
    col.g = pow(col.g,3./2.);
	
    fragColor = vec4( col, 1.0 );
   
}
