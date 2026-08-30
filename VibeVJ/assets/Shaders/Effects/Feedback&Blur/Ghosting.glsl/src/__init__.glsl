
//@settings dtype=float32

uniform sampler2D input;
uniform sampler2D feedback;

// ==== Custom Uniform Controls ====

//@slider min=0 max=1 value=0.99
uniform float ghosting;
//@enum options=(Default, Add, Add2) 
uniform int mode;
//@slider min=0 max=1 value=0.0
uniform float blur;
//@slider min=-1 max=1 value=0.0 
uniform float feedback_flow;
//@slider min=0 max=100 value=5
uniform float blur_radius;
//@slider min=0 max=2 value=1.0
uniform float gain;

// Fast separable blur (approximate, much cheaper)
vec4 fastBlur(sampler2D tex, vec2 uv, float blurAmt, float radius) {
    if (blurAmt <= 0.0 || radius < 1.0) return texture(tex, uv);

    vec4 sum = vec4(0.0);
    float total = 0.0;
    int rad = int(clamp(radius, 1.0, 20.0));
    float stepSize = 1.0;

    // Horizontal blur
    for (int i = -20; i <= 20; ++i) {
        if (abs(i) > rad) continue;
        float w = 1.0 - abs(float(i)) / float(rad);
        vec2 offset = vec2(i * stepSize, 0.0) / iResolution.xy;
        sum += texture(tex, uv + offset) * w;
        total += w;
    }

    vec4 hBlur = sum / total;

    // Vertical blur
    sum = vec4(0.0);
    total = 0.0;
    for (int i = -20; i <= 20; ++i) {
        if (abs(i) > rad) continue;
        float w = 1.0 - abs(float(i)) / float(rad);
        vec2 offset = vec2(0.0, i * stepSize) / iResolution.xy;
        sum += texture(tex, uv + offset) * w;
        total += w;
    }

    vec4 vBlur = sum / total;

    // Mix the result
    return mix(texture(tex, uv), 0.5 * (hBlur + vBlur), blurAmt);
}

void mainImage(out vec4 o, in vec2 p) {
    vec2 uv = p / iResolution.xy;

    // Flow feedback outward or inward
    vec2 flowDir = uv - 0.5;
    uv += flowDir * 0.01 * feedback_flow;

    // Fast blur
    vec4 feedbackvec = fastBlur(feedback, uv, blur, blur_radius);
    vec4 inputTex = texture(input, uv);

	float ghosting_curve = 1.0 - ghosting;
	ghosting_curve = pow(ghosting_curve, 4.0);
	ghosting_curve = 1.0 - ghosting_curve;

    // Combine feedback and input
    if (mode == 0)
        o = feedbackvec * ghosting_curve + inputTex * (1.0 - ghosting_curve) * gain;
    else if(mode == 1)
        o = feedbackvec * ghosting_curve + inputTex * gain;
	else if(mode == 2) {
		float tresh = max(inputTex.r, max(inputTex.g, inputTex.b));
		if(tresh >= 0.5)
			o = inputTex * gain;
		else
			o = max(feedbackvec * ghosting_curve, inputTex * gain);
	}
	o = clamp(o, vec4(0,0,0,0), vec4(1,1,1,1));
	
	o.a = 1.0;
}
