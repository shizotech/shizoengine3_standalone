 // PulseRings - Expanding pulse rings from center or multiple pulse points
// Concentric rings expand outward and fade, creating a ripple/pulse effect
// Supports center, multi-point, and random pulse modes
//
// ==== Custom Uniform Controls ====

 //@slider min=0.05 max=5.0 value=1.0
 uniform float pulse_speed;

 //@rgb
uniform vec3 pulse_color;

 //@rgb
uniform vec3 bg_color;

 //@int min=1 max=8 value=3
 uniform int ring_count;

 //@slider min=0.01 max=0.3 value=0.05
 uniform float ring_width;

 //@enum options=(Center, Multi-Point, Random)
 uniform int pulse_mode;

 // Standard hash function
 float hash(vec2 p) {
     return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
 }

 // Calculate pulse rings based on distance from a source point
 float calc_rings(vec2 uv, vec2 origin) {
     float dist = distance(uv, origin);

     // Normalize distance by speed and time
     float t = dist - fract(iTime * pulse_speed) * 1.5;
     // Spread multiple rings evenly
     t *= float(ring_count);

     // Create ring pattern using modulo distance
     float ring_pos = fract(t);

     // Calculate ring proximity with width
     float ring = 1.0 - smoothstep(0.0, ring_width, abs(ring_pos - 0.5) * 2.0);

     // Fade rings based on distance from origin
     float fade = 1.0 - clamp(dist * 1.2, 0.0, 1.0);

     // Combine: rings fade out over distance
     return ring * fade;
 }

 void mainImage(out vec4 fragColor, in vec2 fragCoord) {
     // Normalize coordinates to 0..1 range
     vec2 uv = fragCoord / iResolution.xy;

     vec3 final_color = bg_color;

     if (pulse_mode == 0) {
         // Center: single origin at screen center
         vec2 center = vec2(0.5);
         float rings = calc_rings(uv, center);
         final_color = mix(final_color, pulse_color, rings);

     } else if (pulse_mode == 1) {
         // Multi-Point: four pulse points at cardinal positions
         vec2 points[4];
         points[0] = vec2(0.5, 0.0);  // top
         points[1] = vec2(0.0, 0.5);  // left
         points[2] = vec2(1.0, 0.5);  // right
         points[3] = vec2(0.5, 1.0);  // bottom

         float total_ring = 0.0;
         for (int i = 0; i < 4; i++) {
             total_ring += calc_rings(uv, points[i]);
         }
         total_ring = clamp(total_ring, 0.0, 1.0);
         final_color = mix(final_color, pulse_color, total_ring);

     } else {
         // Random: use hash to place pulse points
         // Generate up to 4 random pulse points based on frame
         vec2 points[4];
         for (int i = 0; i < 4; i++) {
             vec2 idx = vec2(float(i), 1.0);
             points[i] = vec2(
                 hash(idx + vec2(0.0, 0.0)),
                 hash(idx + vec2(0.0, 1.0))
             );
         }

         float total_ring = 0.0;
         for (int i = 0; i < 4; i++) {
             total_ring += calc_rings(uv, points[i]);
         }
         total_ring = clamp(total_ring, 0.0, 1.0);
         final_color = mix(final_color, pulse_color, total_ring);
     }

     // Output
     fragColor = vec4(final_color, 1.0);
}
