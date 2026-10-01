# cad — woodworking build plans from a text prompt

Part of the md2pdf repo (`cad/`). Everything below runs from this folder; the PDF
step uses the repo's own `md2pdf` (`../md2pdf`).

Turn a **text description** of a small wood build (outhouse, shed, planter, bench,
sawhorse, lean-to…) into a **PDF plan**: an isometric render, a plan + elevation
"blueprint", and a **cut list of every piece of lumber** to cut. No CAD program
required to get the PDF — but you can open the model in one any time.

The generator is **OpenSCAD** (parametric, code-driven CAD). An **AI agent
(Claude) writes the model** from your prompt; the scripts here render it and
assemble the PDF. The model is the single source of truth: every physical board
both draws itself *and* emits its own cut-list line, so the drawing and the cut
list can never disagree.

```
prompt ──▶ projects/<name>/<name>.scad ──▶ cad-render ──▶ out/view-*.png + .stl + cutlist
                  (agent writes this)                └─▶ cad-plan ──▶ out/<name>-plan.pdf
```

---

## Quick start

```bash
cd ~/scripts/md2pdf/cad
bin/cad-build projects/outhouse --open      # render + build PDF, then open it
```

Output lands in `projects/outhouse/out/` — open `outhouse-plan.pdf`.

To change the build, edit the parameters at the top of
`projects/outhouse/outhouse.scad` (or ask the agent to) and re-run `cad-build`.

> Tip: add the tools to your PATH so you can run them anywhere:
> `export PATH="$HOME/scripts/md2pdf/cad/bin:$PATH"` (in `~/.zshrc`).

### Requirements

- Everything md2pdf needs (see the repo `README.md`), plus `python3`.
- **OpenSCAD — the nightly/snapshot build.** macOS: `brew install --cask openscad@snapshot`.
  The stable `openscad` cask (2021.01) fails macOS Gatekeeper and is SIGKILL'd on launch.
  `cad-render` uses `openscad` on `PATH`, else `/Applications/OpenSCAD.app`.
- Generated output (`projects/*/out/`) is git-ignored; only the `.scad` model is source.

---

## Agent runbook  ← read this if you are Claude

You have been given a text prompt describing something to build out of wood.
Produce a complete LEGO-style PDF plan **entirely from this folder**, end to
end. Steps:

1. **Start from the template.** Copy `templates/SKELETON.scad` to
   `projects/<kebab-name>/<kebab-name>.scad`:
   ```bash
   mkdir -p projects/<name> && cp templates/SKELETON.scad projects/<name>/<name>.scad
   ```
   The skeleton already exercises every required pattern; you replace the
   `TODO`s with the real design. `projects/outhouse-deluxe` is the canonical
   full-featured example — read it when you need to see a pattern in action.

2. **Model the geometry.** Build the structure out of `board()` / `sheet()`
   (or the `plate` / `stud` / `beam` helpers). **One physical piece = one
   `board()`/`sheet()` call** — never hand-write a cut list, let it fall out of
   the geometry. Group each build phase into one or more **named sub-assembly
   modules** so the staged Build Instructions can reference them.

3. **Emit plan metadata** (required). Title block with `plan_meta(...)`, key
   dimensions with `plan_dim(...)`, assembly tips with `plan_note(...)`, and
   an ordered build sequence via `plan_step(...)` — one call per real assembly
   step, in build order. Walk the builder from foundation → floor → walls →
   roof → fixtures → trim → porch/steps → finishes.

4. **Set cost inputs.** An **Estimated material cost** table is auto-appended
   to the cut-list totals (lumber by $/linear ft, plywood by $/sheet, + waste).
   Built-in defaults work as placeholders; override for region with
   `plan_price("currency", "CAD $")`, `plan_price("waste_pct", 12)`, and any
   `plan_price("<size>", <unit price>)` rows. Tell the user the figures are
   rough — they exclude fasteners, roofing, hardware, and finishes.

