
//@settings dtype=float32

#include "util/shared.glsl"

uniform sampler2D B;

void mainImage( out vec4 U, in vec2 pos )
{
    R = iResolution.xy; time = iTime; Mouse = iMouse;
    ivec2 p = ivec2(pos);

    vec4 data = texel(B, pos); 
    
    particle P;// = getParticle(data, pos);
       
    Reintegration(B, P, pos);
   
    //initial condition
    if(iFrame < 1)
    {
        //random
        vec3 rand = hash32(pos);
        if(rand.z < 0.) 
        {
            P.X = pos;
            P.V = 0.5*(rand.xy-0.5) + vec2(0., 0.);
            P.M = vec2(mass, 0.);
        }
        else
        {
            P.X = pos;
            P.V = vec2(0.);
            P.M = vec2(1e-6);
        }
    }
    
    U = saveParticle(P, pos);
}