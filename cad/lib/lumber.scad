// lumber.scad — parametric lumber library for cad-tools
// Units: INCHES.  (1 OpenSCAD unit = 1 inch.)
//
// CORE IDEA — single source of truth
// ----------------------------------
// Every physical piece of material is created by exactly one board()/sheet()
// call. That call BOTH draws the geometry AND echoes a structured "CUTLIST|..."
// line. The render pipeline captures those echoes, so the 3D view and the cut
// list come from the same calls and can never drift. Add a board to the model
// and it appears in the cut list; delete it and it leaves the cut list. There
// is no separate bill of materials to keep in sync.
//
// Metadata for the printed plan (title, notes, key dimensions) is emitted the
// same way, via plan_meta()/plan_note()/plan_dim(), so one capture pass yields
// everything the PDF needs.

// ---- appearance -----------------------------------------------------------
WOOD_COLOR = "#c8a165";   // framing lumber
PLY_COLOR  = "#d8b988";   // sheet goods (plywood/OSB)
$fn = 24;

// ---- staged (LEGO-style) build instructions -------------------------------
// Wrap each build phase in  stage(n, "title") { ... }  in build order. Pieces
// then carry their stage, so the pipeline can render one isometric per step
// (prior parts ghosted, this step's parts in full colour, later parts hidden)
// and list just the parts consumed in that step.
//   SHOW_STAGE = 0  -> overview: everything drawn normally (the default).
//   SHOW_STAGE = n  -> step n render (cad-render sets this with -D per step).
SHOW_STAGE  = 0;
XPLODE      = 0;                            // >0 = exploded-parts view: blow sub-assemblies apart by this (in)
GHOST_COLOR = [0.80, 0.78, 0.72, 0.28];     // already-built parts (translucent)

// Member-type palette: pieces are coloured by role (matched from their tag) so
// the way parts fit together reads clearly. Mirrored in bin/cad-cutlist.py for
// the PDF colour key — keep the keyword order in sync (most-specific first).
ROLE_COLORS = [
    ["deck board", "#caa978"], ["tread", "#caa978"],
    ["sheathing", "#c9b48a"], ["panel", "#c9b48a"], ["deck", "#c9b48a"],
    ["ridge", "#6b8e9e"], ["rafter", "#6b8e9e"],
    ["joist", "#8f9b5a"], ["rim", "#8f9b5a"],
    ["header", "#a85f2b"],
    ["sill", "#b07a3f"], ["plate", "#b07a3f"],
    ["seat", "#9c6b42"], ["trim", "#7e8b5a"],
    ["stringer", "#7a5c3e"],
    ["baluster", "#5d7d74"], ["rail", "#5d7d74"],
    ["ledger", "#8b4a2b"], ["beam", "#8b4a2b"],
    ["post", "#6e5a48"],
    ["king", "#c8a165"], ["jack", "#c8a165"], ["cripple", "#c8a165"], ["stud", "#c8a165"],
];
function _eqsub(h, n, i) = len([for (j = [0:len(n)-1]) if (h[i+j] != n[j]) 1]) == 0;
function _contains(h, n) = len(h) < len(n) ? false :
    len([for (i = [0:len(h)-len(n)]) if (_eqsub(h, n, i)) 1]) > 0;
function _role_color(tag, fb) =
    let(hits = [for (r = ROLE_COLORS) if (_contains(tag, r[0])) r[1]]) len(hits) ? hits[0] : fb;

function _stage_tag() = is_undef($stage) ? "" : str($stage);
function _piece_color(base, tag) =
    (SHOW_STAGE <= 0)      ? _role_color(tag, base) :   // overview: colour by role
    is_undef($stage)       ? _role_color(tag, base) :   // un-staged
    ($stage <  SHOW_STAGE) ? GHOST_COLOR :              // already built (ghost)
    ($stage == SHOW_STAGE) ? _role_color(tag, base) :   // added this step
                             [0, 0, 0, 0];              // future

