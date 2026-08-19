// GridMatrixChase - 2D grid matrix with multiple chase patterns
// Supports Horizontal, Vertical, Diagonal, Corner Sweep, and Spiral modes
//
// ==== Custom Uniform Controls ====

//@int min=1 max=32 value=8
uniform int grid_x;

//@int min=1 max=32 value=8
uniform int grid_y;

//@slider min=0.1 max=5.0 value=1.0
uniform float speed;

//@rgb
uniform vec3 matrix_color;

//@rgb
uniform vec3 bg_color;

//@enum options=(Horizontal, Vertical, Diagonal, Corner Sweep, Spiral)
uniform int chase_direction;

// Standard hash function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Check if a fragment is inside a grid cell with padding
float isInsideCell(vec2 fragCoord, float cellW, float cellH, vec2 cellOrigin, float gap) {
    vec2 localPos = fragCoord - cellOrigin;
    float inX = float(localPos.x >= gap && localPos.x <= cellW - gap);
    float inY = float(localPos.y >= gap && localPos.y <= cellH - gap);
    return inX * inY;
}

// Calculate distance for smooth cell activation with a given progression value (0..N)
float cellActivation(float cellIndex, float progress, float cellDuration) {
    float cellProgress = clamp(progress - cellIndex, 0.0, cellDuration);
    // Smoothstep fade-in for each cell
    return smoothstep(0.0, cellDuration, cellProgress);
}

// Horizontal mode: each row sweeps left-to-right sequentially
// Top row starts first, then second row, etc.
float horizontal_mode(float progress, int cellRow, int cellCol) {
    // Row offset: row 0 starts at 0, row 1 at grid_x, etc.
    float rowOffset = float(cellRow) * float(grid_x);
    float cellOrder = rowOffset + float(cellCol);
    float cellDuration = 1.0;
    return cellActivation(cellOrder, progress, cellDuration);
}

// Vertical mode: each column sweeps top-to-bottom sequentially
// First column starts first, then second column, etc.
float vertical_mode(float progress, int cellRow, int cellCol) {
    float colOffset = float(cellCol) * float(grid_y);
    float cellOrder = colOffset + float(cellRow);
    float cellDuration = 1.0;
    return cellActivation(cellOrder, progress, cellDuration);
}

// Diagonal mode: cells light up along diagonals (anti-diagonal sweep)
// The diagonal index = cellRow + cellCol, ranges from 0 to grid_x + grid_y - 2
float diagonal_mode(float progress, int cellRow, int cellCol) {
    float diagIndex = float(cellRow + cellCol);
    float cellDuration = 1.0;
    return cellActivation(diagIndex, progress, cellDuration);
}

// Corner Sweep mode: corners light up in order
// Pattern: top-left corner, then top-right, then bottom-right, then bottom-left
// Each corner lights up its cells row by row or col by col
float corner_mode(float progress, int cellRow, int cellCol) {
    float totalCells = float(grid_x * grid_y);
    float cellsPerCorner = totalCells / 4.0;

    // Determine which corner the cell belongs to and its order within that corner
    float cornerIndex;
    float localIndex;

    if (cellRow < grid_y / 2 && cellCol < grid_x / 2) {
        // Top-left corner
        cornerIndex = 0.0;
        localIndex = float(cellRow * grid_x + cellCol);
    } else if (cellRow < grid_y / 2 && cellCol >= grid_x / 2) {
        // Top-right corner
        cornerIndex = 1.0;
        localIndex = float(cellRow * grid_x + (cellCol - grid_x / 2));
    } else if (cellRow >= grid_y / 2 && cellCol >= grid_x / 2) {
        // Bottom-right corner
        cornerIndex = 2.0;
        localIndex = float((cellRow - grid_y / 2) * grid_x + (cellCol - grid_x / 2));
    } else {
        // Bottom-left corner
        cornerIndex = 3.0;
        localIndex = float((cellRow - grid_y / 2) * grid_x + cellCol);
    }

    float cellOrder = cornerIndex * cellsPerCorner + localIndex;
    float cellDuration = 1.0;
    return cellActivation(cellOrder, progress, cellDuration);
}

