//@settings dtype=float32 format=rgba

#define sat(a) clamp(a, 0., 1.)
#define PI acos(-1.)

mat2 r2d(float a) {
    float c = cos(a), s = sin(a); return mat2(c, -s, s, c);
}

float lenny(vec2 v)
{
    return abs(v.x)+abs(v.y);
}

#define N 96
// Thanks IQ :)
// Polygon - exact   (https://www.shadertoy.com/view/wdBXRW)
float sdPolygon( in vec2[N] v, in vec2 p )
{
    float d = dot(p-v[0],p-v[0]);
    float s = 1.0;
    for( int i=0, j=N-1; i<N; j=i, i++ )
    {
        vec2 e = v[j] - v[i];
        vec2 w =    p - v[i];
        vec2 b = w - e*clamp( dot(w,e)/dot(e,e), 0.0, 1.0 );
        d = min( d, dot(b,b) );
        bvec3 c = bvec3(p.y>=v[i].y,p.y<v[j].y,e.x*w.y>e.y*w.x);
        if( all(c) || all(not(c)) ) s*=-1.0;  
    }
    return s*sqrt(d);
}
vec3 flare(vec2 uv)
{
    return vec3(0.424,0.596,0.996)*(1.-sat(lenny(uv*vec2(1.,4.))))*2.;
}
vec3 chromaflare(vec2 uv)
{
    vec2 off = vec2(0.05);
    
    vec3 col = vec3(0.);
    col.x += flare(uv+off).x;
    col.y += flare(uv).y;
    col.z += flare(uv-off).z;
    return col;
}
vec3 rdr(vec2 uv)
{
    vec2 ouv = uv;
    vec3 col = vec3(0.);
    float basean = atan(uv.y, uv.x);
    float cnt = 6.;
    for (float i = 0.; i < cnt; ++i)
    {
        float sides = PI*2./cnt;
        float an = basean+i*2.+iTime*.05*mix(1.,1.5,i/cnt);
        float sectors = mod(an+sides*.5,sides)-sides*.5;
        vec2 newuv = vec2(sin(sectors), cos(sectors))*length(uv);
    
        vec2 curuv = newuv+sin(i+iTime*.2)*.05;
        float sz = mix(0.05,0.4, pow(i/cnt,2.)+sin(i+iTime)*.04);
        float shape = abs(curuv.y-sz)-mix(0.01, 0.03, i/cnt);
        vec3 rgb = texture(iChannel0, curuv*7.).xyz*mix(0.2, 1.,pow(i/cnt, .5));
        vec3 outrgb = rgb *(1.-sat(shape*500.));
        outrgb += rgb *(1.-sat(shape*20.))*.35;
        outrgb = mix(outrgb*vec3(1.,.3,.3)*.5, outrgb, pow(i/cnt,2.));
        col += outrgb;
        
        float shape2 = abs(curuv.y-sz-.1)-mix(0.01, 0.03, i/cnt)*.1;
        col += vec3(1.000,0.000,0.349)*(1.-sat(shape2*100.))*sat(sin(curuv.x*100.)*.5+.5);
    }
    
    col += chromaflare(uv)*.8;
    col += pow(texture(iChannel1, vec2(basean, +iTime*.03+1./length(uv)*.02)).x, 5.)
    *vec3(1.000,0.533,0.220)*sat(length(uv)*2.);
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{    
    vec2 uv = (fragCoord.xy-.5*iResolution.xy)/iResolution.xx;
    uv *= r2d(sin(iTime*.2)*.2);
    uv *= mix(1.2,1., sin(iTime)*.5+.5);
    uv += vec2(sin(iTime*.33), cos(iTime*.14))*.05;
    vec3 col = rdr(uv);
    col += sat(sin(uv.y*800.)*.5+.5)*vec3(0.,0.,1.)
    *texture(iChannel1, uv*.1).x;

vec2 points[96];
points[0] = vec2(0.07991514, 0.6348686);
points[1] = vec2(0.09641513, 0.6812686);
points[2] = vec2(0.1307151, 0.6464686);
points[3] = vec2(0.1583152, 0.5911686);
points[4] = vec2(0.1826151, 0.5790686);
points[5] = vec2(0.3704152, 0.7149686);
points[6] = vec2(0.4047152, 0.6834686);
points[7] = vec2(0.4323151, 0.6630686);
points[8] = vec2(0.4787152, 0.6155686);
points[9] = vec2(0.4980151, 0.6072686);
points[10] = vec2(0.5272151, 0.6442686);
points[11] = vec2(0.5205151, 0.6559686);
points[12] = vec2(0.5032151, 0.6677686);
points[13] = vec2(0.4838151, 0.6904686);
points[14] = vec2(0.4563152, 0.7153686);
points[15] = vec2(0.4331152, 0.7304686);
points[16] = vec2(0.4336151, 0.7369686);
points[17] = vec2(0.4428152, 0.7374686);
points[18] = vec2(0.4341151, 0.7477686);
points[19] = vec2(0.4422151, 0.7499686);
points[20] = vec2(0.4568152, 0.7289686);
points[21] = vec2(0.5232152, 0.6819686);
points[22] = vec2(0.5581151, 0.6800686);
points[23] = vec2(0.6139151, 0.6791686);
points[24] = vec2(0.6362152, 0.6824686);
points[25] = vec2(0.6400151, 0.7090686);
points[26] = vec2(0.6488152, 0.7315686);
points[27] = vec2(0.6641151, 0.7491686);
points[28] = vec2(0.6927152, 0.7535686);
points[29] = vec2(0.7133151, 0.7368686);
points[30] = vec2(0.7185152, 0.7181686);
points[31] = vec2(0.7108151, 0.7005686);
points[32] = vec2(0.7003151, 0.6865686);
points[33] = vec2(0.6956152, 0.6818686);
points[34] = vec2(0.7272152, 0.6703686);
points[35] = vec2(0.7440152, 0.6698686);
points[36] = vec2(0.7586151, 0.6709686);
points[37] = vec2(0.7721151, 0.6867686);
points[38] = vec2(0.8005152, 0.7258686);
points[39] = vec2(0.8090152, 0.7407686);
points[40] = vec2(0.8056152, 0.7637686);
points[41] = vec2(0.8037151, 0.7737686);
points[42] = vec2(0.7913151, 0.7873686);
points[43] = vec2(0.8020152, 0.7975686);
points[44] = vec2(0.8092152, 0.7928686);
points[45] = vec2(0.8239151, 0.7834686);
points[46] = vec2(0.8337151, 0.7851686);
points[47] = vec2(0.8539152, 0.8061686);
points[48] = vec2(0.8656151, 0.8275687);
points[49] = vec2(0.8872151, 0.8470686);
points[50] = vec2(0.9019151, 0.8530686);
points[51] = vec2(0.9071151, 0.8455686);
points[52] = vec2(0.9032152, 0.8399686);
points[53] = vec2(0.8850151, 0.8208686);
points[54] = vec2(0.8781152, 0.7945686);
points[55] = vec2(0.8781152, 0.7945686);
points[56] = vec2(0.9031152, 0.8075686);
points[57] = vec2(0.9369152, 0.8220686);
points[58] = vec2(0.9477152, 0.8270686);
points[59] = vec2(0.9574151, 0.8159686);
points[60] = vec2(0.9347152, 0.8032686);
points[61] = vec2(0.9051151, 0.7872686);
points[62] = vec2(0.9123151, 0.7730686);
points[63] = vec2(0.9657152, 0.7579686);
points[64] = vec2(0.9621152, 0.7407686);
points[65] = vec2(0.9004152, 0.7545686);
points[66] = vec2(0.9154152, 0.7294686);
points[67] = vec2(0.9296151, 0.7120686);
points[68] = vec2(0.9118152, 0.7103686);
points[69] = vec2(0.8928151, 0.7309686);
points[70] = vec2(0.8560151, 0.7143686);
points[71] = vec2(0.8241152, 0.6755686);
points[72] = vec2(0.7808151, 0.6225686);
points[73] = vec2(0.7658151, 0.6148686);
points[74] = vec2(0.7096151, 0.6286686);
points[75] = vec2(0.6771151, 0.6168686);
points[76] = vec2(0.6319152, 0.5926686);
points[77] = vec2(0.5773152, 0.5832686);
points[78] = vec2(0.5221152, 0.5104686);
points[79] = vec2(0.4818152, 0.4475686);
points[80] = vec2(0.4365152, 0.3935686);
points[81] = vec2(0.3971151, 0.3436686);
points[82] = vec2(0.3534151, 0.3056686);
points[83] = vec2(0.3452151, 0.2660686);
points[84] = vec2(0.3241152, 0.2577686);
points[85] = vec2(0.3195151, 0.2767686);
points[86] = vec2(0.3452151, 0.3132686);
points[87] = vec2(0.3786151, 0.3605686);
points[88] = vec2(0.4115151, 0.4078686);
points[89] = vec2(0.4125152, 0.4381686);
points[90] = vec2(0.4658151, 0.5361686);
points[91] = vec2(0.3673151, 0.6462686);
points[92] = vec2(0.2527151, 0.5852686);
points[93] = vec2(0.1579151, 0.5152686);
points[94] = vec2(0.1217152, 0.5070686);
points[95] = vec2(0.1044151, 0.5581686);

    float spider = sdPolygon(points, (uv+.4)*1.5);
    vec3 rgbspider = mix(vec3(0.), 
    sat(sin(uv.y*1200.)*.3+.7)*vec3(1.000,0.580,0.333), sat((length(uv)-.2)*15.));
    float eyes = length((uv-vec2(0.07,.08))*r2d(.5)*vec2(.8,.6))-.01;
    eyes = min(eyes, length((uv-vec2(0.04,.09))*r2d(.5)*vec2(.8,.6))-.01);
    rgbspider = mix(rgbspider, vec3(1.,0.,0.)*length((uv-vec2(0.04,.09))*30.), 1.-sat((abs(eyes)-0.005)*500.));
    rgbspider = mix(rgbspider, vec3(1.), 1.-sat(eyes*500.));
    col = mix(col, rgbspider, (1.-sat(spider*500.))*.75);
    col += vec3(1.000,0.580,0.333)*(1.-sat((abs(spider-0.01)-0.001)*200.));

    fragColor = vec4(col,1.0);
}
