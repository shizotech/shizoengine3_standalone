//@settings dtype=float32 format=rgba
//ref:https://twitter.com/Pixelated_Donut/status/1756587677984461254
//ronwnor, @Pixelated_Donut (twitter)
void mainImage(out vec4 c,in vec2 f){
    vec2 u=14.*(f-iResolution.xy*.5)/iResolution.y,v=sin(u+iTime);
    float p=sin(4.*atan(v.y,v.x)+iTime-16.*length(v)+iTime);
    c=vec4(vec3(p<=.1?0.:1.),1.);
}
//before the golf:
/*
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = 14.0*(fragCoord - iResolution.xy * 0.5) / iResolution.y;
    float sinX = sin(uv.x + iTime);
    float sinY = sin(uv.y + iTime);
    float angle = atan(sinY, sinX) + iTime;
    float magnitude = length(vec2(sinX, sinY));
    //formula, remove all itimes for the static output 
    float pattern = sin(4.0 * angle - 16.0 * magnitude + iTime);
    vec3 color = pattern <= .1 ? vec3(0.0) : vec3(1.0);
    fragColor = vec4(color, 1.0);
}
*/
