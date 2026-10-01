// outhouse-deluxe.scad — the main outhouse for the property.
// Roomy, tall, mono-slope (shed) roof falling toward the back, a side window,
// an interior boxed bench seat, and a front porch with real deck boards.
// Units: INCHES. Built from lib/lumber.scad so the cut list always matches the
// geometry. A scale figure (lib/figures.scad) is shown for reference only.
//   cad-build projects/outhouse-deluxe

use <../../lib/lumber.scad>
use <../../lib/figures.scad>

/* ───── parameters ───── */
WIDTH    = 60;   // X: side-to-side (outside of framing)
DEPTH    = 60;   // Y: front-to-back
H_FRONT  = 92;   // wall height at the front (door side)
H_BACK   = 78;   // wall height at the back  (roof slopes down to here)
OVERHANG = 10;   // roof overhang past the walls
STUD_OC  = 16;   // stud / rafter spacing, on-center

DOOR_W   = 32;   DOOR_H = 78;             // front door rough opening
WIN_W    = 20;   WIN_H  = 20;  WIN_SILL = 46;   // side window rough opening

PORCH_DEPTH = 40;   // porch projection in front of the door

SEAT_H = 19;     // finished seat height above the floor
SEAT_D = 22;     // seat depth (front-to-back), against the back wall

JOIST = "2x6";          // floor + porch framing
FRAME = "2x4";          // walls + roof framing + seat
DECK_T = 0.75;          // interior floor plywood
ROOF_T = 0.5;           // roof sheathing plywood

SHOW_HUMAN = true;
HUMAN_H    = 70;        // 5'10" reference figure

// derived
WD = lumber_dims(FRAME)[0];   // 3.5  wall thickness
PT = lumber_dims(FRAME)[1];   // 1.5  plate thickness
JH = lumber_dims(JOIST)[0];   // 5.5  floor frame height
DECK_TOP = JH + DECK_T;       // top of interior floor; walls start here

PLAN_VIEW = false;            // set via -D by cad-render for the plan render

/* ───── plan metadata ───── */
plan_meta(
    title    = "Outhouse — Main (Recreational Property)",
    subtitle = str(WIDTH, "\" x ", DEPTH, "\" + ", PORCH_DEPTH, "\" porch · shed roof · bench seat"),
    units    = "inches",
    material = "SPF framing · PT floor/porch frame · plywood deck & roof · 2x6 decking & seat");
plan_dim("Building footprint", str(WIDTH, "\" x ", DEPTH, "\""));
plan_dim("Porch",              str(WIDTH, "\" x ", PORCH_DEPTH, "\""));
plan_dim("Wall height",        str(H_FRONT, "\" front / ", H_BACK, "\" back"));
plan_dim("Roof slope",         str(round(atan((H_FRONT-H_BACK)/DEPTH)*10)/10, "° (", H_FRONT-H_BACK, "\" drop over ", DEPTH, "\")"));
plan_dim("Ridge (front) ht",   str(DECK_TOP + H_FRONT, "\" above grade"));
plan_dim("Door rough op'ng",   str(DOOR_W, "\" x ", DOOR_H, "\""));
plan_dim("Window rough op'ng", str(WIN_W, "\" x ", WIN_H, "\", sill ", WIN_SILL, "\""));
plan_dim("Bench seat",         str(SEAT_H, "\" high x ", SEAT_D, "\" deep, full width"));
plan_note("Floor and porch frames: pressure-treated lumber on level skids/blocks.");
plan_note("Roof slopes down to the back; the tall front gives headroom + a door eave.");
plan_note("Frame walls flat on the deck; the side walls' top plates are cut on the slope.");
plan_note("Set rafters front-to-back on the sloped top plates; sheathe, felt, then metal/asphalt.");
plan_note("Bench: cut the seat opening in the 2x6 top to suit your riser/bucket.");
plan_note("Sheet-goods counts are by area — see PDF note; add ~10% waste.");

