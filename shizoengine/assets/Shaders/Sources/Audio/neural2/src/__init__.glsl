//@settings dtype=float32 format=rgba rendersize=(3,64)

// Alias: iChannel0 = A (feedback from this pass), iChannel1 = AUDIO
// Shadertoy auto-detection via mainImage

float hash12(vec2 p) {
	float h = dot(p, vec2(127.1, 311.7));
    return fract(abs(sin(h) * 43758.5453123));
}

void mainImage(out vec4 C, in vec2 fragCoord)
{
	C = vec4(-.5);
    
    // buffer texture

    if (int(fragCoord.y) < 64) {
        
        float vol = texelFetch(iChannel1, ivec2(fragCoord.y * 2., 0), 0).r;
        
        // first column -- position
        if (int(fragCoord.x) == 0) {        

            if (iFrame == 0) {            

                // initial position
                C.x = (hash12(fragCoord.xy) / 2. - .5) + .75;
                C.y = (hash12(fragCoord.yx) / 2. - .5) * 2.;
				
                // initial speed vector
                C.z = (hash12(fragCoord.xy * C.xy) / 2. - .5) * 2.;
                C.w = (hash12(C.xy * 1000. + iDate.w * 100.) / 2. - .5) * 4.;

            } else {
                
                // previous frame
                C = texelFetch(iChannel0, ivec2(fragCoord.xy), 0) - .5;
                C.xy += (C.zw) * 0.01;
				C += .5;
            }

        }
        
        // second column -- nearest point position
        if (int(fragCoord.x) == 1) {
            float minDist = 2.;
            
            vec4 G = texelFetch(iChannel0, ivec2(0, fragCoord.y), 0); // 1st column
            vec4 P = texelFetch(iChannel0, ivec2(fragCoord.xy), 0); // 2nd column previous value
            
            C = G;
            
            // test all values stored in 1st column.
            for (int i = 0; i < 64; i++) {
            	vec4 H = texelFetch(iChannel0, ivec2(0, i), 0);
                float d = distance(G.xy, H.xy);
                
                if (d < minDist) {
                    if (d < 1. - vol) {
                        C.xy = H.xy;
                        minDist = d;
                        if (dot(G.xy, C.xy) > .5) {
                            C.w = 1.;
                        }
                        break;
                    } else {
                        C.xy = G.xy;
                    }
                }
            }
            
            C.w -= 0.1;
            C.w = max(C.w, 0.);
        }
        
        // third column - copy of sound texture
        if (int(fragCoord.x) == 2) {
            C.r = vol;
        }
        
        C = fract(C);
    }
}
