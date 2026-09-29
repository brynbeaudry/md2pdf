# md2pdf — Markdown → PDF (headless Chromium)

A small Bash wrapper around the `md-to-pdf` npm package that adds:

- **Mermaid** diagrams rendered inline as SVG (via `mmdc`).
- **PlantUML** diagrams via the public PlantUML server (via `curl`).
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
   PlantUML blocks via the public server (`curl`), each to an SVG, then embed
   them in the Markdown as base64-data `<img>` tags inside a `.diagram-container`.
3. **Convert** the resulting Markdown through `md-to-pdf` with a bundled
   GitHub-flavoured stylesheet, and A4 portrait or 16:9 landscape print options.

A failed Mermaid render leaves a visible warning block in the PDF (and prints to
stderr) instead of silently falling back to a code listing.

## Troubleshooting

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
└── README.md       # this file
```

## License

Personal tool — distribute freely.
