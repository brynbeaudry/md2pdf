// outhouse.scad — parametric framed outhouse for a recreational property.
// Units: INCHES.  Built from real dimensional lumber via lib/lumber.scad, so the
// cut list (captured from echoes) always matches this geometry.
//
// Edit the parameters below and re-run `cad-build projects/outhouse --open` to
// regenerate the render + cut list + PDF.

use <../../lib/lumber.scad>

/* ───── parameters ───── */
WIDTH   = 48;   // X: side-to-side (outside of framing)
DEPTH   = 48;   // Y: front-to-back
H_FRONT = 84;   // wall height at front (door side) — measured from floor deck
H_BACK  = 72;   // wall height at back (roof slopes down toward the back)
STUD_OC = 16;   // stud spacing, on-center
OVERHANG = 6;   // roof overhang past the walls

DOOR_W  = 28;   // rough opening width
DOOR_H  = 76;   // rough opening height

// When true, hide the roof + door panel so the top view reads as a framing
// plan. cad-render sets this (via -D PLAN_VIEW=true) for the plan render only.
PLAN_VIEW = false;

JOIST   = "2x6";          // floor joists
FRAME   = "2x4";          // wall + roof framing
DECK_T  = 0.75;           // floor deck plywood
ROOF_T  = 0.5;            // roof sheathing plywood

WALL_DEPTH = lumber_dims(FRAME)[0];   // 3.5 — wall thickness
PLATE_T    = lumber_dims(FRAME)[1];   // 1.5 — plate thickness
JOIST_H    = lumber_dims(JOIST)[0];   // 5.5 — floor frame height
DECK_TOP   = JOIST_H + DECK_T;        // top of floor deck; walls start here

/* ───── plan metadata (flows into the PDF) ───── */
plan_meta(
    title    = "Outhouse — Recreational Property",
    subtitle = str(WIDTH, "\" x ", DEPTH, "\" footprint, mono-slope roof, ", DOOR_W, "\" door"),
    units    = "inches",
    material = "construction-grade SPF; pressure-treated floor frame; plywood deck/roof");
plan_dim("Footprint",        str(WIDTH, "\" x ", DEPTH, "\""));
plan_dim("Wall height",      str(H_FRONT, "\" front / ", H_BACK, "\" back"));
plan_dim("Roof slope",       str(round(atan((H_FRONT-H_BACK)/DEPTH)*10)/10, "° (", H_FRONT-H_BACK, "\" drop over ", DEPTH, "\")"));
plan_dim("Door rough op'ng", str(DOOR_W, "\" x ", DOOR_H, "\""));
plan_dim("Stud spacing",     str(STUD_OC, "\" o.c."));
plan_note("Build the floor frame from pressure-treated lumber; everything above can be SPF.");
plan_note("Set the floor frame level on blocks/skids; check it for square before decking.");
plan_note("Sheathe the roof, then add roofing felt + metal or asphalt; cut siding to taste.");
plan_note("Hang the door to swing OUT so it clears the (downhill) interior.");

// Ordered build sequence (rendered as a numbered Assembly Sequence in the PDF).
plan_step("Set level skids/blocks, then build the PT floor frame (rims + joists) and check it for square.");
plan_step("Deck the floor with 3/4\" plywood, fastened to every joist.");
plan_step("Frame the walls on the deck: front tall, back short, side walls cut on the slope; frame the door opening with king + jack studs and a header.");
plan_step("Stand the four walls, plumb and brace them, then nail the corners together.");
plan_step("Set the sloped rafters at 16\" o.c.; sheathe the roof, then felt + metal/asphalt.");
plan_step("Hang the door, add siding/finishes, prime and paint.");

/* ───── floor frame: 2x6 joists on edge + plywood deck ───── */
module floor() {
    // side rims run along Y
    for (x = [0, WIDTH - PLATE_T])
        translate([x, 0, 0]) rotate([0, 0, 90]) translate([0, 0, 0])
            // beam runs along +X; rotate 90° about Z -> runs along +Y
            translate([PLATE_T, 0, 0]) beam(JOIST, DEPTH, "floor side rim");
    // cross joists run along X, between the side rims, at OC
    for (y = [0 : STUD_OC : DEPTH - 1])
        translate([PLATE_T, min(y, DEPTH - PLATE_T), 0])
            beam(JOIST, WIDTH - 2*PLATE_T, "floor joist");
    // deck (hidden in plan view so the joist layout shows through)
    if (!PLAN_VIEW)
        translate([0, 0, JOIST_H]) sheet(DECK_T, WIDTH, DEPTH, "floor deck");
}

