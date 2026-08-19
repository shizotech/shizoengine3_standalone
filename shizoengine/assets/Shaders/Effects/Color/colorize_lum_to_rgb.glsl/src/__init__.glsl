//@slider min=0.0 max=1.0 value=1.0
uniform float Mix;
//@slider min=0.0 max=1.0 value=1.0
uniform float Saturation;
//@slider min=0.0 max=1.0 value=1.0
uniform float Value;
//@slider min=-1.0 max=1.0 value=0.0
uniform float HueOffset;
//@rgb value=(0.299,0.587,0.114)
uniform vec3 LuminanceWeightsColor;
//@slider min=-1.0 max=1.0 value=0.0
uniform float Keep_Background;



// ==== Custom Uniform Controls ====

// ==== HSV to RGB Helper ====
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// ==== Main ====
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
	vec4 original = texture(iChannel0, uv).rgba;
	vec3 col = original.rgb;

    float brightness = dot(col, LuminanceWeightsColor);
	//float simple_brightness = (col.r + col.g + col.b) / 3.0;

    // Optional: Skip hue mapping if pixel is close to black
	if(Keep_Background < 0.0)
	{
		float keep_bg2 = abs(Keep_Background);
		if (brightness < keep_bg2) {
			fragColor = vec4(vec3(0), 1.0);
			return;
		}
	}
    else if (brightness < Keep_Background) {
        fragColor = vec4(col, 1.0);
        return;
    }

    float hue = fract(brightness + HueOffset);

    vec3 hsv = vec3(hue, Saturation, Value);
    vec3 rgb = hsv2rgb(hsv);

    fragColor = vec4(rgb, 1.0) * Mix + (1.0 - Mix) * original;
}
