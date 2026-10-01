# md2pdf — rules for Claude sessions

These rules apply whenever a Claude session writes an **illustrative document** — a
guide, report, explainer, plan, prep doc or deck meant to be read as a PDF — in any
project, not only in this repo. A user-level `~/.claude/CLAUDE.md` imports this file.

## Authoring

- **Follow `~/scripts/md2pdf/AUTHORING.md`** (this repo's [`AUTHORING.md`](AUTHORING.md)) for structure, diagrams, 3D models, tables
  and deck layout. It describes what the renderer actually does; treat it as the
  contract, not a style preference. Read it before writing the first document of a
  session.
- Write GitHub-flavoured Markdown. Use ` ```mermaid ` for structure and flow, and
  ` ```openscad ` (inline, `file=model.scad` or `file=part.stl`) for physical objects.
- Reference images by path relative to the document; md2pdf embeds them.
- Don't hand-write a table of contents; the renderer generates one.

## Rendering

- Render with `md2pdf <file>.md` (on `PATH`, installed from this repo by
  `install.sh`). `--present` for a 16:9 deck, `--dark` for the dark theme. Don't call
  `md-to-pdf` directly — it lacks the diagram, 3D, image and watchdog handling.
- The PDF lands next to the source unless `-o <dir>` is given. Don't commit PDFs
  unless the project already does.
- A project that has its own build script for documents (e.g. `bin/hp-build`,
  `bin/cad-build`) — use that instead; it calls md2pdf itself.

## Verifying

Never report a document as done from the exit code alone.

- Read stderr: `⚠ diagram N FAILED`, `⚠ 3D model N FAILED` and `⚠ image not found`
  each mean something in the PDF is wrong, even though the render "succeeded".
- Look at the result: `pdftoppm -r 50 -png file.pdf /tmp/page` and read the pages.
  Check that diagrams are legible, nothing is cut off, and no page is blank.
- For a deck, the page count should be the number of `##` sections plus one (the
  title card). More means a slide overflowed — cut content rather than shrinking it.

## Build plans for physical things (`cad/`)

When asked to **design or build something** (shed, outhouse, bench, planter,
sawhorse, shelf, lean-to — anything made from lumber and sheet goods), produce a
LEGO-style PDF build plan with this repo's `cad/` pipeline rather than writing a
document by hand:

- **Read `~/scripts/md2pdf/cad/README.md` first** — its "Agent runbook" is the
  canonical procedure and its API section is the modelling contract.
- Work inside `~/scripts/md2pdf/cad/`: copy `templates/SKELETON.scad` to
  `projects/<kebab-name>/<kebab-name>.scad`, fill in the `TODO`s, and use
  `projects/outhouse-deluxe/outhouse-deluxe.scad` as the full reference.
- One physical piece = one `board()`/`sheet()` call; the cut list and cost come
  from the geometry. Units are inches; X width, Y depth (front at Y=0), Z up.
- `bin/cad-build projects/<name>` renders the views and builds the PDF via md2pdf.
- **Verify by Reading** the PNGs in `out/` and the PDF, and grep `out/cutlist.md`
  for `| -` (negative lengths) before calling it done.

For a single 3D illustration inside an ordinary document, use an
` ```openscad ` block instead (see `AUTHORING.md` §2.7).

## Changing md2pdf itself

When the renderer's behaviour changes, update `README.md` and `AUTHORING.md` in the
same change — they must describe what the script does. Test against real documents
and compare with the previous version (page counts and `pdftotext` output) before
installing with `./install.sh`.