5. **Stage the build for LEGO-style instructions.** Wrap each build phase in
   `stage(n, "title") { ... }` (in build order) and call `plan_bounds(...)`
   once with the overall extent. Split each stage into sub-assembly modules
   and wrap each in `xpart(direction[, mult])` so they blow apart in the
   exploded view. The PDF then gets, per step, **two isometrics** (seated in
   context with ghosted prior, *and* exploded with every piece visible) plus
   the parts list. See "Staged build instructions" in the API below.

6. **Render and inspect.**
   ```bash
   bin/cad-render projects/<name>
   ```
   Then **Read** the generated PNGs in `out/` — `view-iso.png`, `view-plan.png`,
   `view-front.png`, `view-side.png`, every `step-*.png` (in-place + exploded)
   — and check: geometry looks right, nothing clipped, the exploded views show
   every piece, no negative-length pieces in `out/cutlist.md`. Fix the `.scad`
   and re-render until clean.

7. **Build the PDF.**
   ```bash
   bin/cad-plan projects/<name> --open      # or do 6+7 in one with bin/cad-build
   ```
   Output: `projects/<name>/out/<name>-plan.pdf`. **Read the PDF back**
   (paginated; use the `pages` arg) and verify the title + dimensions, all
   overview renders, the colour key, both step images per step, the parts
   lists, the full cut list with cost estimate, and the assembly notes.

8. **Iterate.** "Make it 6 ft wide", "add a window on the left", "change the
   roof" → edit the parameters block at the top of the `.scad` (cheap) or the
   geometry modules (more involved), and re-run `bin/cad-build`.

### Conventions you must follow when writing a model
- **Units are inches.** 1 OpenSCAD unit = 1 inch. Use real lumber sizes.
- **Axes:** `X` = width (left↔right), `Y` = depth (front↔back), `Z` = up.
  Put the "front" (door/access side) at **`Y = 0`** so the front elevation shows
  it. `cad-render` renders: iso, plan (looking down Z), front elevation (along
  Y), side elevation (along X).
- **Plan view:** wrap roof/cladding in `if (!PLAN_VIEW) { ... }`. `cad-render`
  passes `-D PLAN_VIEW=true` for the plan render only, so the top view reads as a
  framing plan instead of just showing the roof. (Harmless to omit.)
- **Tag every piece** with a short role string that contains a **standard
  keyword**, because the tag drives three things: the "Used for" column, the
  cut-list grouping, AND the **colour-coding** (pieces are auto-coloured by
  member type, with a colour key in the PDF). Use these keywords so colours map:
  `stud`/`king`/`jack`/`cripple`, `plate`/`sill`, `header`, `joist`/`rim`,
  `rafter`/`ridge`, `sheathing`/`deck`/`panel`, `deck board`/`tread`, `seat`,
  `trim`. Unmatched tags fall back to the default wood/ply colour (still fine).
- Identical pieces (same size + length + tag) are auto-counted as a quantity, so
  just call `board()` in a `for` loop; you don't manage counts yourself.
- **Always include an ordered build sequence** (`plan_step()` in build order) —
  see step 3. A plan without one is incomplete.
- **Frame between two rim members and distribute the field evenly.** Any
  rectangular frame (floor, porch, deck, ceiling) gets rim members at **both**
  ends and field members distributed evenly at ≤16″ o.c. Pattern:
  ```openscad
  nb = ceil((span - thick) / STUD_OC);
  for (i = [0 : nb]) translate([..., i * (span - thick) / nb, 0]) beam(...);
  ```
  Never open-loop `for (y = [0 : STUD_OC : L - 1])` — that leaves the far edge
  open and the last bay an uneven remainder.
- **Verify by Reading.** Every iteration ends with you Reading the generated
  PNGs and the PDF and scanning `cutlist.md` for negatives. Don't declare a
  plan done without looking at the actual output.

---

## `lib/lumber.scad` — modeling API

```openscad
use <../../lib/lumber.scad>     // path from projects/<name>/<name>.scad
```

**Primitives** (each draws geometry *and* emits one `CUTLIST` line):
| Call | Draws | Notes |
|------|-------|-------|
| `board(size, length, tag)` | a stick of lumber along **+X** (width→+Y, thickness→+Z) | `size` like `"2x4"` |
| `sheet(thick, w, h, tag)`  | a panel lying flat (w→+X, h→+Y, thick→+Z) | plywood/OSB |