// ---- nominal lumber cross-sections ---------------------------------------
// Returns [actual_width, actual_thickness] in inches for a nominal name.
// "width" is the wide face; "thickness" is the narrow face.
function lumber_dims(size) =
    size == "1x2"  ? [1.5,  0.75] :
    size == "1x3"  ? [2.5,  0.75] :
    size == "1x4"  ? [3.5,  0.75] :
    size == "1x6"  ? [5.5,  0.75] :
    size == "1x8"  ? [7.25, 0.75] :
    size == "2x2"  ? [1.5,  1.5 ] :
    size == "2x3"  ? [2.5,  1.5 ] :
    size == "2x4"  ? [3.5,  1.5 ] :
    size == "2x6"  ? [5.5,  1.5 ] :
    size == "2x8"  ? [7.25, 1.5 ] :
    size == "2x10" ? [9.25, 1.5 ] :
    size == "2x12" ? [11.25, 1.5] :
    size == "4x4"  ? [3.5,  3.5 ] :
    size == "6x6"  ? [5.5,  5.5 ] :
    [3.5, 1.5];   // fallback: unknown sizes are drawn as 2x4 (also warned)

function lumber_known(size) =
    size=="1x2"||size=="1x3"||size=="1x4"||size=="1x6"||size=="1x8"||
    size=="2x2"||size=="2x3"||size=="2x4"||size=="2x6"||size=="2x8"||
    size=="2x10"||size=="2x12"||size=="4x4"||size=="6x6";

// ---- primitives -----------------------------------------------------------
// board(): the one true primitive. Drawn from the origin with
//   length  along +X
//   width   along +Y   (wide face up/down -> lies flat)
//   thickness along +Z
// Use the oriented helpers below, or translate()/rotate() directly, to place.
module board(size, length, tag="") {
    d = lumber_dims(size); w = d[0]; t = d[1];
    if (!lumber_known(size)) echo(str("WARNING|unknown lumber size '", size, "' drawn as 2x4"));
    echo(str("CUTLIST|lumber|", size, "|", length, "|", w, "|", t, "|", tag, "|", _stage_tag()));
    color(_piece_color(WOOD_COLOR, tag)) cube([length, w, t]);
}

// sheet(): plywood / OSB panel. Drawn lying flat:
//   w along +X, h along +Y, thickness along +Z.
module sheet(thick, w, h, tag="") {
    echo(str("CUTLIST|sheet|", thick, "in ply|", w, "|", h, "|", thick, "|", tag, "|", _stage_tag()));
    color(_piece_color(PLY_COLOR, tag)) cube([w, h, thick]);
}

// stringer(): a notched stair stringer cut from one board (2x12 is standard).
// A plain board() can't draw one — a rectangle pokes through the treads — so
// this draws the real sawtooth profile and emits one cut-list line for the
// stock it is cut from. Drawn with the run along +X (bottom of the stair at
// x=0, rising toward +X), rise along +Z, thickness along +Y.
//   risers : number of risers (the top one lands on the deck/floor)
//   rise   : height of each riser;  run : depth of each tread seat
//   tt     : tread thickness — seats are cut this far below each step height,
//            and the top plumb cut sits this far below the landing surface
// Treads are not included: place them with plate() on the seats, the top of
// tread i (1..risers-1) at z = i*rise over x in [(i-1)*run, i*run].
function stringer_seat_z(i, rise, tt) = i * rise - tt;
module stringer(size, risers, rise, run, tt = 1.5, tag = "stair stringer") {
    d = lumber_dims(size); w = d[0]; t = d[1];
    if (!lumber_known(size)) echo(str("WARNING|unknown lumber size '", size, "' drawn as 2x4"));
    n = risers;
    th = atan(rise / run);
    h1 = stringer_seat_z(1, rise, tt);
    drop = w / cos(th);                         // vertical depth of the board
    xg = max(0, (drop - h1) * run / rise);      // where the bottom edge meets grade
    xt = (n - 1) * run;                         // top plumb cut (against the rim)
    zb = h1 + xt * rise / run - drop;           // bottom edge at the plumb cut
    teeth = [for (i = [1 : n - 1]) each [[(i - 1) * run, stringer_seat_z(i, rise, tt)],
                                         [i * run,       stringer_seat_z(i, rise, tt)]]];
    pts = concat([[xg, 0], [0, 0]], teeth,
                 [[xt, stringer_seat_z(n, rise, tt)], [xt, max(zb, 0)]]);
    // stock length = the profile's extent along the slope
    u = [cos(th), sin(th)];
    proj = [for (p = pts) p * u];
    len_in = ceil(max(proj) - min(proj));
    echo(str("CUTLIST|lumber|", size, "|", len_in, "|", w, "|", t, "|", tag, "|", _stage_tag()));
    color(_piece_color(WOOD_COLOR, tag))
        translate([0, t, 0]) rotate([90, 0, 0]) linear_extrude(t) polygon(pts);
}

