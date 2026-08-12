//density

//@settings dtype=float32

#include "util/shared.glsl"

uniform sampler2D A;

//density

void mainImage( out vec4 fragColor, in vec2 pos )
{
    R = iResolution.xy; time = iTime;
    ivec2 p = ivec2(pos);

    vec4 data = texel(A, pos);
    particle P = getParticle(data, pos);
    
    //particle render
    vec4 rho = vec4(0.);
    range(i, -1, 1) range(j, -1, 1)
    {
        vec2 ij = vec2(i,j);
        vec4 data = texel(A, pos + ij);
        particle P0 = getParticle(data, pos + ij);

        vec2 x0 = P0.X; //update position
        //how much mass falls into this pixel
        rho += 1.*vec4(P.V, P.M)*G((pos - x0)/0.75); 
    }
    
    fragColor = rho;
}