**Oriented helpers** (same board, laid three ways; start at origin, then `translate()`):
| Call | Lays the board | Use for |
|------|----------------|---------|
| `plate(size, length, tag)` | **flat**, length along X, wide face down | plates, blocking, decking nailers |
| `stud(size, length, tag)`  | **vertical**, length along Z | wall studs, posts |
| `beam(size, length, tag)`  | **on edge**, length along X, wide face vertical | joists, rafters, headers |

**Plan metadata** (captured into the PDF):
| Call | Effect |
|------|--------|
| `plan_meta(title, subtitle, units, material)` | PDF title block |
| `plan_dim(label, value)` | one row in the Key Dimensions table |
| `plan_note(text)` | one bullet under Assembly Notes |
| `plan_step(text)` | one step in the numbered **Assembly Sequence** — call in build order (required) |
| `plan_price(key, value)` | cost-estimate input: a lumber size → $/linear ft, `"<t>in ply"` → $/sheet, `"waste_pct"`, `"currency"`. Overrides built-in defaults. |

**Helpers / data:**
- `lumber_dims(size)` → `[width, thickness]` in inches.
- Known sizes: `1x2 1x3 1x4 1x6 1x8 2x2 2x3 2x4 2x6 2x8 2x10 4x4 6x6`.
  Unknown sizes draw as a `2x4` and emit a warning into the cut list.

**Scale figures — `lib/figures.scad`:** `use <../../lib/figures.scad>` then
`human(height=70)` draws a person (feet at origin, facing +Y) for scale in the
renders. It uses raw primitives, **not** `board()/sheet()`, so it is never in the
cut list. Gate it: `if (SHOW_HUMAN && !PLAN_VIEW) translate([...]) human();`.

**Staged build instructions (LEGO-style):** wrap each build phase in
`stage(n, "title") { ... }` in build order. The PDF then gets a **Build
Instructions** section with **two isometrics per step** plus the parts consumed:
1. *in the build so far* — this step's parts seated in place, earlier parts
   ghosted translucent, on a fixed camera so the build grows in place;
2. *parts exploded* — just this step's pieces blown apart and auto-framed so
   **every piece is visible** (nothing hidden behind a panel/plate).

To make the explode work, split each stage into sub-assemblies and wrap each in
**`xpart(direction, mult=1)`** (a no-op except in the exploded render), e.g.:
```openscad
stage(4, "Roof") { roof_rafters(); xpart([0,0,1.4]) roof_sheathing(); }   // lift sheathing off rafters
stage(2, "Walls") { xpart([0,-1,0]) front(); xpart([0,1,0]) back(); xpart([-1,0,0]) left(); xpart([1,0,0]) right(); }
```
Add `plan_bounds([xlo,ylo,zlo],[xhi,yhi,zhi], fit)` once (overall extent incl.
porch/roof; `fit`≈1.5–1.9) so the in-place views share one camera. `cad-render`
sets `-D SHOW_STAGE=n` (and `-D XPLODE=…` for the exploded image) per step; with
no `stage()`s the whole section is omitted. Keep the scale figure out of steps
with `&& SHOW_STAGE <= 0`. Stages are numbered 1..N in build order.

Renders also show **edges** and **colour-by-member-type** (tag keywords above; a
colour key prints in the PDF). Note: per-piece **3D text labels with leader lines
are intentionally not done** — they don't lay out reliably in OpenSCAD. The
explode + colour key + each step's "parts added" list are the reliable substitute
for labelling, and `xpart()` separates sub-assemblies (decks, walls, layers), not
every individual board.

**Starter template:** `templates/SKELETON.scad` is a complete, copy-paste
scaffold that uses every API call above, runs out of the box, and has `TODO`
markers where you fill in the real design. Copy it to
`projects/<name>/<name>.scad` and build from there. The canonical full-featured
reference is `projects/outhouse-deluxe/outhouse-deluxe.scad` — read it when you
need to see a pattern (sloped walls, openings + framing, porch, seat, trim,
stages, xpart directions) used in anger.