// Spiral mode: cells light up in an outward spiral from center
// We simulate a spiral path through the grid cells
float spiral_mode(float progress, int cellRow, int cellCol) {
    // Calculate spiral index for a given cell position
    // We use concentric layers from the center outward
    int cx = grid_x / 2;
    int cy = grid_y / 2;

    // Calculate the "ring" or layer of the cell
    int dx = abs(cellCol - cx);
    int dy = abs(cellRow - cy);
    int ring = max(dx, dy);

    // Calculate the perimeter of this ring
    int ringSize;
    if (ring == 0) {
        ringSize = 1;
    } else {
        ringSize = 8 * ring;
    }

    // Calculate the starting offset (total cells in all inner rings)
    float startOffset = 0.0;
    for (int r = 1; r <= ring; r++) {
        startOffset += 8.0 * float(r);
    }

    // Calculate position within the ring
    // Walk: right along top, down along right, left along bottom, up along left
    int sideLength = 2 * ring + 1;
    float perimeter = float(4 * (sideLength - 1));
    float posInRing;

    if (cellRow <= cy && cellCol <= cx + ring && cellCol >= cx - ring && cellRow == cy - ring) {
        // Top side: left to right
        posInRing = float(cellCol - (cx - ring));
    } else if (cellCol >= cx + ring && cellRow >= cy - ring && cellRow <= cy + ring && cellCol == cx + ring) {
        // Right side: top to bottom
        posInRing = float(sideLength - 1.0) + float(cellRow - (cy - ring));
    } else if (cellRow >= cy + ring && cellCol >= cx - ring && cellCol <= cx + ring && cellRow == cy + ring) {
        // Bottom side: right to left
        posInRing = 2.0 * float(sideLength - 1) + float((cx + ring) - cellCol);
    } else {
        // Left side: bottom to top
        posInRing = 3.0 * float(sideLength - 1) + float((cy + ring) - cellRow);
    }

    float cellOrder = startOffset + posInRing;
    float cellDuration = 1.0;
    return cellActivation(cellOrder, progress, cellDuration);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Grid cell dimensions
    float cellW = iResolution.x / float(grid_x);
    float cellH = iResolution.y / float(grid_y);

    // Gap between cells (padding)
    float gap = max(cellW, cellH) * 0.08;

    // Determine which grid cell this fragment belongs to
    int cellCol = int(floor(fragCoord.x / cellW));
    int cellRow = int(floor(fragCoord.y / cellH));

    // Clamp to grid bounds
    cellCol = clamp(cellCol, 0, grid_x - 1);
    cellRow = clamp(cellRow, 0, grid_y - 1);

    // Cell origin (top-left corner of the cell)
    vec2 cellOrigin = vec2(float(cellCol) * cellW, float(cellRow) * cellH);

    // Check if fragment is inside the cell (with gap)
    float cellMask = isInsideCell(fragCoord, cellW, cellH, cellOrigin, gap);

    if (cellMask < 0.5) {
        // Outside any cell — output background color
        fragColor = vec4(bg_color, 1.0);
        return;
    }

    // Animation progress: total cells to light up sequentially
    float totalCells = float(grid_x * grid_y);
    float animTime = iTime * speed;
    // Each cell takes (totalCells / speed) time to fully cycle, progress goes 0..N
    float progress = animTime;

    // Calculate activation based on chase direction
    float brightness;

    if (chase_direction == 0) {
        // Horizontal
        brightness = horizontal_mode(progress, cellRow, cellCol);
    } else if (chase_direction == 1) {
        // Vertical
        brightness = vertical_mode(progress, cellRow, cellCol);
    } else if (chase_direction == 2) {
        // Diagonal
        brightness = diagonal_mode(progress, cellRow, cellCol);
    } else if (chase_direction == 3) {
        // Corner Sweep
        brightness = corner_mode(progress, cellRow, cellCol);
    } else {
        // Spiral
        brightness = spiral_mode(progress, cellRow, cellCol);
    }

    // Apply brightness to matrix color against background
    vec3 final_color = mix(bg_color, matrix_color, brightness);

    // Add subtle glow effect for fully lit cells
    final_color += matrix_color * brightness * 0.15;

    fragColor = vec4(final_color, 1.0);
}
