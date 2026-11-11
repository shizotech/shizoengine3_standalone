// ---- Voxels: what the passes share ----
// The picture as a city of blocks: the picture is cut into Columns x (as many rows as keep them square) cells, and
// each cell becomes a box as high as the brightness (or a channel) of the cell, in the colour of the cell. Pass H keeps
// the picture at a quarter of the size (colour and height). __init__ traces a ray through the grid for every pixel
// (an analytic grid walk: one cell after the other along the ray, a box test in each, no raymarching steps), lights
// the box it hits (sun, sky, bevelled edges, a little ambient occlusion) and, at Quality 2, walks the grid again
// towards the sun for the shadow. On the beat a ripple runs out from the middle. S keeps the music.
#include music.glsl

//@int min=4 max=480 value=96
uniform int columns;                // blocks across the picture (the rows follow, so the blocks are square)
//@slider min=0.0 max=2.0 value=0.45
uniform float height;               // how high a block of full brightness stands (the picture is 2 deep)
//@enum options=(Brightness, Darkness, Red, Green, Blue, Saturation) value=0
uniform int height_by;              // what of the picture sets the height
//@slider min=0.3 max=3.0 value=1.4
uniform float height_curve;         // above 1 only the bright parts stand up, below 1 everything rises
//@slider min=0.0 max=0.3 value=0.015
uniform float base_height;          // every block at least this high
//@enum options=(Extrude, Cubes) value=0
uniform int block_mode;             // Extrude: columns from the ground; Cubes: one floating cube a cell, at its height
//@slider min=0.0 max=0.45 value=0.0
uniform float gap;                  // space between the blocks, in parts of a cell
//@slider min=0.0 max=0.5 value=0.18
uniform float bevel;                // rounded edges, in parts of a cell (shading)
//@slider min=0.0 max=2.0 value=0.0
uniform float edge_glow;            // light lines along the edges of the blocks
//@slider min=0.0 max=1.0 value=0.25
uniform float side_shade;           // darkens the sides against the top, which keeps the picture readable

//@slider min=0.0 max=1.0 value=0.35
uniform float ripple;               // a wave runs out from the middle on the beat (every Beat every-th)
//@slider min=0.2 max=6.0 value=2.2
uniform float ripple_speed;         // how fast the ripple runs (picture heights a second)
//@slider min=0.0 max=1.0 value=0.0
uniform float wave;                 // a wave that always rolls across the blocks
//@slider min=0.0 max=2.0 value=0.5
uniform float bass_height;          // the bass (or the kick of the beat) lifts the blocks

//@slider min=0.0 max=360.0 value=215.0
uniform float sun_angle;            // degrees around
//@slider min=5.0 max=89.0 value=38.0
uniform float sun_height;           // degrees over the ground: low = long shadows
//@slider min=0.0 max=3.0 value=1.2
uniform float sun_strength;
//@slider min=0.0 max=1.0 value=0.35
uniform float ambient;
//@slider min=0.0 max=1.0 value=0.3
uniform float specular;
//@slider min=0.0 max=3.0 value=1.25
uniform float saturation_boost;     // more colour from the picture (1 = as it is)
//@slider min=0.0 max=2.0 value=0.35
uniform float emission;             // the blocks glow in their own colour (also in the shadow)

//@slider min=0.0 max=89.0 value=48.0
uniform float camera_tilt;          // degrees above the ground
//@slider min=-180.0 max=180.0 value=-20.0
uniform float camera_turn;          // degrees around
//@slider min=0.0 max=60.0 value=14.0
uniform float camera_sway;          // degrees the camera rocks to and fro over 16 beats
//@slider min=-2.0 max=2.0 value=0.0
uniform float camera_orbit;         // turns around per 16 beats
//@slider min=1.5 max=12.0 value=3.4
uniform float camera_distance;      // small: strong perspective; the size stays the same
//@slider min=0.2 max=4.0 value=0.8
uniform float zoom;

//@enum options=(Colour, Transparent, Picture) value=0
uniform int background_mode;        // Transparent: alpha 0 around the blocks; Picture: the input behind
//@rgb value=(0.02, 0.02, 0.03)
uniform vec3 background_color;
//@rgb value=(0.04, 0.04, 0.05)
uniform vec3 floor_color;           // the ground between the blocks
//@int min=1 max=3 value=2
uniform int quality;                // 1 no shadows (live and cheap), 2 shadows, 3 shadows and 4x antialiasing
//@slider min=0.2 max=4.0 value=1.2
uniform float exposure;

float lumaOf(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// The value of a colour that sets the height (Height by)
float heightValue(vec3 c) {
    if (height_by == 1) return 1.0 - lumaOf(c);
    if (height_by == 2) return c.r;
    if (height_by == 3) return c.g;
    if (height_by == 4) return c.b;
    if (height_by == 5) {
        float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
        return mx > 1e-4 ? (mx - mn) / mx : 0.0;
    }
    return lumaOf(c);
}
