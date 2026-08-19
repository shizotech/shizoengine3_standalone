//@settings dtype=float32 format=rgba
uniform sampler2D input1;
uniform sampler2D AUDIO;

#define freqStart -1.0
#define freqInterval 0.01
#define sampleSize 0.02           // How accurately to sample spectrum, must be a factor of 1.0

float glow_radius = 0.00002;
float glow_intens = 0.00125;
float glow_blur_step = 0.5;
float glow_num_steps = 1.0; // 1.0 is hollywood glow :))

float fixcolor(float x) {
    return 1.0-round(x*glow_num_steps)/glow_num_steps;
}

float getcolor(vec2 uv) {
    vec4 c = texture(input1, uv);
    return max(fixcolor(c.r),max(fixcolor(c.g),fixcolor(c.b)));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 v = fragCoord.xy / iResolution.xy;
    float val = texture(AUDIO, vec2(.3,.152)).r;//;sin(iDate.w)/2.+.5;
    float val2 = texture(AUDIO, vec2(.3,.152)).r;//;sin(iDate.w)/2.+.5;
    vec2 offset = (v-.5)*val;
    float dist = distance(v,vec2(.5));
    vec2 uv = v-offset*dist;
    //vec2 uv = fragCoord/iResolution.xy;
    float mdst = dist/distance(vec2(.5), vec2(1.));
    float distanceMul = ((((uv.x>1.)||(uv.x<0.))||((uv.y>1.)||(uv.y<0.)))?0.:1.);    
    vec2 xy = fragCoord.xy / iResolution.xy;  
    
    vec4 c = texture(input1, uv)*val2;
     
    float d = 0.0;    
    for (float x=0.0; x<1.0; x+=glow_blur_step) 
        for (float y=0.0; y<1.0; y+=glow_blur_step) {
            d += getcolor(uv+glow_radius*vec2(x-0.5, y-0.5));
        }
    
    float glow_intens2 = texture(AUDIO, vec2(1,0)).r;//;sin(iDate.w)/2.+.5;

    d *= glow_intens2*.2;
    
    float intensity = 0.0;
	for(float s = 0.0; s < freqInterval; s += freqInterval * sampleSize) {
		intensity += texture(AUDIO, vec2(freqStart + s, 0.0)).r;
	}
    intensity = abs(intensity)*1.0;
    intensity = pow((intensity*sampleSize),3.0)*4.0;
    
    
    //set offsets
    vec2 rOffset = vec2(-0.02,0)*intensity;
    vec2 gOffset = vec2(0.0,0)*intensity;
    vec2 bOffset = vec2(0.04,0)*intensity;
    
    vec4 rValue = texture(input1, xy - rOffset);
    vec4 gValue = texture(input1, xy - gOffset);
    vec4 bValue = texture(input1, xy - bOffset);

    
    fragColor = vec4(rValue.r, gValue.g, bValue.b, 1.0)*0.6; //rgb effect
    fragColor += distanceMul*texture(input1,uv, (dist*val)*25.); //fisheye effect
    fragColor += vec4(d,d,d,d)+c; //glow effect
}
