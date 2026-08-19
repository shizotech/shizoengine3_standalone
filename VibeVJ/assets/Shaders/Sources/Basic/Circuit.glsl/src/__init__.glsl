

// ==== Custom Uniform Controls ====
//@float min=0.01 max=2.0 value=0.3
uniform float circuit_speed;
//@float min=0.1 max=1.0 value=0.5
uniform float circuit_density;
//@float min=5.0 max=50.0 value=20.0
uniform float circuit_grid_size;
//@rgb value=(0.0,1.0,0.0)
uniform vec3 circuit_colors;
//@float min=0.0 max=2.0 value=0.5
uniform float circuit_glow;
//@float min=0.0 max=2.0 value=0.5
uniform float circuit_data_flow;
//@int min=1 max=5 value=3
uniform int circuit_complexity;
//@float min=0.0 max=1.0 value=0.5
uniform float circuit_nodes;

// ============================================================
// HASH & NOISE FUNCTIONS
// ============================================================

float hash1(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float hash2(vec2 p) {
    p = fract(p * vec2(223.45, 789.12));
    p += dot(p, p + 12.67);
    return fract(p.x * p.y);
}

// Pseudo-random angle
float hashAngle(vec2 p) {
    return hash1(p) * 6.28318; // 2*PI
}

// Simple 2D noise
float noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep
    
    float a = hash1(i);
    float b = hash1(i + vec2(1.0, 0.0));
    float c = hash1(i + vec2(0.0, 1.0));
    float d = hash1(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// ============================================================
// CIRCUIT BOARD GENERATION
// ============================================================

// Check if a grid cell has a horizontal trace
bool hasHorizontalTrace(vec2 gridPos, float time) {
    float h = hash1(gridPos * 3.5 + floor(time * circuit_speed * 0.1));
    return h < circuit_density * 0.4;
}

// Check if a grid cell has a vertical trace
bool hasVerticalTrace(vec2 gridPos, float time) {
    float v = hash2(gridPos * 2.7 + floor(time * circuit_speed * 0.1));
    return v < circuit_density * 0.4;
}

// Get trace direction from grid position
float getTraceDir(vec2 gridPos, float time) {
    float dir = hash1(gridPos * 1.3 + vec2(0.5));
    return dir;
}

// Draw a horizontal line with animated flow
float drawHLine(vec2 uv, float y, float xMin, float xMax, float time, float flow) {
    float t = time * flow * 3.0;
    float line = 0.0;
    
    // Draw line segment
    float seg = step(xMin, uv.x) * step(uv.x, xMax) * step(abs(uv.y - y), 0.015);
    
    // Animated flow pulse
    float pulse = sin((uv.x - xMin) * 20.0 + t) * 0.5 + 0.5;
    pulse = smoothstep(0.3, 0.7, pulse);
    
    // Traveling data packet
    float packetPos = fract(t * 0.1);
    float packet = 1.0 - smoothstep(0.01, 0.03, abs(uv.x - (xMin + packetPos * (xMax - xMin))));
    
    line = mix(seg * (0.5 + 0.5 * pulse), seg * 1.5, packet);
    return line;
}

// Draw a vertical line with animated flow
float drawVLine(vec2 uv, float x, float yMin, float yMax, float time, float flow) {
    float t = time * flow * 3.0;
    float line = 0.0;
    
    float seg = step(yMin, uv.y) * step(uv.y, yMax) * step(abs(uv.x - x), 0.015);
    
    float pulse = sin((uv.y - yMin) * 20.0 + t) * 0.5 + 0.5;
    pulse = smoothstep(0.3, 0.7, pulse);
    
    float packetPos = fract(t * 0.1 + hash2(vec2(x, yMin)) * 10.0);
    float packet = 1.0 - smoothstep(0.01, 0.03, abs(uv.y - (yMin + packetPos * (yMax - yMin))));
    
    line = mix(seg * (0.5 + 0.5 * pulse), seg * 1.5, packet);
    return line;
}

// Draw circuit node (junction)
float drawNode(vec2 uv, vec2 pos, float size, float time) {
    float d = length(uv - pos);
    float pulse = sin(time * 2.0 + hash1(pos * 10.0) * 6.28) * 0.3 + 0.7;
    float node = smoothstep(size, size * 0.3, d) * pulse;
    
    // Glow effect
    float glow = 1.0 - smoothstep(size * 0.5, size * 3.0, d);
    
    return node + glow * circuit_glow * 0.3;
}

// ============================================================
// CIRCUIT LAYERS (complexity)
// ============================================================

vec3 renderCircuitLayer(vec2 uv, vec2 gridPos, float gridSize, float time, int layer) {
    vec3 color = vec3(0.0);
    float alpha = 0.0;
    
    // Each layer has different characteristics
    float layerScale = 1.0 + float(layer) * 0.3;
    float layerOffset = float(layer) * 1.7;
    
    vec2 layerGridPos = vec2(
        floor(uv.x * gridSize / layerScale + layerOffset),
        floor(uv.y * gridSize / layerScale + layerOffset)
    );
    
    float layerDensity = circuit_density * (0.5 + float(layer) * 0.15);
    float layerTime = time * circuit_speed * (0.8 + float(layer) * 0.2);
    
    // Grid lines
    float gridAlpha = 0.15 / layerScale;
    float gx = step(abs(fract(uv.x * gridSize / layerScale + layerOffset) - 0.5) - 0.49, 0.0);
    float gy = step(abs(fract(uv.y * gridSize / layerScale + layerOffset) - 0.5) - 0.49, 0.0);
    color += vec3(gridAlpha);
    
    // Traces in this layer
    if (hash1(layerGridPos + vec2(layerOffset)) < layerDensity * 0.3) {
        // Horizontal trace
        float xMin = (layerGridPos.x - layerOffset) / (gridSize / layerScale);
        float xMax = xMin + (gridSize / layerScale) * (0.5 + hash2(layerGridPos) * 0.5);
        float y = (layerGridPos.y - layerOffset) / (gridSize / layerScale);
        float hLine = drawHLine(uv, y, xMin, xMax, layerTime + layerOffset, circuit_data_flow);
        color += circuit_colors * hLine * 0.8;
        alpha = max(alpha, hLine * 0.8);
    }
    
    if (hash2(layerGridPos + vec2(layerOffset * 2.0)) < layerDensity * 0.3) {
        // Vertical trace
        float yMin = (layerGridPos.y - layerOffset) / (gridSize / layerScale);
        float yMax = yMin + (gridSize / layerScale) * (0.5 + hash1(layerGridPos) * 0.5);
        float x = (layerGridPos.x - layerOffset) / (gridSize / layerScale);
        float vLine = drawVLine(uv, x, yMin, yMax, layerTime + layerOffset, circuit_data_flow);
        color += circuit_colors * vLine * 0.8;
        alpha = max(alpha, vLine * 0.8);
    }
    
    // L-junctions
    if (hash1(layerGridPos + vec2(layerOffset * 3.0)) < layerDensity * 0.2) {
        float cornerX = (layerGridPos.x - layerOffset) / (gridSize / layerScale);
        float cornerY = (layerGridPos.y - layerOffset) / (gridSize / layerScale);
        float segLen = (gridSize / layerScale) * 0.3;
        
        float corner = max(
            drawHLine(uv, cornerY, cornerX, cornerX + segLen, layerTime, circuit_data_flow),
            drawVLine(uv, cornerX, cornerY, cornerY + segLen, layerTime, circuit_data_flow)
        );
        color += circuit_colors * corner * 0.7;
        alpha = max(alpha, corner * 0.7);
    }
    
    // Nodes at intersections
    if (hash2(layerGridPos + vec2(layerOffset * 4.0)) < circuit_nodes * 0.5) {
        vec2 nodePos = vec2(
            (layerGridPos.x - layerOffset + 0.5) / (gridSize / layerScale),
            (layerGridPos.y - layerOffset + 0.5) / (gridSize / layerScale)
        );
        float node = drawNode(uv, nodePos, 0.008 / layerScale, layerTime);
        color += circuit_colors * node * 1.2;
        alpha = max(alpha, node * 1.2);
    }
    
    color.x *= alpha;
    color.y *= alpha;
    color.z *= alpha;
    return color;
}

// ============================================================
// CHIP / IC COMPONENT
// ============================================================

vec3 renderChip(vec2 uv, vec2 center, float size, float time) {
    vec3 color = vec3(0.0);
    
    // Chip body
    float chipBody = 1.0 - smoothstep(size * 0.4, size * 0.38, length(uv - center));
    chipBody *= step(abs(uv.x - center.x), size * 0.4) * step(abs(uv.y - center.y), size * 0.4);
    
    // Chip pins (left)
    for (int i = 0; i < 4; i++) {
        float pinY = center.y + size * 0.2 * (float(i) - 1.5);
        float pin = step(abs(uv.x - (center.x - size * 0.5)), size * 0.12) * 
                    step(abs(uv.y - pinY), size * 0.06);
        color += circuit_colors * pin * 0.6;
    }
    
    // Chip pins (right)
    for (int i = 0; i < 4; i++) {
        float pinY = center.y + size * 0.2 * (float(i) - 1.5);
        float pin = step(abs(uv.x - (center.x + size * 0.5)), size * 0.12) * 
                    step(abs(uv.y - pinY), size * 0.06);
        color += circuit_colors * pin * 0.6;
    }
    
    // Chip label dot
    float dot = 1.0 - smoothstep(size * 0.08, size * 0.04, length(uv - (center + vec2(-size * 0.25, size * 0.25))));
    color += circuit_colors * dot * 1.5;
    
    // Chip glow
    float chipGlow = chipBody * (sin(time * circuit_speed * 2.0 + hash1(center * 50.0) * 6.28) * 0.3 + 0.7);
    color += circuit_colors * chipGlow * circuit_glow * 0.4;
    
    return color;
}

// ============================================================
// MAIN SHADER
// ============================================================

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float time = iTime * circuit_speed;
    
    vec3 color = vec3(0.0);
    
    // Dark circuit board background with subtle green tint
    vec3 bgColor = vec3(0.02, 0.05, 0.02);
    
    // Grid-based circuit patterns
    vec2 gridUv = uv * circuit_grid_size;
    vec2 gridPos = floor(gridUv);
    
    // Base circuit layer
    vec3 baseLayer = renderCircuitLayer(uv, gridPos, circuit_grid_size, time, 0);
    color += bgColor + baseLayer * 0.5;
    
    // Additional layers for complexity
    for (int layer = 1; layer < 5; layer++) {
        if (float(layer) < float(circuit_complexity)) {
            vec3 layerColor = renderCircuitLayer(uv, gridPos, circuit_grid_size, time, layer);
            color += layerColor * (1.0 - float(layer) * 0.2);
        }
    }
    
    // Add chips/components at strategic locations
    float chipChance = circuit_density * 0.15;
    float chipHash = hash1(gridPos * 7.7 + vec2(1.3, 4.2));
    if (chipHash < chipChance) {
        float chipSize = 0.02 + hash2(gridPos) * 0.03;
        vec2 chipPos = (gridPos + 0.5) / circuit_grid_size;
        chipPos = chipPos * 2.0 - 1.0;
        chipPos.y *= iResolution.y / iResolution.x;
        color += renderChip(uv, chipPos, chipSize, time);
    }
    
    // Larger IC components
    float bigChipHash = hash2(gridPos * 3.3 + vec2(5.7, 2.1));
    if (bigChipHash < chipChance * 0.3) {
        float bigChipSize = 0.04 + hash1(gridPos) * 0.04;
        vec2 bigChipPos = (gridPos + 0.5) / circuit_grid_size;
        bigChipPos = bigChipPos * 2.0 - 1.0;
        bigChipPos.y *= iResolution.y / iResolution.x;
        color += renderChip(uv, bigChipPos, bigChipSize, time * 0.8);
    }
    
    // Subtle scanline effect
    float scanline = sin(fragCoord.y * 3.14) * 0.02 + 0.98;
    color *= scanline;
    
    // Vignette
    float vignette = 1.0 - length(uv * 0.8);
    vignette = smoothstep(0.0, 1.0, vignette);
    color *= vignette;
    
    // Color grading - push toward green
    color = pow(color, vec3(0.9, 1.0, 1.1));
    
    // Gamma correction
    color = pow(max(color, vec3(0.0)), vec3(1.0 / 2.2));
    
    fragColor = vec4(color, 1.0);
}
