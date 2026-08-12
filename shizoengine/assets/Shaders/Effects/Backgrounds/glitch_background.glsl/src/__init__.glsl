//@settings dtype=float32 format=rgba

float hs(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}


//All audio code from https://www.shadertoy.com/view/ltlyRM
float getLevel(float samplePos){
	int tx = int(samplePos*512.0);
	return texelFetch( iChannel0, ivec2(tx,0), 0 ).x; 
}

float toLog(float value, float min, float max){
	float exp = (value-min) / (max-min);
	return min * pow(max/min, exp);
}

vec3 hsl( in vec3 c )
{
    vec3 rgb = clamp( abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0, 1.0 );

    return c.z + c.y * (rgb-0.5)*(1.0-abs(2.0*c.z-1.0));
}
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{

    vec2 uv = (fragCoord-.5*iResolution.xy)/iResolution.y;
    vec2 uv1;
        
    float t =  iTime*1.7+ 60.;
    //uv.x -= .5*sin(t/12.);
    vec3 col =vec3(1.);
    for(float i=1.; i<100.;i++){
    float dir = mod(i,3.5)>1. ? uv1.y +uv.x: uv1.x+uv.y;
    float xPos = toLog(dir+0.5, 0.1, 8.2);
    float fft  = pow(abs(sin(getLevel(xPos)*1.5)),2.4);
    float sc = .8*pow(i+fft/22222222.,1.4);
    

    vec2 uv1 = ceil(uv*sc)/sc+t/152222222.;
    col.x *= (0.185+pow(abs(hs(uv1+vec2((2.7*pow(fft,3.)+t)/21111111.))),.9/i));
    col.y *= (0.185+pow(abs(hs(uv1+vec2((2.8*pow(fft,3.)+t)/21111111.))),.9/i));
    col.z *= (0.185+pow(abs(hs(uv1+vec2((2.9*pow(fft,3.)+t)/21111111.))),.9/i));
    uv +=0.3;
    }
  
    
      
    
    col = 1.2*col-0.08*hsl(col*vec3(.0000006,.006,.00005)+vec3(-.5,11111.8,11.));
    fragColor = vec4(pow(col*.0000007,vec3(1.5)),1.0);
}
