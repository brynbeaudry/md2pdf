# md2pdf — Markdown → PDF (headless Chromium)

A small Bash wrapper around the `md-to-pdf` npm package that adds:

- **Mermaid** diagrams rendered inline as SVG (via `mmdc`).
- **PlantUML** diagrams via the public PlantUML server (via `curl`).
- **3D models** — ` ```openscad ` blocks (inline OpenSCAD, a `.scad` file, or an
  STL/3MF mesh) rendered to one or more views (via `openscad`).
- **Local images that just work** — relative `![](fig.png)` and `<img src>` paths
  are resolved against the source document and embedded.
- **`cad/` — woodworking build plans**: an agent turns a text prompt into a
  parametric OpenSCAD model and a LEGO-style PDF plan (renders, staged build
  steps, cut list, cost estimate). See [`cad/README.md`](cad/README.md).
- A **watchdog** around `md-to-pdf`, which intermittently wedges on its browser
  launch: detected, killed and retried automatically.
- A GitHub-flavoured stylesheet (light/dark), automatic Table of Contents
  injection for docs with ≥3 headings, heading anchors, and an A4 print layout.

The script itself is pure Bash and has no Node dependency of its own — it shells
out to the tools below.

## Requirements

| Tool | Install | Used for |
|---|---|---|
| **Node + npm** | a version manager — [`n`](https://github.com/tj/n) (`n lts`) or [`nvm`](https://github.com/nvm-sh/nvm); or https://nodejs.org | runs `md-to-pdf` and `mmdc` |
| **md-to-pdf** | `npm install -g md-to-pdf` | Markdown → PDF (headless Chromium) |
| **mmdc** | `npm install -g @mermaid-js/mermaid-cli` | Mermaid diagram rendering |
| **curl** | preinstalled on macOS / most Linux | PlantUML over the public server |
| **python3** | preinstalled on macOS / most Linux | PlantUML encoding, image embedding |
| **openscad** *(optional)* | macOS: `brew install --cask openscad@snapshot` · Linux: your package manager | ` ```openscad ` 3D blocks |

On macOS use the **snapshot** (nightly) cask: the stable `openscad` cask is years
old and is killed by Gatekeeper on recent macOS. Without OpenSCAD, 3D blocks are
left as code listings and everything else works.

Built and used on macOS (Darwin). Should work on Linux with the same deps. On
Windows, run under WSL.

## Install

The quickest way — `./install.sh` from this folder:

```sh
cd ~/scripts/md2pdf
./install.sh                       # copies md2pdf to ~/.local/bin and reports missing deps
./install.sh /usr/local/bin        # or pick your own PATH dir
```

Or do it by hand:

```sh
mkdir -p ~/.local/bin
cp md2pdf ~/.local/bin/
chmod +x ~/.local/bin/md2pdf
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc   # or ~/.bashrc
source ~/.zshrc
npm install -g md-to-pdf @mermaid-js/mermaid-cli
```

Smoke test:

```sh
printf '# Hello\n\n```mermaid\nflowchart LR; A-->B\n```\n' > /tmp/hello.md
md2pdf /tmp/hello.md --open
```

## Usage

```sh
md2pdf file.md                    # → file.pdf (same directory)
md2pdf file.md -o ~/Desktop       # → ~/Desktop/file.pdf
md2pdf *.md -o ./pdfs             # batch convert
md2pdf file.md --dark             # dark theme
md2pdf file.md --present          # 16:9 slide deck, one slide per H2
md2pdf file.md --open             # open the PDF after conversion (macOS)
md2pdf -h                         # full help
```

**Writing the source matters as much as the flags.** [`AUTHORING.md`](AUTHORING.md) is the guide
to structuring a document or a deck for this renderer: section shape, the Mermaid conventions and
the two traps it cannot fix for you, what fits on a slide, and which parts of the opening the
renderer generates versus expects you to author.

### Presentation mode

`--present` renders 13.333 x 7.5in landscape, one slide per `##`, with larger type and a capped
diagram height so a diagram and the prose interpreting it stay on the same slide. It opens with a
title card (the H1 and its framing paragraph) followed by a generated two-column agenda card. To
write your own agenda instead, give the document a `##` section headed `Overview`, `Agenda`,
`Contents`, `In this deck`, `On the agenda`, `What's covered`, or `How to read` — the renderer
detects it and injects nothing. `--dark` composes with it.

### 3D models

A fenced block tagged `openscad` is rendered with OpenSCAD and embedded as images.
Options go after the tag, space-separated:

| Option | Meaning | Default |
|---|---|---|
| `view=` | `iso` (perspective), `top`, `front`, `side`, `back`, `left` — or a comma list shown side by side | `iso` |
| `file=` | render a `.scad` file or a mesh (`.stl` `.3mf` `.obj` `.off` `.amf`), relative to the document; the block body is ignored | inline body |
| `size=` | pixels per view, `WxH` | `1600x1200` |
| `define=NAME=VALUE` | passed to the model as `-D NAME=VALUE`; repeatable | — |

    ```openscad view=iso,front,side
    use <parts/lib.scad>          // resolved against the document's folder
    cube([30, 20, 4]);
    translate([20, 10, 4]) import("parts/bracket.stl");
    ```

    ```openscad file=models/box.scad define=W=40
    ```