// ---- oriented framing helpers --------------------------------------------
// Three ways to lay the same board, all starting at the origin. Positioning is
// then just a translate(). Pick by role:
//   plate(size,len) : lies FLAT  -> length along X, wide face down (plates, blocking)
//   stud (size,len) : stands UP  -> length along Z, thickness along X, width along Y
//   beam (size,len) : on EDGE    -> length along X, width VERTICAL (joists, rafters, headers)
module plate(size, length, tag="plate") {
    board(size, length, tag);
}
module stud(size, length, tag="stud") {
    t = lumber_dims(size)[1];
    translate([t, 0, 0]) rotate([0, -90, 0]) board(size, length, tag);
}
module beam(size, length, tag="beam") {
    t = lumber_dims(size)[1];
    translate([0, t, 0]) rotate([90, 0, 0]) board(size, length, tag);
}

// ---- plan metadata (captured from echoes by the render pipeline) ----------
module plan_meta(title, subtitle="", units="inches", material="") {
    echo(str("META|title|", title));
    if (subtitle != "") echo(str("META|subtitle|", subtitle));
    echo(str("META|units|", units));
    if (material != "") echo(str("META|material|", material));
}
module plan_note(text) { echo(str("NOTE|", text)); }   // one assembly-note bullet
module plan_dim(label, value) { echo(str("DIM|", label, "|", value)); }  // a key dimension row
module plan_step(text) { echo(str("STEP|", text)); }   // one ordered build step (call in build order)
// plan_price(key, value): unit price / cost setting for the cost estimate.
//   key = a lumber size ("2x4" -> $/linear ft), "<t>in ply" ($/4x8 sheet),
//   "waste_pct" (number), or "currency" (e.g. "CAD $"). Overrides built-in defaults.
module plan_price(key, value) { echo(str("PRICE|", key, "|", value)); }

// stage(n, title): wrap a build phase. Sets $stage on its pieces and, in step
// mode (SHOW_STAGE=n), draws prior stages ghosted, this stage in colour, and
// hides later stages. In overview mode it just draws and records the title.
module stage(n, title = "") {
    $stage = n;
    if (SHOW_STAGE <= 0) { echo(str("STAGEMETA|", n, "|", title)); children(); }
    else if (n == SHOW_STAGE) children();                  // current step (xpart() may blow it apart)
    else if (n < SHOW_STAGE && XPLODE <= 0) children();    // prior parts: ghosted, only in the in-place view
    // future stages, and prior stages in the exploded view, are not drawn
}

// xpart(dir, mult): offset a sub-assembly by dir*XPLODE*mult — but only in the
// exploded-parts view (XPLODE>0). In every other render it is a no-op, so the
// in-place/overview geometry is untouched. Wrap each sub-assembly of a stage in
// xpart() with a direction so the parts blow apart without hiding each other.
module xpart(dir, mult = 1) {
    translate(dir * (XPLODE * mult)) children();
}

// plan_bounds(lo, hi): declare the model's overall extent so step renders use a
// fixed camera (the build "grows in place" instead of being re-framed each step).
module plan_bounds(lo, hi, fit = 1.5) {
    c = [(lo[0]+hi[0])/2, (lo[1]+hi[1])/2, (lo[2]+hi[2])/2];
    echo(str("BOUNDS|", c[0], "|", c[1], "|", c[2], "|",
             norm([hi[0]-lo[0], hi[1]-lo[1], hi[2]-lo[2]]) * fit));
}
