 // Dimm-Video Utility Effect
 // Dims its input by multiplying it with a white (grey) overlay whose
 // strength is controlled by the 'brightness' slider.
 // brightness = 1.0  -> input shown at full brightness (no dim)
 // brightness = 0.0  -> fully dimmed (black)
 //
 // Reference: assets/Shaders/Sources/Basic/SimpleColor.glsl

 // ==== Custom Uniform Controls ====

 //@slider min=0.0 max=1.0 value=1.0
 uniform float brightness;

 void mainImage( out vec4 fragColor, in vec2 fragCoord )
 {
     vec2 uv = fragCoord / iResolution.xy;

     vec4 input = texture(iChannel0, uv);

     // Multiply the input by a white/grey 'brightness' value -> dims it.
     fragColor = input * brightness;
 }
