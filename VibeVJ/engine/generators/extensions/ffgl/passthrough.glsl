//The picture of the FFGL plugin: ffgl_loader.shio sets this input to its ffgl host. Everything after it (preview, OUT,
//Spout, NDI, display, video router, transform, projection mapping) is the one of a shader generator
uniform sampler2D ffgl_out;

void mainImage( out vec4 fragColor, in vec2 p )
{
	fragColor = texture( ffgl_out, p / iResolution.xy );
}
