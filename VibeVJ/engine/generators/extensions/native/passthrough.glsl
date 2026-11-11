//The picture of a native asset (#201): native_loader.shio sets this input to the texture its plugin renders into.
//Everything after it (preview, OUT, Spout, NDI, display, video router, transform, projection mapping) is the one of a
//shader generator
uniform sampler2D native_out;

void mainImage( out vec4 fragColor, in vec2 p )
{
	fragColor = texture( native_out, p / iResolution.xy );
}