Inline source resolves `use`/`include` against the document's folder, and relative
`import()`/`surface()` paths are rewritten to it, so a document and its model files
can live side by side. `--dark` switches the render colour scheme too. A model
that fails shows a visible warning box with OpenSCAD's error, plus the source.

For full multi-step build plans (staged LEGO-style renders, exploded views, cut
lists) see the separate `cad-tools` project, which generates Markdown for md2pdf.

### Local images

Relative image paths resolve against the source document, not the temp copy
md-to-pdf renders, and are embedded as data URIs — so `![](figs/a.png)` works
and the PDF is self-contained. Remote URLs and fenced code are left alone; a
missing file prints `⚠ image not found` and renders as a broken image.

### Diagram blocks

Diagram blocks are detected automatically inside fenced code:

    ```mermaid
    flowchart LR
      A --> B
    ```

    ```plantuml
    @startuml
    Alice -> Bob: hi
    @enduml
    ```

## How it works

For each input file:

1. **Inject** a contents block + heading anchors (skipped if <3 headings), placed
   after the H1's framing paragraph. In `--present` this becomes an `Overview`
   agenda card, suppressed when the document already has an overview section.
2. **Pre-process diagram fences**: render Mermaid blocks with `mmdc` and
   PlantUML blocks via the public server (`curl`), each to an SVG, and
   OpenSCAD blocks with `openscad` to PNG views, then embed them in the Markdown
   as base64-data `<img>` tags inside a `.diagram-container`.
3. **Embed local images** referenced by relative or absolute path.
4. **Convert** the resulting Markdown through `md-to-pdf` with a bundled
   GitHub-flavoured stylesheet, and A4 portrait or 16:9 landscape print options,
   under a watchdog (below).

A failed Mermaid render leaves a visible warning block in the PDF (and prints to
stderr) instead of silently falling back to a code listing.

## Troubleshooting

### `⚠ md-to-pdf wedged (no browser after 20s) — attempt 1/3`

md-to-pdf intermittently hangs while launching Puppeteer's Chromium: 0% CPU, no
browser process, forever — sometimes several runs in a row. md2pdf watches for
it: a run that has started no browser after `MD2PDF_LAUNCH_TIMEOUT` seconds
(default 20; a healthy one starts within a second) is killed and retried, up to
3 attempts. `MD2PDF_TIMEOUT` (default 90) is a backstop for a render that hangs
after launch — raise it for very large documents. md-to-pdf is also given an
empty stdin, because it reads Markdown from a piped stdin and would otherwise
wait on one that never closes (e.g. when run from an agent or CI).

### `ArgError: unknown or unexpected option: -o` (or `--open`, `--dark`, …)

The `md-to-pdf` npm package installs **two** binaries that both point at its own
`cli.js`: `md-to-pdf` *and* an alias literally named `md2pdf`. That alias
(`~/n/bin/md2pdf`, or wherever your global npm bin is) collides with this script
and, if it wins the `PATH` lookup, receives flags it doesn't understand — hence
the error above coming from `md-to-pdf/dist/cli.js`, not from this script.

Fix: delete the colliding alias (the real `md-to-pdf` command stays):

```sh
rm "$(dirname "$(command -v md-to-pdf)")/md2pdf"   # removes only the alias
hash -r                                            # clear the shell's command cache
command -v md2pdf                                  # should now be ~/.local/bin/md2pdf
```

It comes back every time you (re)install or update `md-to-pdf` globally, so
re-run the `rm` after a `npm install -g md-to-pdf`. Keeping your install dir
(e.g. `~/.local/bin`) ahead of the npm global bin on `PATH` also makes this
script win regardless.

### `Could not find Chrome (ver. X)`

`mmdc` (mermaid-cli) and `md-to-pdf` each bundle a *different* Puppeteer pinned
to a *different* Chrome build, both cached under `~/.cache/puppeteer`. If a build
is missing, reinstall just that tool's browser from its own package:

```sh
cd "$(npm root -g)/@mermaid-js/mermaid-cli"   # or .../md-to-pdf
node node_modules/puppeteer/install.mjs
```

If Puppeteer downloads the zip but the executable is still missing (the unpack
truncates), verify and extract it by hand — don't wipe all of
`~/.cache/puppeteer`, or you'll delete the other tool's Chrome too:

```sh
cd ~/.cache/puppeteer/chrome-headless-shell/mac_arm-<ver>
unzip -t ../<ver>-chrome-headless-shell-*.zip   # confirm the zip is intact
unzip -o ../<ver>-chrome-headless-shell-*.zip   # extract into place
```

## Layout

```
scripts/md2pdf/
├── md2pdf          # the script (executable)
├── install.sh      # copies md2pdf to a PATH dir + reports missing deps
├── AUTHORING.md    # how to write a document or deck for this renderer
├── CLAUDE.md       # agent rules: points Claude sessions at AUTHORING.md + cad/
├── README.md       # this file
└── cad/            # build-plan generator (OpenSCAD → md2pdf); see cad/README.md
    ├── bin/        #   cad-build, cad-render, cad-plan, cad-open, cad-cutlist.py
    ├── lib/        #   lumber.scad (board/sheet + cut list), figures.scad
    ├── templates/  #   SKELETON.scad — start every new plan from this
    └── projects/   #   one folder per plan; outhouse + outhouse-deluxe examples
```

## License

Personal tool — distribute freely.
