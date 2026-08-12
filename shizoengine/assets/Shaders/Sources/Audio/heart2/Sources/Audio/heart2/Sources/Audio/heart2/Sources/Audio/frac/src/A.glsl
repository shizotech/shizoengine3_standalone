//@settings dtype=float32 format=rgba

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    vec3 col = texture(iChannel0, uv).xyz;
  
    float offset = 0.02;
    float offset_speed = 1. * iTime;
    vec2 sunpos = vec2(0.5 + offset*sin(offset_speed), 0.5 + offset*cos(offset_speed));

    vec3 shine = col;
    float radi = 1.;
    int anz = 100;
    for (int n=1; n <= anz; n++)
    { 
      vec2 newUV = (uv-sunpos)*radi+sunpos;
      shine += 2./float(anz)*texture(iChannel0, newUV).xyz;
      radi -= 0.875/float(anz);
    }
    
    col = max(shine, col);

    fragColor = vec4(col,1.0);
}
