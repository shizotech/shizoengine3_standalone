#define PI 3.14
#define TWO_PI 6.28

#define TIMESCALE 0.5

#define BLUR_STRENGTH 2.0
#define BLUR_RANGE 2.7

#define UI_COLOR vec4(0.5, 0.8, 1.0, 1.0)

float hash12(vec2 x)
{
    return fract(sin(dot(x, vec2(43.5287, 41.12871))) * 523.582);   
}

vec2 hash21(float x)
{
    return fract(sin(x * vec2(24.0181, 52.1984)) * 5081.4972);   
}

float hash11(float x)
{
    return fract(sin(x * 42.146291) * 4215.4827);   
}

vec2 hash22(vec2 x)
{
    return fract(sin(x * mat2x2(24.4372, 12.47864, 32.3874, 29.4873)) * 4762.832);  
}

mat2x2 rotationMatrix(in float angle)
{
    return mat2x2(-cos(angle), sin(angle), -sin(angle), -cos(angle));   
}

//Blur function
vec4 blur(in sampler2D sampler, in vec2 fragCoord, in vec2 resolution)
{
    vec2 uv = fragCoord / resolution;
    float blurStrength = distance(uv, vec2(0.5));
    blurStrength = pow(blurStrength, BLUR_RANGE) * (resolution.x / 100.0) * BLUR_STRENGTH;
    vec4 sum = vec4(0.0);
    vec2 pixelSize = vec2(1.0) / resolution;
    for (float x = -1.0; x <= 1.0; x += 1.0)
    {
        for (float y = -1.0; y <= 1.0; y += 1.0)
        {
            sum += texture(sampler, uv + vec2(x, y) * pixelSize * blurStrength);
        }
    }

    return sum / 9.0;
}

float circle(in vec2 uv, in float radius, in float width)
{
    return smoothstep(width, width * 0.5, abs(radius - length(uv)));
}

float softCircle(in vec2 uv, in float radius, in float width)
{
    return smoothstep(width, 0.0, abs(radius - length(uv)));
}

float hardCircle(in vec2 uv, in float radius, in float width)
{
    return smoothstep(width, width * 0.99, abs(radius - length(uv)));   
}

float dottedCircle(in vec2 uv, in float circleRadius, in float dotRadius, float dotsCount)
{
    float angle = atan(uv.y, uv.x);
    angle /= TWO_PI;
    angle += 0.5;
    angle = round(angle * dotsCount) / dotsCount;
    angle *= TWO_PI;
    vec2 dotPoint = vec2(circleRadius, 0.0) * rotationMatrix(angle);
    return smoothstep(dotRadius, dotRadius * 0.5, distance(dotPoint, uv));
}

float circularSector(vec2 uv, in float radius, in float width, in float cutAngle)
{
    float angle = atan(uv.y, uv.x) + PI;
    float circ = circle(uv, radius, width);
    return circ * smoothstep(cutAngle, cutAngle - 0.001, abs(angle - cutAngle));
}

float cutSector(in vec2 uv, in float cutAngle, in float offset)
{
    float angle = atan(uv.y, uv.x) + PI + offset;
    angle = mod(angle, TWO_PI);
    return smoothstep(cutAngle, cutAngle - 0.0001, abs(angle - cutAngle));
}

float dashedCircle(vec2 uv, in float radius, in float width, in float density)
{
    float angle = atan(uv.y, uv.x) + PI;
    angle /= TWO_PI;
    angle = fract(angle * density);
    float circ = circle(uv, radius, width);
    return circ * smoothstep(0.1, 0.11, abs(angle - 0.5));
}

float dottedGrid(vec2 uv, in vec2 gridSpaces, float dotRadius)
{
    uv = mod(uv, gridSpaces) - gridSpaces * 0.5;
    return smoothstep(dotRadius, 0.0, abs(length(uv) - dotRadius));
}

float lineGrid(vec2 uv, in vec2 gridSpaces, float lineWidth)
{
    uv = mod(uv, gridSpaces) - gridSpaces * 0.5;
    float verticalLines = smoothstep(lineWidth, lineWidth * 0.5, abs(uv.x - lineWidth));
    float horizontalLines = smoothstep(lineWidth, lineWidth * 0.5, abs(uv.y - lineWidth));
    return verticalLines + horizontalLines;
}

float writings(vec2 uv, in float linesCount, in float maxLen, in float height, in float hash)
{
    float mul = 
        smoothstep(0.0, 0.01, uv.x) 
        * smoothstep(0.0, 0.01, uv.y)
        * smoothstep(height, height - 0.001, uv.y);
    
    uv.y = clamp(uv.y, 0.0, height);
    uv.y *= linesCount;
    float len = hash11(floor(uv.y - linesCount) + hash) * maxLen;
    return smoothstep(len, len * 0.5, uv.x) * hash12(uv) * mul * fract(uv.y);
}

float writingsGrid(vec2 uv, in vec2 gridSpace, in float scale)
{
    uv /= gridSpace;
    vec2 floorUV = floor(uv);
    vec2 fractUV = fract(uv);
    
    fractUV -= hash22(floorUV) * (1.0 - (1.0 / scale)) * (sin(iTime * 0.6 * TIMESCALE + hash12(floorUV) * 12.0) * 0.5 + 0.5);
    fractUV *= scale;
    
    float writing = writings(fractUV, 10.0 * hash12(floorUV) + 5.0, 1.0, hash12(floorUV + 0.1) * 0.6, 1.0);
    
    return writing;
}

vec3 uvToCameraPlanePoint(in vec2 uv)
{
    return vec3(uv.x, uv.y, 1.5 + sin(iTime * TIMESCALE * 0.3) * 0.2);   
}

//xy - plane uv
//z - plane height
//w - distance to plane
vec4 raycastPlane(in vec3 rayOrigin, vec3 rayDirection, in float planeHeight)
{
    float distanceToPlane = abs(rayOrigin.y - planeHeight);   
    rayDirection /= rayDirection.y;
    rayDirection *= distanceToPlane;
    vec3 hitPoint = rayOrigin + rayDirection;
    
    return vec4(hitPoint.x, hitPoint.z, hitPoint.y, length(rayDirection));
}
