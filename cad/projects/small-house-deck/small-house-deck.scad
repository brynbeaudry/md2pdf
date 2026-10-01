// small-house-deck.scad — a 12' x 10' attached deck for a small house.
// Ledger on the house wall, doubled 2x10 beam on three posts, 2x8 joists at
// ~16" o.c. cantilevered 12" past the beam, 2x6 decking, a 36" guard on the
// three open sides, and a 36"-wide stair down the front.
//   Build:  bin/cad-build projects/small-house-deck --open

use <../../lib/lumber.scad>
use <../../lib/figures.scad>

/* ───── parameters ──────────────────────────────────────────────────────────
   Units are INCHES.  Axes:  X=width along the house, Y=depth out from the
   house (FRONT / stair side at y=0, house wall at y=D), Z=up from grade.    */
W       = 144;      // deck width along the house wall (12')
D       = 120;      // deck depth out from the house (10')
H_DECK  = 36;       // grade to top of decking
PT      = 1.5;      // 2x thickness
JOIST   = 7.25;     // 2x8 depth
BEAM    = 9.25;     // 2x10 depth
OC      = 16;       // max joist spacing
CANT    = 12;       // joist cantilever past the beam (front side)

GUARD_H = 36;       // guard height above the decking
BAL_GAP = 3.75;     // max clear gap between balusters (< 4" code sphere)

STAIR_W = 36;       // stair width, outside of stringers
RISERS  = 5;
RISE    = H_DECK / RISERS;   // 7.2"
RUN     = 10.5;              // tread seat depth (2 x 2x6 with nosing)

J_TOP   = H_DECK - PT;       // top of joists
J_BOT   = J_TOP - JOIST;     // bottom of joists
B_BOT   = J_BOT - BEAM;      // bottom of beam
PIER_H  = 6;                 // pier top above grade
BEAM_Y  = CANT;              // front face of the beam
STAIR_X = (W - STAIR_W) / 2; // left edge of the stair
POST    = 3.5;               // 4x4

/* ───── render switches — cad-render overrides these with -D per image ──────
   `use <lumber.scad>` imports modules but NOT variables, so a model that tests
   these must declare them itself, or they are undefined and every test on them
   is false (OpenSCAD only warns).                                            */
PLAN_VIEW  = false;   // true for the plan (top) render: hide roof/decking
SHOW_STAGE = 0;       // n for build-step n's render; 0 = overview
XPLODE     = 0;       // > 0 for the exploded-parts render

/* ───── plan metadata ─────────────────────────────────────────────────────── */
plan_meta(
    title    = "Small House Deck — 12' x 10'",
    subtitle = "Ledger-attached deck with guard and front stair",
    units    = "inches",
    material = "Pressure-treated (ground-contact posts) SPF, 2x6 decking");

plan_dim("Footprint",          str(W / 12, "' wide x ", D / 12, "' deep"));
plan_dim("Deck height",        str(H_DECK, "\" to top of decking"));
plan_dim("Joists",             str("2x8 at ", round((W - PT) / ceil((W - PT) / OC) * 10) / 10, "\" o.c., ", CANT, "\" cantilever"));
plan_dim("Beam",               "doubled 2x10 on three 4x4 posts");
plan_dim("Guard",              str(GUARD_H, "\" above decking, 2x2 balusters"));
plan_dim("Stair",              str(STAIR_W, "\" wide, ", RISERS, " risers of ", RISE, "\", ", RUN, "\" run"));

plan_note("Check local code and get a permit first: guard height, footing depth, ledger fastening and stair rules vary by region (BC requires a guard above 600 mm / ~24\").");
plan_note("Ledger: remove siding, flash over the ledger, and through-bolt or structural-screw it to the house rim joist in a staggered pattern. Never fasten to siding or brick veneer.");
plan_note("Hardware (not in the cut list): joist hangers at the ledger, hurricane ties at the beam, post bases, 1/2\" carriage bolts for guard posts, stair stringer hangers, deck screws.");
plan_note("Piers are drawn for reference only: pour to below frost depth (or use engineered deck footings) — they are not in the cut list.");
plan_note("A stair with more than 3 risers needs a graspable handrail; add one per code (not modelled).");
plan_note("Gap decking about 1/4\" (a 16d nail) and start the first board against the house with a 1/2\" gap for drainage.");

