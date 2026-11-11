//@settings dtype=uint8 format=rgba
// --- SlitScan, pass F: the slit-scan camera (Time mode Slit stack). Every frame the picture moves on by Scan speed
// pixels and the slit of the input fills the gap at the edge, so the picture is a record of what passed the slit ---
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D feedback;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;
    if (time_mode != 6 || iFrame < 2) {
        // not in use: keep the live picture, so Slit stack starts from it
        fragColor = texture(input, uv);
        return;
    }
    if (freeze) {
        fragColor = texelFetch(feedback, ivec2(fragCoord), 0);
        return;
    }
    // the speed in whole pixels of this picture (moving by fractions would blur the picture a bit more every frame)
    float sp = max(1.0, floor(scan_speed * res.y / 1080.0 + 0.5));
    int dir = scan_direction;
    // pos: how far this pixel is from the edge where the slits come in, along the run
    float pos;
    vec2 step_;
    if (dir == 0) { pos = res.x - fragCoord.x; step_ = vec2(1.0, 0.0); }
    else if (dir == 1) { pos = fragCoord.x; step_ = vec2(-1.0, 0.0); }
    else if (dir == 2) { pos = fragCoord.y; step_ = vec2(0.0, -1.0); }
    else if (dir == 3) { pos = res.y - fragCoord.y; step_ = vec2(0.0, 1.0); }
    else {
        float m = res.x * 0.5;
        pos = abs(fragCoord.x - m);
        step_ = vec2(fragCoord.x > m ? -1.0 : 1.0, 0.0);
    }
    if (pos < sp) {
        // the new slit: a column (or a row) of the input at Slit position, spread over the new pixels
        vec2 s = (dir == 2 || dir == 3) ? vec2(uv.x, slit_position) : vec2(slit_position, uv.y);
        fragColor = texture(input, s);
        return;
    }
    // the rest moves on: this pixel takes what was Scan speed pixels further in, one frame ago
    ivec2 src = ivec2(floor(fragCoord + step_ * sp));
    fragColor = texelFetch(feedback, clamp(src, ivec2(0), ivec2(res) - 1), 0);
}
