//@settings dtype=float32 format=rgba
#define SPEED 0.5
#define NB_SHAPES 6.0

#define TRAIL_DUR 0.25
#define NB_REPEAT 16.0

//#define TRAIL_MODE

#define DRAW_CIRCLES
// AND / OR
#define DRAW_LINES


#define LINE_THICKNESS 0.0025
#define LINE_SHINE 0.005

float sqrLen(vec2 vec)
{
	return dot(vec, vec);  
}

vec2 pixelToNormalizedspace(vec2 pixel)
{
    vec2 res;
    res.x = pixel.x * 2.0 / iResolution.x - 1.0;
    res.y = pixel.y * 2.0 / iResolution.y - 1.0;
    res.y *= iResolution.y / iResolution.x;//correct aspect ratio
    return res;
}

vec2 rotate(vec2 pos, float angle)
{
    float rad = radians(angle);
 	mat2 rotM = mat2(vec2(cos(rad), -sin(rad)), vec2(sin(rad), cos(rad)));    
    return rotM * pos;
}

float circle(vec2 diff, float radius){
    return abs(length(diff) - radius);
}

float segment(vec2 diff, vec2 dir, vec2 dim)
{
    float projDist 	= dot(diff, dir);
	float dist = 0.0;

    dist += length(diff - dir * dim.x) * step(dim.x, projDist);
    dist += length(diff) * (1.0 - step(0.0, projDist));
    dist += length(diff - dir * projDist) * (step(0.0, projDist) - step(dim.x, projDist));
    return dist - dim.y;
}

float colorStrength(float dist){
	   return 1.0 - smoothstep(LINE_THICKNESS - LINE_SHINE,
                             LINE_THICKNESS + LINE_SHINE,
                             dist);
}

vec3 draw(vec2 pos, float time)
{ 
    vec3 col 		= vec3(0.0);    
    float colorStr 	= 0.0;    
    float colTime 	= 0.0;
            
#ifdef DRAW_CIRCLES
    vec2 circlePos = vec2(0.0);
    circlePos.x += cos(time) - cos(time * 5.0) * 0.5 - sin(time * 15.0) * 0.1;
    circlePos.y += sin(time) - sin(time * 3.0) * 0.5 + cos(time * 10.0) * 0.3;
    circlePos 	*= 0.3; 
    float dist = 0.05 + sqrLen(circlePos - vec2(0.5, 0.5)) * 0.1;
#endif
    
#ifdef DRAW_LINES    
    vec2 lineEnd = vec2(0.0);
  	lineEnd.x += (sin(time) * 0.5 - cos(time * 2.0)) * sin(time * 0.5);
    lineEnd.y += (cos(time) * 0.5 - sin(time * 2.0)) * sin(time * 0.5);
    lineEnd *= 0.3;    
    vec2 lineStart = vec2(0.0);
    lineStart.x -= (sin(time) * 0.5 + cos(time * 2.0)) * cos(time * 0.4);
    lineStart.y -= (cos(time) * 0.5 + sin(time * 2.0)) * cos(time * 0.4);
#endif             
     
    for(float a = 0.0; a < 359.0; a += 360.0 / NB_SHAPES)
    {
        colorStr = 0.0;
        colTime = time + 1.0 * a / 360.0;        
 	vec2 rotPos = rotate(pos, a);
        
 	#ifdef DRAW_CIRCLES        
        colorStr += colorStrength(circle(rotPos - circlePos, dist));
 	#endif 
        
 	#ifdef DRAW_LINES        
        vec2 seg = lineEnd - lineStart;
        colorStr += colorStrength(segment(rotPos - lineStart,
                                          normalize(seg),
                                          vec2(length(seg), LINE_THICKNESS)));        
 	#endif                
        col += vec3(0.5 + 0.5 * cos(colTime * 5.0),
                    0.5 + 0.5 * cos(colTime * 5.0 + 3.14),
                    0.5 + 0.5 * sin(colTime * 5.0)) * colorStr;
    }
       
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float startTime = iTime - iMouse.x / iResolution.x * 5.0;
    float time = 0.0;
    vec2 fragPos = pixelToNormalizedspace(fragCoord);
	vec2 uv = fragCoord.xy / iResolution.xy;        
    
    vec3 finalCol = vec3(0.0);
    
    float scale = 1.0;
    
    for(float rep = 0.0; rep < NB_REPEAT; ++rep)
    {              
        time = (startTime - rep * TRAIL_DUR/NB_REPEAT) * SPEED;
        finalCol += draw(fragPos * scale, time) * pow(1.0 - rep / NB_REPEAT, 2.0);                         
        #ifndef TRAIL_MODE
        scale *= 1.0 + TRAIL_DUR / NB_REPEAT;
        #endif
    }
    
	fragColor = vec4(finalCol, 1.0);
    fragColor = pow( fragColor, vec4(1.0/2.2));
}
