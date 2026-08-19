//@settings dtype=float32 format=rgba

// Altair2 - Audio texture pass
// Passes through iChannel0 with alpha based on audio FFT input
// This provides the background audio-reactive texture for the raymarching scene

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	// "in my crawl space"
	// Shadertoy port of Windows 4K intro:
	// https://www.pouet.net/prod.php?which=82169
	// https://www.youtube.com/watch?v=jw-nC5bINFc

	vec2 uv = (fragCoord.xy/iResolution.xy);
	fragColor = vec4(texture(iChannel0, uv).rgb, 1.0);
}
