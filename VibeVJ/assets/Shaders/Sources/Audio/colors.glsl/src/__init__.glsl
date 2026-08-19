
//@settings dtype=float32 format=rgba

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - .5*iResolution.xy)/iResolution.y;
    
    vec3 r=vec3(1,0,0);
    vec3 y=vec3(1,1,0);
    vec3 g=vec3(0,1,0);
    vec3 b=vec3(0,0,1);
    vec3 ca[19];
    ca[1]=b*2./6.+r*4./6.;
    ca[2]=b*1./6.+r*5./6.;
    ca[3]=r;
    ca[4]=r*5./6.+y/6.;
    ca[5]=r*4./6.+y*2./6.;
    ca[6]=r*3./6.+y*3./6.;
    ca[7]=r*2./6.+y*4./6.;
    ca[8]=r*1./6.+y*5./6.;
    ca[9]=y;
    ca[10]=y*2./3.+g*1./3.;
    ca[11]=y*1./3.+g*2./3.;
    ca[12]=g;
    ca[13]=g*2./3.+b*1./3.;
    ca[14]=g*1./3.+b*2./3.;
    ca[15]=b;
    ca[16]=b*5./6.+r*1./6.;
    ca[17]=b*4./6.+r*2./6.;
    ca[18]=b*3./6.+r*3./6.;
    
    vec4 o=vec4(0,0,0,0);
    int c=0;
    for (float x=.0; x<acos(-1.)*2.;x+=acos(-1.)/18. )
    {
        c+=1;
        vec4 color=vec4(ca[c%18+1],0);   
        o+=color*vec4((texture(iChannel0,vec2(.3-x*.05)).r)*x/2.*.008/length(uv-.1*sin(iDate.w*.2)*(x+1.5)*vec2(sin(x),cos(x))));
        o+=color*vec4((texture(iChannel1,vec2(.3-x*.05)).r)*x/2.*.008/length(uv-.1*sin(iDate.w*.2)*(x+2.5)*vec2(sin(x),cos(x))));
    }
    o+=vec4(0,0,.2,1.0);
    
    fragColor = o;
}