/* ───── a stud wall built along +X, sitting on the floor deck ─────
   L  = length, hf/hb = wall height at x=0 / x=L (equal => flat top).
   opening = [x0, w, h] for a door/window rough opening (or undef). */
module stud_wall(L, hf, hb, opening = undef, tag = "wall") {
    sloped = (hf != hb);
    ang = atan((hf - hb) / L);

    // bottom plate
    plate(FRAME, L, str(tag, " bottom plate"));

    // top plate (horizontal, or sloped along the wall)
    if (!sloped)
        translate([0, 0, hf - PLATE_T]) plate(FRAME, L, str(tag, " top plate"));
    else
        translate([0, 0, hf - PLATE_T]) rotate([0, ang, 0])
            plate(FRAME, L / cos(ang), str(tag, " top plate (sloped)"));

    function h_at(x) = hf + (hb - hf) * x / L;

    has_op = !is_undef(opening);
    ox = has_op ? opening[0] : -1;
    ow = has_op ? opening[1] : 0;
    oh = has_op ? opening[2] : 0;

    // common studs at OC, skipping the rough opening
    for (i = [0 : ceil(L / STUD_OC)]) {
        x = min(i * STUD_OC, L - PLATE_T);
        inop = has_op && (x + PLATE_T > ox) && (x < ox + ow);
        if (!inop)
            translate([x, 0, PLATE_T]) stud(FRAME, h_at(x) - 2*PLATE_T, str(tag, " stud"));
    }

    // opening framing: king studs (full height) + jack studs + header
    if (has_op) {
        for (kx = [ox - PLATE_T, ox + ow])         // king studs
            translate([kx, 0, PLATE_T]) stud(FRAME, h_at(kx) - 2*PLATE_T, str(tag, " king stud"));
        for (jx = [ox, ox + ow - PLATE_T])         // jack (trimmer) studs
            translate([jx, 0, PLATE_T]) stud(FRAME, oh, str(tag, " jack stud"));
        translate([ox - PLATE_T, 0, PLATE_T + oh]) // header across the opening
            beam(FRAME, ow + 2*PLATE_T, str(tag, " door header"));
    }
}

/* ───── roof: rafters on edge + plywood sheathing, tilted as one assembly ───── */
module roof() {
    ang = atan((H_FRONT - H_BACK) / DEPTH);
    run = DEPTH + 2*OVERHANG;
    rlen = run / cos(ang);                 // sloped rafter length
    // build flat in local frame (underside at z=0), pivot at front wall plane y=0
    translate([0, 0, DECK_TOP + H_FRONT]) rotate([-ang, 0, 0])
    translate([0, -OVERHANG, 0]) {
        for (i = [0 : ceil(WIDTH / STUD_OC)]) {
            x = min(i * STUD_OC, WIDTH - PLATE_T);
            translate([x + PLATE_T, 0, 0]) rotate([0, 0, 90]) beam(FRAME, rlen, "rafter");
        }
        translate([-OVERHANG, 0, lumber_dims(FRAME)[0]])
            sheet(ROOF_T, WIDTH + 2*OVERHANG, rlen, "roof sheathing");
    }
}

/* ───── door panel (plywood), shown in the opening ───── */
module door_panel() {
    dx = (WIDTH - DOOR_W) / 2;
    translate([dx, WALL_DEPTH, DECK_TOP]) rotate([90, 0, 0])
        sheet(DECK_T, DOOR_W, DOOR_H, "door panel");
}

/* ───── assembly ───── */
floor();

door_x = (WIDTH - DOOR_W) / 2;
// front wall (door side, tall)
translate([0, 0, DECK_TOP]) stud_wall(WIDTH, H_FRONT, H_FRONT, [door_x, DOOR_W, DOOR_H], "front wall");
// back wall (short)
translate([0, DEPTH - WALL_DEPTH, DECK_TOP]) stud_wall(WIDTH, H_BACK, H_BACK, undef, "back wall");
// side walls (sloped front->back), inset between front and back walls
translate([WALL_DEPTH, WALL_DEPTH, DECK_TOP]) rotate([0, 0, 90])
    stud_wall(DEPTH - 2*WALL_DEPTH, H_FRONT, H_BACK, undef, "left wall");
translate([WIDTH, WALL_DEPTH, DECK_TOP]) rotate([0, 0, 90])
    stud_wall(DEPTH - 2*WALL_DEPTH, H_FRONT, H_BACK, undef, "right wall");

if (!PLAN_VIEW) {
    roof();
    door_panel();
}
