// SKELETON.scad — copy to projects/<your-name>/<your-name>.scad and fill in.
// This file is a starting template that exercises every cad-tools convention so
// the resulting PDF is a complete LEGO-style build plan. Search "TODO" to find
// what to change. Renders out of the box (as two stacked rails) once copied.
//   Then:  bin/cad-build projects/<your-name> --open
//
// Read README.md "Agent runbook" first if you haven't.

use <../../lib/lumber.scad>
use <../../lib/figures.scad>

/* ───── parameters ──────────────────────────────────────────────────────────
   Keep all dimensions here so the design is easy to tweak by prompt.
   Units are INCHES.  Axes:  X=width, Y=depth (FRONT at y=0), Z=up.        */
W = 24;     // TODO: overall width  (X)
D = 12;     // TODO: overall depth  (Y) — keep the FRONT at y=0
H = 18;     // TODO: overall height (Z)

PT = 1.5;   // 2x lumber thickness (handy constant)

/* ───── render switches — cad-render overrides these with -D per image ──────
   `use <lumber.scad>` imports modules but NOT variables, so a model that tests
   these must declare them itself, or they are undefined and every test on them
   is false (OpenSCAD only warns).                                            */
PLAN_VIEW  = false;   // true for the plan (top) render: hide roof/decking
SHOW_STAGE = 0;       // n for build-step n's render; 0 = overview
XPLODE     = 0;       // > 0 for the exploded-parts render

/* ───── plan metadata — title block + numbered build sequence (REQUIRED) ─── */
plan_meta(
    title    = "TODO Project Title",
    subtitle = "TODO short one-line description",
    units    = "inches",
    material = "TODO e.g. SPF framing + 3/4\" plywood");

plan_dim("Footprint", str(W, "\" x ", D, "\""));
plan_dim("Height",    str(H, "\""));
// TODO: more plan_dim("Label", "Value") rows as useful

plan_note("TODO assembly tip or material note.");
// TODO: more plan_note() bullets — short, practical

// REQUIRED: one plan_step() per build step, IN ORDER. These print as a
// numbered Assembly Sequence in the PDF. Walk the builder from foundation
// to finishes: skids/footings → floor → walls → roof → fixtures → trim →
// porch/steps → finishes. Use language the human can follow on site.
plan_step("TODO step 1: e.g. set the base on level skids.");
plan_step("TODO step 2: e.g. assemble the frame.");
plan_step("TODO step 3: e.g. attach the top.");

// Cost estimate inputs. Defaults are placeholder US/CAD retail; set
// region-appropriate values. Currency is a string prefix shown in the PDF.
plan_price("currency",  "CAD $");
plan_price("waste_pct", 10);
// plan_price("2x4", 0.95);  plan_price("2x6", 1.65);  plan_price("0.5in ply", 52);

/* ───── extents for the fixed step-render camera (REQUIRED if you use stages)
   Give the overall min/max corners (including any overhangs, porch, etc.) so
   every step shares one camera and the build "grows in place". Bump `fit`
   (1.5–2.0) if the iso clips at the top of any step image.                   */
plan_bounds([0, 0, 0], [W, D, H], 1.7);

/* ───── sub-assembly modules ─────────────────────────────────────────────────
   Group each build phase into ≥1 named module. Within a module, every
   physical piece is exactly one board()/sheet() call (or one of the
   plate/stud/beam helpers). Tag each piece with a short role string that
   contains a STANDARD KEYWORD (stud, plate, sill, header, joist, rim,
   rafter, ridge, sheathing, deck, panel, deck board, tread, seat, trim) so
   the colour coding and colour key map correctly.

   FRAMING CONVENTION: any rectangular frame (floor, porch, deck, ceiling)
   gets rim members at BOTH ends + field members distributed evenly, never
   a single open-loop `for(y=[0:OC:L-1])`. Pattern:
       nb = ceil((span - thick) / OC);
       for (i = [0:nb]) translate([0, i*(span-thick)/nb, 0]) beam(...);
   This guarantees a closed frame with even spacing.                         */

module base() {
    // TODO: replace with the real base/floor/frame for stage 1
    plate("2x4", W, "base rail");
}

module top() {
    // TODO: replace with the real top/roof/cap for stage 2
    translate([0, 0, H - PT]) plate("2x4", W, "top rail");
}

/* ───── staged assembly (drives the LEGO-style Build Instructions) ──────────
   Wrap each phase in stage(n, "title"). The PDF then gets two isometrics per
   step (seated in context with prior parts ghosted, and an exploded view with
   every piece visible). To make the explode work, split each stage into
   sub-assemblies and wrap each in xpart(direction[, mult]). xpart() is a no-op
   in every render except the exploded one. Directions are unit vectors:
       xpart([0,0, 1]) for "lift up off"          (decking off joists, sheathing off rafters)
       xpart([0,0,-1]) for "drop the frame down"
       xpart([0,-1,0]) for "pull forward toward the viewer"  (e.g. door, porch)
       xpart([ 1,0,0]) / [-1,0,0] for left/right walls fanning out             */

stage(1, "TODO step 1 title") {
    base();                          // base stays in place
    // xpart([0,0,-1]) sub_part();   // any sub-assembly that should drop down
}

stage(2, "TODO step 2 title") {
    xpart([0, 0, 1]) top();          // top lifts away in the exploded image
}

// TODO: add more stage(3,...), stage(4,...) for additional build phases.

/* ───── scale figure (overview only — not in the step renders) ────────────── */
SHOW_HUMAN = true;
if (SHOW_HUMAN && SHOW_STAGE <= 0)
    translate([-14, -8, 0]) human(70);   // 5'10" person, standing in front-left