---

## Scripts (`bin/`)

| Command | What it does |
|---------|--------------|
| `cad-render <proj\|file.scad>` | Renders iso + plan + front + side PNGs, exports `model.stl`, captures echoes, writes `cutlist.{md,json}` and `meta.json` into `out/`. |
| `cad-plan <proj> [--open] [--dark]` | Assembles `out/<name>-plan.md` (images base64-embedded) and runs `md2pdf` → `out/<name>-plan.pdf`. |
| `cad-build <proj> [--open] [--dark]` | `cad-render` then `cad-plan`. The usual entry point. |
| `cad-open <proj>` | Opens the `.scad` in the OpenSCAD GUI for manual editing (live-reloads). |
| `cad-cutlist.py` | Internal: parses captured echoes into the cut list (called by `cad-render`). |

Notes:
- The PDF step runs this repo's `md2pdf` (`../md2pdf`), falling back to `~/.local/bin/md2pdf`.
  Images are base64-embedded so they survive md2pdf's temp-dir copy.
- `model.stl` is best-effort and not required for the PDF; it's there so you can
  import the shape into other software later.

---

## Editing in a CAD program

You don't need one for the PDF, but when you want to:

- **OpenSCAD GUI** (already installed): `bin/cad-open projects/<name>`. Edit the
  `.scad` in any editor (or by prompt) and OpenSCAD live-updates the 3D preview.
  This is the most direct path — the `.scad` *is* the model.
- **Other CAD (Fusion, FreeCAD, SketchUp, etc.):** import `out/model.stl`. Note
  STL is a unitless mesh; since we model in inches, set the import unit to inches
  (or scale ×25.4 if the tool assumes mm). For editable solids rather than a
  mesh, regenerate as STEP via a future `build123d`/CadQuery path (see below).

### Two ways to make changes
1. **By prompt** — ask the agent to tweak `projects/<name>/<name>.scad`, then it
   re-runs `cad-build` and you get a fresh PDF. Best for parametric changes
   ("make it taller", "add a shelf").
2. **By hand in OpenSCAD** — `cad-open`, drag/edit in the GUI or editor. Re-run
   `cad-build` afterward to refresh the PDF + cut list.

---

## How it fits together (and why OpenSCAD, not a text-to-3D AI)

AI *mesh* generators (Meshy, Tripo, Rodin, Luma) make visually-plausible blobs
with **no real dimensions and no discrete parts** — useless for cutting wood.
This pipeline instead has the agent write **parametric CAD code**, so you get
exact lumber sizes and a cut list derived from the same geometry that's drawn.

```
lib/lumber.scad      reusable lumber library (board/sheet + cut-list echoes)
lib/figures.scad     non-structural scale figures (human); never in the cut list
bin/                 cad-render, cad-plan, cad-build, cad-open, cad-cutlist.py
templates/
  SKELETON.scad      copy this to projects/<name>/<name>.scad to start a new plan
projects/<name>/     ← each plan gets its own self-contained folder
  <name>.scad        the model (single source of truth; edit this)
  notes.md           (optional) extra assembly notes appended verbatim
  out/               generated: PNGs, STL, cutlist.*, meta.json, <name>-plan.pdf

Example projects:
  projects/outhouse         simple mono-slope outhouse (no staging — minimal demo)
  projects/outhouse-deluxe  full-featured reference: shed roof, sloped walls,
                            framed window, interior seat, porch + step, door trim,
                            stages + xpart explode, cost estimate, scale figure
```

## Limitations / future enhancements
- Sheet-goods totals estimate panel count by **area only** (no cut-nesting/
  optimization). Treat "4×8 sheets (approx)" as a lower bound; add ~10% waste.
- Imperial only for now. A `metric` flag in `lumber.scad` would be easy to add.
- Joinery is modeled as overlapping members (good enough for a render + cut
  list), not true mortise/tenon/birdsmouth cuts.
- Want editable solids + STEP export + fancier BOMs? A parallel **CadQuery /
  build123d** (Python) backend could slot in beside OpenSCAD using the same
  `cad-plan` PDF step.
