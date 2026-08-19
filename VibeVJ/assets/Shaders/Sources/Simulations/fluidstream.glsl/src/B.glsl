
//@settings dtype=float32

#include "util/shared.glsl"

uniform sampler2D A;

//@vec2 value=(0.8,0.9)
uniform vec2 Spawn1;
//@slider min=0 max=100 value=10 
uniform float Spawn1Size;
//@slider min=0 max=1 value=0.666 
uniform float Spawn1Dir;
//@slider min=0 max=1 value=0.1 
uniform float Spawn1Sway;

//@vec2 value=(0.2,0.9)
uniform vec2 Spawn2;
//@slider min=0 max=100 value=10 
uniform float Spawn2Size;
//@slider min=0 max=1 value=0.666 
uniform float Spawn2Dir;
//@slider min=0 max=1 value=0.86
uniform float Spawn2Sway;

//@slider min=0 max=10 value=1 
uniform float Speed;
//@slider min=0 max=10 value=1 
uniform float SwaySpeed;
//@slider min=0 max=50 value=5 
uniform float BorderW;

void mainImage( out vec4 U, in vec2 pos )
{
    R = iResolution.xy; time = iTime; Mouse = iMouse;
    ivec2 p = ivec2(pos);
        
    vec4 data = texel(A, pos); 
    
    particle P = getParticle(data, pos);
    
    
    if(P.M.x != 0.) //not vacuum
    {
        Simulation(A, P, pos);
    }
    
    if(length(P.X - R*vec2(Spawn1.x, Spawn1.y)) < Spawn1Size) 
    {
        P.X = pos;
        P.V = 0.5*Dir(PI*Spawn1Dir*2.0 + Spawn1Sway*sin(time * SwaySpeed));
        P.M = mix(P.M, vec2(fluid_rho, 1.), 0.4);
    }

    if(length(P.X - R*vec2(Spawn2.x, Spawn2.y)) < Spawn2Size) 
    {
        P.X = pos;
        P.V = 0.5*Dir(PI*Spawn2Dir*2.0 + Spawn2Sway*sin(time * SwaySpeed));
        P.M = mix(P.M, vec2(fluid_rho, 0.), 0.4);
    }
    
    U = saveParticle(P, pos);
}