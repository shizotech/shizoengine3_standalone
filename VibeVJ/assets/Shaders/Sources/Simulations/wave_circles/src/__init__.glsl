//@settings dtype=float32 format=rgba

#define U(u) texelFetch(prevBuffer, ivec2(u), 0)
const float FOCUS_DIST = .45;

const float BOUND_GAMMA = .1;

vec2 initWave(vec2 u, vec2 c, vec2 R)
{
    vec2 delta = u - c;
    float d2 = dot(delta, delta);

    float df = sqrt(d2);
    return 3. * R.x * vec2(sin(df), cos(df)) / (1. + d2 * 1e6);
}

void updateBuffer(out vec4 O, vec2 u, vec2 R, int iFrame, vec4 iMouse, sampler2D prevBuffer, sampler2D keyBuffer, bool bufferA)
{
    vec2 o = vec2(1, 0),
         p = (u - .5 * R) / R.y;

    vec4 state = texelFetch(prevBuffer, ivec2(0), 0);
    
    if (ivec2(u) == ivec2(0))
    {
        if (iFrame == 0 ||
            state.w != R.x * R.y)
        {
            O = vec4(0);
            O.w = R.x * R.y;
            return;
        }
        
        O = state;
        
        if (bufferA && ++O.z > 25.)
            O.z = 0.;
        
        return;
    }
    
    if (iFrame == 0 ||
        state.w != R.x * R.y)
    {
        O = vec4(0);
        return;
    }
    else
    {
        float C = p.y > 0. ? .5 : .2;

        O = U(u).xxyy;

        if (int(u.y) < 5)
            O.x = O.x - C * (O.x - U(u + o.yx).x) - BOUND_GAMMA*(O.x-O.z);
        else if (int(u.y) == int(R.y) - 1)
            O.x = O.x - C * (O.x - U(u - o.yx).x) - BOUND_GAMMA*(O.x-O.z);
        else if (int(u.x) == 0)
            O.x = O.x - C * (O - U(u + o)).x - BOUND_GAMMA*(O.x-O.z);
        else if (int(u.x) == int(R.x) - 1)
            O.x = O.x - C * (O - U(u - o)).x - BOUND_GAMMA*(O.x-O.z);
        else
            O.x = -O.z + 2.*O.x + C*(U(u + o) + U(u - o) + U(u + o.yx) + U(u - o.yx) - 4. * O).x;
    }

    if (bufferA)
    {
        if (iMouse.z > 0. && (state.z < 1. || iMouse.w > 0.))
            O.xy += initWave(u, iMouse.xy, R);
    }
    
    O *= .9995;
}

vec4 getColorFromHeight(float d)
{
    vec4 c = sin(d * 6e2 * vec4(9, 2, 5, 0));
    return pow(abs(c), vec4(3));
}

vec4 get_pixel(vec2 uv)
{
    return texture(iChannel1, (uv.xy / iResolution.xy));
}

void mainImage( out vec4 O, vec2 u)
{
    // Wave equation update with mouse interaction
    updateBuffer(O, u, iResolution.xy, iFrame, iMouse, iChannel0, iChannel2, true);
    
    if(get_pixel(u).r > 0.5)
    {
        O.xy += initWave(u, u, iResolution.xy);
    }
}