plan_step("Lay out the deck footprint with batter boards and string, square it with 3-4-5 diagonals.");
plan_step("Remove siding where the ledger goes, install flashing, and fasten the 2x8 ledger to the house rim joist.");
plan_step("Dig and pour three piers under the beam line; set post bases level and plumb the 4x4 posts.");
plan_step("Assemble the doubled 2x10 beam (glue + nail the plies), set it on the posts and fasten with post caps.");
plan_step("Hang the two end joists and the front rim joist, then fill in the field joists with hangers at the ledger and ties at the beam.");
plan_step("Bolt the 4x4 guard posts to the outside of the rim and end joists.");
plan_step("Lay the 2x6 decking perpendicular to the joists, starting at the house; notch around guard posts.");
plan_step("Hang the notched stringers from the front rim, set the bottom on a level pad, then fasten the treads.");
plan_step("Install the guard rails, balusters and the 2x6 cap; check every gap is under 4\".");

// Pressure-treated retail, rough BC prices (CAD $ per linear foot).
plan_price("currency",  "CAD $");
plan_price("waste_pct", 10);
plan_price("2x2",  0.75);  plan_price("2x4",  1.25);  plan_price("2x6", 1.85);
plan_price("2x8",  2.45);  plan_price("2x10", 3.20);  plan_price("2x12", 4.10);
plan_price("4x4",  2.70);

plan_bounds([-4.5, -(RISERS - 1) * RUN - 2, 0], [W + 4.5, D, H_DECK + GUARD_H + PT], 1.9);

/* ───── context (not built, not in the cut list) ───────────────────────────── */
HOUSE_C = [0.86, 0.87, 0.88];
PIER_C  = [0.62, 0.62, 0.60];
module house_wall() {        // the existing house, behind the deck
    color(HOUSE_C) difference() {
        translate([-30, D, 0]) cube([W + 60, 10, H_DECK + 96]);
        translate([W / 2 - 36, D - 1, H_DECK]) cube([72, 12, 80]);   // patio door
    }
    color([0.45, 0.55, 0.62]) translate([W / 2 - 34, D + 4, H_DECK]) cube([68, 1, 78]);
}
module pier() { color(PIER_C) cylinder(h = PIER_H, d = 10, $fn = 32); }

/* ───── sub-assemblies ───────────────────────────────────────────────────── */
// 3 posts under the beam: near each end and in the middle
POST_X = [6, W / 2 - POST / 2, W - 6 - POST];
POST_YC = BEAM_Y + PT;                 // centre of the 3"-wide doubled beam

module ledger() {
    translate([0, D - PT, J_BOT]) beam("2x8", W, "ledger");
}
module piers() {
    for (x = POST_X) translate([x + POST / 2, POST_YC, 0]) pier();
}
module support_posts() {
    for (x = POST_X)
        translate([x, POST_YC - POST / 2, PIER_H]) stud("4x4", B_BOT - PIER_H, "support post");
}
module beam_ply(i) {    // i = 0 front ply, 1 back ply
    translate([0, BEAM_Y + i * PT, B_BOT]) beam("2x10", W, "beam ply");
}
// a 2x8 running along Y (out from the house), left face at x
module joist_y(x, y0, len, tag) {
    translate([x + PT, y0, J_BOT]) rotate([0, 0, 90]) beam("2x8", len, tag);
}
module end_joist(left) { joist_y(left ? 0 : W - PT, PT, D - 2 * PT, "end joist"); }
module field_joists() {
    nb = ceil((W - PT) / OC);
    for (i = [1 : nb - 1]) joist_y(i * (W - PT) / nb, PT, D - 2 * PT, "joist");
}
module front_rim() {
    translate([0, 0, J_BOT]) beam("2x8", W, "rim joist");
}
module decking() {
    n = round(D / 5.75);
    gap = (D - n * 5.5) / (n - 1);
    for (i = [0 : n - 1]) translate([0, i * (5.5 + gap), J_TOP]) plate("2x6", W, "deck board");
}

/* ── guard: posts outside the rim, rails + balusters between them, cap on top */
G_BOT = J_BOT;                         // posts bolt to the rim/end joists
G_TOP = H_DECK + GUARD_H - PT;         // cap sits on the post tops
RAIL_LO = H_DECK + 3;                  // bottom rail: 3" over the decking
RAIL_HI = G_TOP - 3.5;                 // top rail: tight under the cap
BAL_LEN = RAIL_HI - (RAIL_LO + 3.5);

module guard_post(x, y) { translate([x, y, G_BOT]) stud("4x4", G_TOP - G_BOT, "guard post"); }

