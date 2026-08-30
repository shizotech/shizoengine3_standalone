// ==== Custom Uniform Controls ====

//@float min=0.0 max=1.0 value=0.0
uniform float mirror_x;

//@float min=0.0 max=1.0 value=0.0
uniform float mirror_y;

//@int min=0 max=1 value=0
uniform int flip_x;

//@int min=0 max=1 value=0
uniform int flip_y;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // Clamp mirror thresholds to avoid errors
    float mx = clamp(mirror_x, 0.0, 1.0);
    float my = clamp(mirror_y, 0.0, 1.0);

    // Mirror around vertical axis (X)
    if (uv.x < mx) {
        uv.x = mix(mx, 1.0 - uv.x, 1.0); // mirror only the portion to the left of mx
    }

    // Mirror around horizontal axis (Y)
    if (uv.y < my) {
        uv.y = mix(my, 1.0 - uv.y, 1.0); // mirror only the portion below my
    }

	if(flip_x == 1)
		uv.x = 1.0 - uv.x;
	if(flip_y == 1)
		uv.y = 1.0 - uv.y;

    vec3 color = texture(iChannel0, uv).rgb;
    fragColor = vec4(color, 1.0);
}