// Ordered build sequence (rendered as a numbered Assembly Sequence in the PDF).
plan_step("Set level skids/blocks, then build the PT floor frame (side rims + joists) and check it for square.");
plan_step("Deck the floor with 3/4\" plywood, fastened to every joist.");
plan_step("Frame each wall flat on the deck: bottom plate, studs at 16\" o.c., and the door/window openings (king + jack studs, header, window sill). Cut the two side-wall top plates on the roof slope.");
plan_step("Stand the four walls; plumb and brace them, then nail the corners together.");
plan_step("Set the rafters front-to-back on the sloped top plates at 16\" o.c.; sheathe the roof, then felt + metal/asphalt.");
plan_step("Build the bench seat and fasten it to the back wall; cut the seat opening in the 2x6 top.");
plan_step("Hang the door, then case it with the 1x4 trim (sides first, then head).");
plan_step("Build the porch frame off the front, lay the 2x6 deck boards, and add the step.");
plan_step("Add siding/finishes, screen the window, prime and paint.");

// Cost estimate inputs (rough Vancouver/CAD retail; tune to your supplier).
plan_price("currency", "CAD $");
plan_price("waste_pct", 12);
plan_price("2x4", 0.95);
plan_price("2x6", 1.65);     // pressure-treated runs higher
plan_price("1x4", 0.85);
plan_price("0.5in ply", 52);
plan_price("0.75in ply", 78);

/* ───── floor frame + plywood deck (split so they can explode apart) ───── */
module floor_frame() {
    for (x = [0, WIDTH - PT])                       // side rims along Y
        translate([x + PT, 0, 0]) rotate([0, 0, 90]) beam(JOIST, DEPTH, "floor side rim");
    // cross joists along X: rims at BOTH ends + evenly-spaced field joists (<=16" o.c.)
    nb = ceil((DEPTH - PT) / STUD_OC);
    for (i = [0 : nb])
        translate([PT, i * (DEPTH - PT) / nb, 0]) beam(JOIST, WIDTH - 2*PT, "floor joist");
}
module floor_deck() {
    if (!PLAN_VIEW) translate([0, 0, JH]) sheet(DECK_T, WIDTH, DEPTH, "floor deck");
}

/* ───── stud wall along +X, sloped or flat top, with framed openings ─────
   hf/hb = wall height at x=0 / x=L (equal => flat). openings: list of
   [x0, width, sill, height] (sill measured above the floor; 0 for a door). */
module stud_wall(L, hf, hb, openings = [], tag = "wall") {
    sloped = (hf != hb);
    ang = atan((hf - hb) / L);
    function h_at(x) = hf + (hb - hf) * x / L;
    function in_op(x) = len([for (o = openings) if (x + PT > o[0] - PT && x < o[0] + o[1] + PT) 1]) > 0;

    plate(FRAME, L, str(tag, " bottom plate"));                 // bottom plate
    if (!sloped)                                                // top plate
        translate([0, 0, hf - PT]) plate(FRAME, L, str(tag, " top plate"));
    else
        translate([0, 0, hf - PT]) rotate([0, ang, 0]) plate(FRAME, L / cos(ang), str(tag, " top plate (sloped)"));

    for (i = [0 : ceil(L / STUD_OC)]) {                         // common studs
        x = min(i * STUD_OC, L - PT);
        if (!in_op(x)) translate([x, 0, PT]) stud(FRAME, h_at(x) - 2*PT, str(tag, " stud"));
    }

    for (o = openings) {
        ox = o[0]; ow = o[1]; oz = o[2]; oh = o[3];
        hdr_bot = PT + oz + oh;
        for (kx = [ox - PT, ox + ow])                           // king studs (to wall top)
            translate([kx, 0, PT]) stud(FRAME, h_at(kx) - 2*PT, str(tag, " king stud"));
        for (jx = [ox, ox + ow - PT])                           // jack/trimmer studs
            translate([jx, 0, PT]) stud(FRAME, oz + oh, str(tag, " jack stud"));
        translate([ox - PT, 0, hdr_bot])                        // header
            beam(FRAME, ow + 2*PT, str(tag, " header"));
        if (oz > 0)                                             // window sill plate
            translate([ox, 0, oz]) plate(FRAME, ow, str(tag, " sill plate"));
        for (cx = [ox, ox + ow/2 - PT/2, ox + ow - PT]) {       // cripples (guarded)
            under = oz - PT;
            over  = h_at(cx) - PT - (hdr_bot + PT);
            if (oz > 0 && under > 1)
                translate([cx, 0, PT]) stud(FRAME, under, str(tag, " cripple (under sill)"));
            if (over > 1)
                translate([cx, 0, hdr_bot + PT]) stud(FRAME, over, str(tag, " cripple (over header)"));
        }
    }
}

