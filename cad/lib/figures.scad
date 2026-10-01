// figures.scad — non-structural reference objects (people, etc.) for scale.
// Units: INCHES.  IMPORTANT: these use raw primitives (cylinder/sphere), NOT
// board()/sheet(), so they are NEVER counted in the cut list. Use them only to
// give a sense of scale in renders. Gate with SHOW_HUMAN and hide in PLAN_VIEW.

// A simple standing person, feet at the origin, centered on X/Y, facing +Y.
// height in inches (default 5'10").
module human(height = 70, clr = "#5b6b7b") {
    h = height;
    leg = h * 0.47;          // hip height
    color(clr) {
        // legs
        for (s = [-1, 1])
            translate([s * h * 0.055, 0, 0]) cylinder(h = leg, d = h * 0.095, $fn = 16);
        // torso (slightly flattened front-to-back), tapering to shoulders
        translate([0, 0, leg]) scale([1, 0.62, 1])
            cylinder(h = h * 0.32, d1 = h * 0.18, d2 = h * 0.16, $fn = 24);
        // arms hanging straight at the sides
        for (s = [-1, 1])
            translate([s * h * 0.10, 0, leg + h * 0.30])
                translate([0, 0, -h * 0.32]) cylinder(h = h * 0.32, d = h * 0.05, $fn = 12);
        // neck
        translate([0, 0, leg + h * 0.30]) cylinder(h = h * 0.05, d = h * 0.055, $fn = 12);
        // head
        translate([0, 0, h * 0.90]) sphere(d = h * 0.12, $fn = 28);
    }
}
