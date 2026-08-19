//@settings dtype=float32 format=rgba

void mainImage( out vec4 fragColor, in vec2 a )
{
    float soundWave;
    float b = texture(iChannel0, vec2(0.,0.)).x;
    soundWave = b + texture(iChannel1, vec2(0.,0.)).x;

    fragColor = vec4(soundWave, 0.,0.,1.0);
}