/* ───── mono-slope roof, split into rafters + sheathing ───── */
ROOF_ANG  = atan((H_FRONT - H_BACK) / DEPTH);
ROOF_RLEN = (DEPTH + 2*OVERHANG) / cos(ROOF_ANG);          // sloped rafter length
module roof_at() {     // place children in the tilted roof plane (front eave at origin)
    translate([0, 0, DECK_TOP + H_FRONT]) rotate([-ROOF_ANG, 0, 0]) translate([0, -OVERHANG, 0]) children();
}
module roof_rafters() {
    roof_at() for (i = [0 : ceil(WIDTH / STUD_OC)]) {
        x = min(i * STUD_OC, WIDTH - PT);
        translate([x + PT, 0, 0]) rotate([0, 0, 90]) beam(FRAME, ROOF_RLEN, "rafter");
    }
}
module roof_sheathing() {
    if (!PLAN_VIEW)
        roof_at() translate([-OVERHANG, 0, lumber_dims(FRAME)[0]])
            sheet(ROOF_T, WIDTH + 2*OVERHANG, ROOF_RLEN, "roof sheathing");
}

/* ───── interior boxed bench seat against the back wall (split parts) ───── */
SEAT_IW = WIDTH - 2*WD;             // interior width
SEAT_X0 = WD;
SEAT_YB = DEPTH - WD;               // back (interior face of back wall)
SEAT_YF = SEAT_YB - SEAT_D;         // front of seat
SEAT_BW = lumber_dims("2x6")[0];    // 5.5
module seat_legs() {
    for (lx = [SEAT_X0, SEAT_X0 + SEAT_IW/2 - PT/2, SEAT_X0 + SEAT_IW - PT])
        for (ly = [SEAT_YF, SEAT_YB - PT])
            translate([lx, ly, DECK_TOP]) stud(FRAME, SEAT_H - 1.5, "seat leg");
}
module seat_rim() {
    translate([SEAT_X0, SEAT_YF, DECK_TOP + SEAT_H - SEAT_BW]) beam("2x6", SEAT_IW, "seat front rim");
}
module seat_planks() {
    n = ceil(SEAT_D / SEAT_BW);
    for (i = [0 : n - 1]) {
        y = SEAT_YF + i * SEAT_BW;
        if (min(SEAT_BW, SEAT_YB - y) > 0.5)
            translate([SEAT_X0, y, DECK_TOP + SEAT_H - 1.5]) plate("2x6", SEAT_IW, "seat top plank");
    }
}

/* ───── door panel (no vent cut-out) ───── */
module door_panel() {
    dx = (WIDTH - DOOR_W) / 2;
    translate([dx, DECK_T, DECK_TOP]) rotate([90, 0, 0])
        sheet(DECK_T, DOOR_W, DOOR_H, "door panel");
}

/* ───── 1x4 casing/trim around the door, proud of the front wall face ───── */
module door_trim() {
    CW = lumber_dims("1x4")[0];     // 3.5 casing width
    yf = -0.75;                     // sits just proud of the wall face (y=0)
    dx = (WIDTH - DOOR_W) / 2;
    for (sx = [dx - CW, dx + DOOR_W])               // side casings (vertical)
        translate([sx + CW, yf, DECK_TOP]) rotate([0, -90, 0]) beam("1x4", DOOR_H, "door trim (side)");
    translate([dx - CW, yf, DECK_TOP + DOOR_H])     // head casing (horizontal)
        beam("1x4", DOOR_W + 2*CW, "door trim (head)");
}

/* ───── assembly parameters ───── */
SIDE_L = DEPTH - 2*WD;
door_x = (WIDTH - DOOR_W) / 2;
win_x  = (SIDE_L - WIN_W) / 2;

// overall extent so every step render shares one fixed camera (grows in place)
plan_bounds([0, -PORCH_DEPTH - 14, 0], [WIDTH, DEPTH, DECK_TOP + H_FRONT + 8], 1.9);

// the four walls — each wrapped in xpart() so they blow apart in the parts view
module walls() {
    xpart([0, -1, 0]) translate([0, 0, DECK_TOP])
        stud_wall(WIDTH, H_FRONT, H_FRONT, [[door_x, DOOR_W, 0, DOOR_H]], "front wall");
    xpart([0, 1, 0]) translate([0, DEPTH - WD, DECK_TOP])
        stud_wall(WIDTH, H_BACK, H_BACK, [], "back wall");
    xpart([-1, 0, 0]) translate([WD, WD, DECK_TOP]) rotate([0, 0, 90])
        stud_wall(SIDE_L, H_FRONT, H_BACK, [], "left wall");
    xpart([1, 0, 0]) translate([WIDTH, WD, DECK_TOP]) rotate([0, 0, 90])
        stud_wall(SIDE_L, H_FRONT, H_BACK, [[win_x, WIN_W, WIN_SILL, WIN_H]], "right wall");
}