// a guard bay running along X between posts, in the post plane centred at yc
module bay_x(x0, x1, yc) {
    s = x1 - x0;
    n = ceil((s - BAL_GAP) / (1.5 + BAL_GAP));
    g = (s - n * 1.5) / (n + 1);
    for (z = [RAIL_LO, RAIL_HI]) translate([x0, yc - 0.75, z]) beam("2x4", s, "guard rail");
    for (i = [0 : n - 1])
        translate([x0 + g + i * (1.5 + g), yc - 0.75, RAIL_LO + 3.5]) stud("2x2", BAL_LEN, "baluster");
}
// the same bay running along Y, in the post plane centred at xc
module bay_y(y0, y1, xc) {
    s = y1 - y0;
    n = ceil((s - BAL_GAP) / (1.5 + BAL_GAP));
    g = (s - n * 1.5) / (n + 1);
    for (z = [RAIL_LO, RAIL_HI]) translate([xc + 0.75, y0, z]) rotate([0, 0, 90]) beam("2x4", s, "guard rail");
    for (i = [0 : n - 1])
        translate([xc - 0.75, y0 + g + i * (1.5 + g), RAIL_LO + 3.5]) stud("2x2", BAL_LEN, "baluster");
}

SIDE_MID = D / 2 - POST / 2;
module guard_posts_front() {
    for (x = [-POST, STAIR_X - POST, STAIR_X + STAIR_W, W]) guard_post(x, -POST);
}
module guard_posts_side(left) {        // the corner post belongs to the front
    for (y = [SIDE_MID, D - POST]) guard_post(left ? -POST : W, y);
}
module bays_front() {
    bay_x(0, STAIR_X - POST, -POST / 2);
    bay_x(STAIR_X + STAIR_W + POST, W, -POST / 2);
}
module bays_side(left) {
    xc = left ? -POST / 2 : W + POST / 2;
    bay_y(0, SIDE_MID, xc);
    bay_y(SIDE_MID + POST, D - POST, xc);
}
module guard_cap() {
    cw = 5.5;                          // 2x6 flat, centred on the post line
    o  = (cw - POST) / 2;
    translate([-POST - o, -POST - o, G_TOP]) plate("2x6", STAIR_X + POST + 2 * o, "cap rail");
    translate([STAIR_X + STAIR_W - o, -POST - o, G_TOP]) plate("2x6", W - STAIR_X - STAIR_W + POST + 2 * o, "cap rail");
    for (x = [-POST - o, W - o])
        translate([x + cw, cw - POST - o, G_TOP]) rotate([0, 0, 90]) plate("2x6", D - cw + POST + o, "cap rail");
}

/* ── stair: notched 2x12 stringers hung from the front rim, 2x6 treads ────── */
STAIR_Y0 = -(RISERS - 1) * RUN;        // front of the bottom tread seat
module stringers() {
    for (x = [STAIR_X, STAIR_X + (STAIR_W - PT) / 2, STAIR_X + STAIR_W - PT])
        translate([x + PT, STAIR_Y0, 0]) rotate([0, 0, 90]) stringer("2x12", RISERS, RISE, RUN);
}
module treads() {
    for (i = [1 : RISERS - 1]) for (k = [0, 1])
        translate([STAIR_X, STAIR_Y0 + (i - 1) * RUN - 1 + k * 5.75, i * RISE - PT])
            plate("2x6", STAIR_W, "stair tread");
}

/* ───── staged assembly ──────────────────────────────────────────────────── */
if (XPLODE <= 0 && !PLAN_VIEW) house_wall();

stage(1, "Ledger, piers and posts") {
    xpart([0, 1, 0]) ledger();
    piers();
    xpart([0, 0, 0.8]) support_posts();
}
stage(2, "Doubled beam") {
    xpart([0, -0.5, 0.6]) beam_ply(0);
    xpart([0,  0.5, 0.6]) beam_ply(1);
}
stage(3, "Rim and joists") {
    xpart([-1, 0, 0]) end_joist(true);
    xpart([ 1, 0, 0]) end_joist(false);
    xpart([0, 0, 0.8]) field_joists();
    xpart([0, -1, 0]) front_rim();
}
stage(4, "Guard posts") {
    xpart([0, -1, 0]) guard_posts_front();
    xpart([-1, 0, 0]) guard_posts_side(true);
    xpart([ 1, 0, 0]) guard_posts_side(false);
}
if (!PLAN_VIEW) stage(5, "Decking") {
    xpart([0, 0, 1]) decking();
}
stage(6, "Stair") {
    xpart([0, -1, 0]) stringers();
    xpart([0, -1, 1.2]) treads();
}
if (!PLAN_VIEW) stage(7, "Guard rails, balusters and cap") {
    xpart([0, -1, 0]) bays_front();
    xpart([-1, 0, 0]) bays_side(true);
    xpart([ 1, 0, 0]) bays_side(false);
    xpart([0, 0, 1.5]) guard_cap();
}

/* ───── scale figure (overview only) ─────────────────────────────────────── */
SHOW_HUMAN = true;
if (SHOW_HUMAN && SHOW_STAGE <= 0 && !PLAN_VIEW)
    translate([-40, -30, 0]) human(70);
