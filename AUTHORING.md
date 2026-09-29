# Authoring illustrative documents for md2pdf

How to write a Markdown file that renders well through `md2pdf`. Two output shapes are supported and they want different source: a **document** (A4 portrait, the default) and a **deck** (`--present`, 16:9 landscape). Most of this file applies to both; §4 is deck-only.

Everything here describes what the renderer actually does. When the tool changes, this file changes with it — it is the contract, not a style preference.

---

## 1. Structure

- **Open with an H1 and a short framing paragraph** (1-3 sentences, no heading) saying what the document is and its scope. In a deck this pair *is* the title card.
- **Do not hand-write a table of contents.** The renderer injects one after the H1 — a contents list in a document, an agenda card in a deck. See [§4.1](#41-the-title-card-and-the-overview-card) for how to override it.
- **Order general to specific**, across sections and within them. The first section is the map.
- **Nest `##` → `###` → `####`.** Break a section into subsections whenever the material supports it rather than running long flat prose.
- **Number sections (`## 1. …`) only when the document cross-references itself.** When numbered, cross-reference with inline anchor links (`[§2.1](#21-...)`). Plain names otherwise.
- **Separate top-level sections with `---`** in a document. Omit in a deck — the page break is the separator.
- **Attribute derived content** with a source blockquote under the heading: `> *Source: path/to/file.md §3.2*`.
- **Close long documents** with a glossary and/or a status table.
- **Spell out acronyms** on first use. Keep product names as-is.

## 2. Diagrams

Lead a section with a Mermaid diagram, **before** the prose, then let the prose interpret it. Add one only when it aids understanding of structure, flow, or relationships — never one that restates the text.

Pick by purpose: `flowchart` (architecture, data flow, lifecycle — the default), `erDiagram` (data models), `sequenceDiagram` (interaction over time), `stateDiagram` (lifecycles), `gantt` (schedules).

### 2.1 Conventions

- **Colour-code by meaning** via `classDef`: green `fill:#f0fff0,stroke:#090` = good/pass; amber `fill:#fdf6ec,stroke:#d48806` = warning/intentional gap; red `fill:#fff0f0,stroke:#c00` = problem/hot path; blue-teal `fill:#d9eef0,stroke:#4a8c99` = reference/dimension.
- **`<br/>` for multi-line node labels**, `<b>…</b>` to bold inside a node. Quote any label containing `(`, `/`, or punctuation.
- **Put code anchors on edges** where useful: `-->|"read_input() runner.py:508"|`.
- **Group with `subgraph`** to show zones or boundaries.
- Emoji artifact icons are fine where they clarify type: 📄 file · 📁 table · 🛢️ row · 📦 blob · ⚙️ process.

### 2.2 Two Mermaid traps the renderer cannot fix for you

- **Disconnected subgraphs stack vertically in arbitrary order.** A `flowchart LR` with a `BEFORE` and an `AFTER` subgraph and no edge between them will often render `AFTER` above `BEFORE`, silently inverting the story. **Always connect paired subgraphs with an explicit edge** (`BEFORE ==>|"what changed"| AFTER`) and set `direction TB` inside each. The edge forces the order and states the transition.
- **Label size is predicted from diagram complexity**, not from how much room the page has. A large diagram gets a smaller font automatically so it fits on one page. If a diagram must stay readable, keep it small — splitting one dense diagram into two is almost always better than shrinking it.

### 2.3 Make the diagram's shape match the page's shape

A diagram is scaled to fit whichever cap binds first, so a **tall diagram on a landscape slide is
rendered small and its labels become unreadable** — the height cap binds long before the width is
used. This is the single most common reason a deck diagram looks weak.

- **On a slide, prefer `flowchart LR`** and put `direction TB` inside subgraphs to keep each group
  compact while the groups sit side by side. A `flowchart TB` with a wide header row and narrow
  boxes beneath wastes most of the width.
- **A comparison belongs on the horizontal axis.** Before/after, cloud/local, per-task/per-batch:
  two subgraphs side by side with an edge between them.
- **Put the numbers in the diagram**, not only in the prose beneath it — cost per node, duration on
  an edge, counts in a group label. That is what makes a diagram carry more than its topology.

### 2.4 A `gantt` shows proportion that boxes cannot

When the point is *how long* or *what overlaps*, boxes lie: three arrangements of the same work
look identical as flowcharts and completely different as bars. Use elapsed clock time from zero
and let the reader see the collapse.

```
gantt
    dateFormat HH:mm
    axisFormat %H:%M
    todayMarker off
    section Serial 130
    ingest 35 claims   :crit,   s2, after s1, 88m
    section Overlapped 88
    ingest 35 claims   :crit,   o2, 00:00, 88m
```

`dateFormat HH:mm` with `axisFormat %H:%M` reads as elapsed time rather than dates. Mark the
critical path `crit` so the constraint is visible, `done` for work that is off it, and `active`
for the rest. **One chart with several `section`s beats several charts** — and adding a section to
the previous slide's chart is the clearest way to develop an idea across two illustrations.

### 2.5 Draw a loop as a loop, and a choice as a choice

Two shapes carry more than a row of boxes and are routinely missed:

- **A repeating process should close back on itself**, with the return edge *labelled* with what
  triggers the next pass (`-->|"again, seconds later"|`). An unlabelled return arrow reads as a
  stray line; a labelled one states the cadence, which is usually the real point of the diagram.
  Two loops side by side is the clearest way to contrast two cadences.
- **A routing rule should be a decision chain, not two labelled boxes.** If the document is
  explaining how to choose between A and B, draw the questions — `{"does it need X?"}` into
  `{"could it be done without X?"}` — and let each branch land on its destination. The reader
  then leaves with a procedure rather than a taxonomy.

### 2.6 Developing an idea across illustrations

When one diagram builds on another, keep the **same topology and node shapes** and change only what the new slide adds — the reader should see the specialisation happen. Say so in the prose ("the same picture, one level in"). This is far stronger than two unrelated diagrams of the same subject.

## 3. Tables and prose

- **Use tables for enumerable facts**: ledgers, per-item matrices, at-a-glance summaries, glossaries, status indexes. Keep explanation in the surrounding prose, not crammed into cells.
- **Precede a non-obvious table with a sentence on how to read it**, and define any non-obvious column.
- **Mark status inline**: ✅ ⚠️ 🔴 or **bold**. Prefer real values to invented examples, and flag illustrative rows as such.
- **Bold the lead-in of a key claim** so it scans.
- **Distinguish measured from inferred.** Mark inferences (`[projected]`, `[infer]`, "best guess") rather than presenting them as fact.
- **Date every measurement**, or state the method. A figure with neither will be quoted as current long after it stops being true — by a person, and much more readily by an agent that has no way to tell.
- **Anchor claims to sources** (`file.py:line`, `§4.2`).

## 4. Writing for `--present`

A deck is 13.333 × 7.5in landscape. **One slide per `##`.** `###` does not break, so a section longer than a slide simply flows onto the next page — that is the main thing to design against.

### 4.1 The title card and the overview card

The intended opening is **title card, then overview card, then sections**.

- **Title card** — the H1 plus its framing paragraph. Nothing else. Keep the paragraph to two or three lines.
- **Overview card** — generated for you from the `##` headings, under the heading `Overview`, rendered as a numbered two-column agenda.
- **To write your own instead**, add a second-level section whose heading starts with one of: `Overview`, `Agenda`, `Contents`, `In this deck`, `On the agenda`, `What's covered`, `How to read`. The renderer detects it and injects nothing. Anchors are still emitted, so your links work.

That detection is the fallback rule in general: **authored formatting wins, generated formatting fills the gap.**

### 4.2 Fitting a slide

The usable slide box is about 166mm tall after margins. A heading takes roughly 16mm. What is left has to hold everything else.

| Slide shape | Fits comfortably |
|---|---|
| Diagram + interpreting prose | one diagram, two short paragraphs |
| Table | 8-9 rows plus a lead-in and a closing line |
| Prose only | three or four short paragraphs, or ~8 bullets |

- **Diagrams are capped at 76mm high** so the prose beneath them stays on the same slide. A diagram alone will therefore not fill the slide, which is correct — the prose is the point.
- **Overflow is silent.** A slide that is one line too long puts that line on a page of its own. Check the page count against the `##` count: they should differ by exactly one, the title card.
- **Trailing content can overflow the page box by a hair** and push the next forced break a page late, producing a fully blank slide. If you see blanks, the previous slide is marginally too full — cut a line.

### 4.3 Language

Plain and concrete. A deck is read at a glance and often from a distance.

- **Lead with the number.** "92 minutes to under 3" beats "significantly faster".
- **One idea per slide**, named in the heading as a claim rather than a topic: "Skip work whose result is still good", not "Reuse".
- **Abstraction without examples reads as filler.** Every general rule wants a measured instance next to it.

## 5. Compatibility

- **GitHub-flavoured Markdown only.** Mermaid in ` ```mermaid ` fences, other code fenced with a language tag.
- **No raw HTML in the body.** Keep HTML (`<br/>`, `<b>`) inside Mermaid labels, where it renders. The one exception is the `<div class="agenda">` the renderer injects itself.
- **Self-contained** — no reliance on external CSS or JS.
- **Themes compose with the output shape**: `--dark` works with `--present`.
