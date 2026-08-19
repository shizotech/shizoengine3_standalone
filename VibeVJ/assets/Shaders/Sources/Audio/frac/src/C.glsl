//@settings dtype=float32 format=rgba

void mainImage( out vec4 fragColor, in vec2 a )
{
    float soundWave = texture(iChannel0, vec2(0.6,0.3)).x;
    soundWave = smoothstep(0.,1., soundWave);
  
    fragColor = vec4(soundWave, 0.,0.,1.0);
}