/* ───── front porch: frame + 2x6 deck boards + a step (split parts) ───── */
PORCH_BW = lumber_dims("2x6")[0];
PORCH_GAP = 0.3;
STEP_D = 11;                 // step depth (carries 2 x 2x6 treads)
module porch_frame() {
    // perimeter (2x6 on edge): front rim + back ledger run along X (carry the deck)
    for (yr = [-PORCH_DEPTH, -PT])
        translate([PT, yr, 0]) beam(JOIST, WIDTH - 2*PT, "porch rim");
    // two side rims run along Y
    for (x = [0, WIDTH - PT])
        translate([x + PT, -PORCH_DEPTH, 0]) rotate([0, 0, 90]) beam(JOIST, PORCH_DEPTH, "porch side rim");
    // evenly-spaced field joists between the rims (<=16" o.c.) — deck boards land on these
    nb = ceil((PORCH_DEPTH - PT) / STUD_OC);
    for (i = [1 : nb - 1])
        translate([PT, -PORCH_DEPTH + i * (PORCH_DEPTH - PT) / nb, 0]) beam(JOIST, WIDTH - 2*PT, "porch joist");
}
module porch_decking() {
    if (!PLAN_VIEW)
        for (i = [0 : floor(WIDTH / (PORCH_BW + PORCH_GAP)) - 1])
            translate([i * (PORCH_BW + PORCH_GAP), -PORCH_DEPTH, JH]) rotate([0, 0, 90])
                plate("2x6", PORCH_DEPTH, "porch deck board");
}
// One framed step in front: 2x6 sleepers flat on grade run front-to-back; the
// 2x6 treads lie ACROSS them (perpendicular) so each tread is fully supported.
// Tread top sits ~3" up — an intermediate step between grade and the porch deck.
module porch_step() {
    y0 = -PORCH_DEPTH - STEP_D;
    for (sx = [0, WIDTH/2 - PORCH_BW/2, WIDTH - PORCH_BW])     // 3 sleepers, along Y
        translate([sx + PORCH_BW, y0, 0]) rotate([0, 0, 90]) plate("2x6", STEP_D, "step sleeper");
    if (!PLAN_VIEW)
        for (i = [0 : ceil(STEP_D / PORCH_BW) - 1])            // treads, along X, on the sleepers
            translate([0, y0 + i * PORCH_BW, 1.5]) plate("2x6", WIDTH, "step tread");
}

/* ───── staged assembly (drives the step-by-step build instructions) ─────
   Each stage's sub-assemblies are wrapped in xpart(direction) so they blow
   apart in the exploded-parts render; in the in-place view xpart is a no-op. */
stage(1, "Build the floor frame & lay the deck") {
    xpart([0, 0, -1]) floor_frame();
    xpart([0, 0,  1.4]) floor_deck();
}
stage(2, "Frame, stand & brace the four walls") walls();   // each wall xpart'd inside
stage(3, "Build the bench seat against the back") {
    xpart([0, 0, -0.6]) seat_legs();
    xpart([0, -1, 0])   seat_rim();
    xpart([0, 0,  1])   seat_planks();
}
stage(4, "Set the rafters & sheathe the roof") {
    roof_rafters();
    xpart([0, 0, 1.4]) roof_sheathing();
}
stage(5, "Hang the door & case it with trim") {
    if (!PLAN_VIEW) {
        xpart([0, -1, 0])      door_panel();
        xpart([0, -1, 0], 2.2) door_trim();
    }
}
stage(6, "Build the porch & step") {
    xpart([0, 0, -0.6]) porch_frame();
    xpart([0, 0,  1])   porch_decking();
    xpart([0, -1, 0])   porch_step();
}

// scale figure: overview only (kept out of step renders to reduce clutter)
if (!PLAN_VIEW && SHOW_HUMAN && SHOW_STAGE <= 0)
    translate([-14, -PORCH_DEPTH - 6, 0]) human(HUMAN_H);
