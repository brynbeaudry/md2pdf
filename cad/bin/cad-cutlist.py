#!/usr/bin/env python3
"""cad-cutlist.py — parse captured OpenSCAD echoes into a cut list + metadata.

Reads a capture.txt full of lines like:
    ECHO: "CUTLIST|lumber|2x4|84|3.5|1.5|wall stud"
    ECHO: "META|title|Outhouse"
    ECHO: "NOTE|Use pressure-treated lumber for the floor frame."
    ECHO: "DIM|Footprint|48 x 48 in"

Writes into the output dir:
    cutlist.md    grouped, human-readable cut list (embedded into the PDF)
    cutlist.json  structured cut list + totals
    meta.json     title / subtitle / units / material / notes / dims

Records are emitted by lib/lumber.scad, so the cut list always matches the
geometry that was rendered.
"""
import json
import re
import sys
from collections import OrderedDict
from fractions import Fraction
from math import ceil

ECHO_RE = re.compile(r'^ECHO:\s*"(.*)"\s*$')

# Placeholder retail unit prices (edit per project with plan_price()). Lumber is
# $/linear foot; plywood is $/4x8 sheet. Rough — tune to your region/supplier.
DEFAULT_PRICES = {
    "currency": "$", "waste_pct": "10",
    "1x2": "0.40", "1x3": "0.55", "1x4": "0.70", "1x6": "1.10", "1x8": "1.60",
    "2x2": "0.55", "2x3": "0.70", "2x4": "0.80", "2x6": "1.30", "2x8": "1.90",
    "2x10": "2.60", "4x4": "2.40", "6x6": "5.50",
    "0.25in ply": "28", "0.5in ply": "45", "0.75in ply": "68",
}

# Member-type colour key — MIRRORS ROLE_COLORS in lib/lumber.scad (same order).
ROLE_MAP = [
    ("deck board", "Decking (2x6)", "#caa978"),
    ("tread", "Decking (2x6)", "#caa978"),
    ("sheathing", "Plywood (deck/roof)", "#c9b48a"),
    ("panel", "Plywood (deck/roof)", "#c9b48a"),
    ("deck", "Plywood (deck/roof)", "#c9b48a"),
    ("ridge", "Roof framing", "#6b8e9e"),
    ("rafter", "Roof framing", "#6b8e9e"),
    ("joist", "Floor/porch framing", "#8f9b5a"),
    ("rim", "Floor/porch framing", "#8f9b5a"),
    ("header", "Headers", "#a85f2b"),
    ("sill", "Plates & sills", "#b07a3f"),
    ("plate", "Plates & sills", "#b07a3f"),
    ("seat", "Bench seat", "#9c6b42"),
    ("trim", "Door trim", "#7e8b5a"),
    ("king", "Studs", "#c8a165"),
    ("jack", "Studs", "#c8a165"),
    ("cripple", "Studs", "#c8a165"),
    ("stud", "Studs", "#c8a165"),
]


def role_of(tag):
    for kw, label, color in ROLE_MAP:
        if kw in tag:
            return label, color
    return None


def build_legend(cut):
    present = {role_of(c["tag"]) for c in cut if role_of(c["tag"])}
    out, seen = [], set()
    for _, label, color in ROLE_MAP:
        if (label, color) in present and label not in seen:
            seen.add(label)
            out.append({"label": label, "color": color})
    return out


def parse(capture_path):
    cut, meta, notes, dims, steps, warnings = [], OrderedDict(), [], [], [], []
    stage_titles, bounds, prices = [], None, {}
    with open(capture_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = ECHO_RE.match(line.strip())
            if not m:
                continue
            parts = m.group(1).split("|")
            kind = parts[0]
            if kind == "CUTLIST":
                # category, material, length, width, thickness, tag, [stage]
                _, cat, material, length, width, thick, *rest = parts
                tag = rest[0] if rest else ""
                stage = rest[1] if len(rest) > 1 else ""
                cut.append({
                    "category": cat, "material": material,
                    "length": float(length), "width": float(width),
                    "thickness": float(thick), "tag": tag, "stage": stage,
                })
            elif kind == "META" and len(parts) >= 3:
                meta[parts[1]] = parts[2]
            elif kind == "NOTE" and len(parts) >= 2:
                notes.append(parts[1])
            elif kind == "DIM" and len(parts) >= 3:
                dims.append([parts[1], parts[2]])
            elif kind == "STEP" and len(parts) >= 2:
                steps.append(parts[1])
            elif kind == "STAGEMETA" and len(parts) >= 3:
                stage_titles.append((parts[1], parts[2]))
            elif kind == "BOUNDS" and len(parts) >= 5:
                bounds = [float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4])]
            elif kind == "PRICE" and len(parts) >= 3:
                prices[parts[1]] = parts[2]
            elif kind == "WARNING" and len(parts) >= 2:
                warnings.append(parts[1])
    return cut, meta, notes, dims, steps, stage_titles, bounds, prices, warnings


def frac_in(x):
    """Format inches to the nearest 1/16, e.g. 89.25 -> '89 1/4\"'."""
    whole = int(x)
    frac = Fraction(round((x - whole) * 16), 16)
    if frac == 0:
        return f'{whole}"'
    if frac == 1:
        return f'{whole + 1}"'
    return f'{whole} {frac.numerator}/{frac.denominator}"' if whole else f'{frac.numerator}/{frac.denominator}"'


def feet_in(x):
    """Format inches as feet-inches, e.g. 84 -> "7'-0\"", 89.25 -> "7'-5 1/4\""."""
    ft = int(x // 12)
    rem = x - ft * 12
    return f"{ft}'-{frac_in(rem)}"


def length_cell(x):
    return f"{frac_in(x)} ({feet_in(x)})"


def group(items, keys):
    """Group dicts by the given key tuple, counting qty; preserve first-seen order."""
    out = OrderedDict()
    for it in items:
        k = tuple(it[key] for key in keys)
        if k not in out:
            out[k] = dict(it, qty=0)
        out[k]["qty"] += 1
    return list(out.values())


def build_cutlist(cut):
    lumber = [c for c in cut if c["category"] == "lumber"]
    sheets = [c for c in cut if c["category"] == "sheet"]

    # group identical (material, length, tag) lumber pieces; longest first
    lum_rows = group(lumber, ["material", "length", "tag"])
    lum_rows.sort(key=lambda r: (r["material"], -r["length"]))

    sheet_rows = group(sheets, ["material", "width", "thickness", "tag"])
    sheet_rows.sort(key=lambda r: (r["thickness"], -(r["width"])))

    # totals
    lum_tot = OrderedDict()
    for r in lum_rows:
        t = lum_tot.setdefault(r["material"], {"pieces": 0, "lin_in": 0.0})
        t["pieces"] += r["qty"]
        t["lin_in"] += r["qty"] * r["length"]

    sheet_tot = OrderedDict()
    for r in sheet_rows:
        t = sheet_tot.setdefault(r["material"], {"pieces": 0, "area_sqin": 0.0})
        t["pieces"] += r["qty"]
        # width here is the panel "width"; we stored width & length on the piece
        t["area_sqin"] += r["qty"] * r["width"] * r.get("length", 0.0)

    return lum_rows, sheet_rows, lum_tot, sheet_tot


def cutlist_md(lum_rows, sheet_rows, lum_tot, sheet_tot, warnings=None, totals=True, empty=None):
    L = []
    if lum_rows:
        L += ["### Lumber\n",
              "| Qty | Size | Length | Used for |",
              "|----:|:-----|:-------|:---------|"]
        for r in lum_rows:
            L.append(f"| {r['qty']} | {r['material']} | {length_cell(r['length'])} | {r['tag'] or '—'} |")
        L.append("")
        if totals:
            L += ["**Lumber totals (linear feet, before waste)**\n",
                  "| Size | Pieces | Linear ft |",
                  "|:-----|-------:|----------:|"]
            for mat, t in lum_tot.items():
                L.append(f"| {mat} | {t['pieces']} | {t['lin_in']/12:.1f} |")
            L.append("")

    if sheet_rows:
        L += ["### Sheet goods\n",
              "| Qty | Material | Panel size (W × H) | Used for |",
              "|----:|:---------|:-------------------|:---------|"]
        for r in sheet_rows:
            size = f"{frac_in(r['width'])} × {frac_in(r.get('length', 0))}"
            L.append(f"| {r['qty']} | {r['material']} | {size} | {r['tag'] or '—'} |")
        L.append("")
        if totals:
            L += ["**Sheet totals (4×8 ft = 32 ft² panels)**\n",
                  "| Material | Pieces | Area ft² | 4×8 sheets (approx) |",
                  "|:---------|-------:|---------:|--------------------:|"]
            for mat, t in sheet_tot.items():
                sqft = t["area_sqin"] / 144.0
                L.append(f"| {mat} | {t['pieces']} | {sqft:.1f} | {ceil(sqft/32) if sqft else 0} |")
            L.append("")

    if warnings:
        L.append("> ⚠ " + "; ".join(sorted(set(warnings))))
        L.append("")

    if not lum_rows and not sheet_rows:
        L.append(empty or "_No cut-list pieces were emitted. Did the model `use <.../lumber.scad>` "
                 "and build with board()/sheet()?_")

    return "\n".join(L) + "\n"


def cost_md(lum_tot, sheet_tot, prices):
    """Rough material-cost estimate: lumber by $/linear ft, plywood by $/sheet."""
    cur = prices.get("currency", "$")
    try:
        waste = float(prices.get("waste_pct", 10))
    except ValueError:
        waste = 10.0

    def money(x):
        return f"{cur}{x:,.2f}"

    L = ["### Estimated material cost\n",
         f"_Rough estimate from the unit prices below — **edit with `plan_price()`**. "
         f"Placeholder retail {cur}, before tax. Excludes fasteners, roofing, hardware "
         f"and finishes._\n",
         "| Material | Qty | Unit price | Cost |",
         "|:---------|----:|-----------:|-----:|"]
    lumber_cost = sheet_cost = 0.0
    missing = []
    for mat, t in lum_tot.items():
        ft = t["lin_in"] / 12.0
        p = prices.get(mat)
        if p is None:
            missing.append(mat)
            L.append(f"| {mat} | {ft:.0f} ft | — | _n/a_ |")
            continue
        c = ft * float(p); lumber_cost += c
        L.append(f"| {mat} | {ft:.0f} ft | {cur}{float(p):.2f}/ft | {money(c)} |")
    for mat, t in sheet_tot.items():
        sqft = t["area_sqin"] / 144.0
        sheets = ceil(sqft / 32) if sqft else 0
        p = prices.get(mat)
        if p is None:
            missing.append(mat)
            L.append(f"| {mat} | {sheets} sheet | — | _n/a_ |")
            continue
        c = sheets * float(p); sheet_cost += c
        L.append(f"| {mat} | {sheets} × 4×8 | {cur}{float(p):.2f}/sheet | {money(c)} |")

    sub = lumber_cost + sheet_cost
    wc = sub * waste / 100.0
    L += [f"| **Subtotal** | | | **{money(sub)}** |",
          f"| Waste / contingency | | {waste:.0f}% | {money(wc)} |",
          f"| **Estimated total** | | | **{money(sub + wc)}** |", ""]
    if missing:
        L.append(f"> ⚠ No price set for: {', '.join(sorted(set(missing)))} — "
                 f'add `plan_price("<material>", <unit price>)`.')
        L.append("")
    return "\n".join(L) + "\n"


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: cad-cutlist.py <capture.txt> <out-dir>")
    capture, out = sys.argv[1], sys.argv[2].rstrip("/")
    cut, meta, notes, dims, steps, stage_titles, bounds, prices, warnings = parse(capture)
    lum_rows, sheet_rows, lum_tot, sheet_tot = build_cutlist(cut)

    merged_prices = {**DEFAULT_PRICES, **prices}
    full_md = cutlist_md(lum_rows, sheet_rows, lum_tot, sheet_tot, warnings, totals=True)
    if lum_rows or sheet_rows:
        full_md += "\n" + cost_md(lum_tot, sheet_tot, merged_prices)
    open(f"{out}/cutlist.md", "w", encoding="utf-8").write(full_md)
    json.dump({"lumber": lum_rows, "sheets": sheet_rows,
               "lumber_totals": lum_tot, "sheet_totals": sheet_tot},
              open(f"{out}/cutlist.json", "w"), indent=2)

    # per-stage "build instructions": each stage's title + the parts it consumes
    stages = []
    for n, title in stage_titles:
        items = [c for c in cut if c["stage"] == n]
        lr, sr, lt, st = build_cutlist(items)
        stages.append({
            "n": int(n) if n.isdigit() else n,
            "title": title,
            "parts_md": cutlist_md(lr, sr, lt, st, totals=False,
                                   empty="_(no new cut pieces this step)_"),
        })

    json.dump({"title": meta.get("title", "Untitled"),
               "subtitle": meta.get("subtitle", ""),
               "units": meta.get("units", "inches"),
               "material": meta.get("material", ""),
               "notes": notes, "dims": dims, "steps": steps,
               "stages": stages, "bounds": bounds, "legend": build_legend(cut)},
              open(f"{out}/meta.json", "w"), indent=2)

    n_pieces = sum(r["qty"] for r in lum_rows) + sum(r["qty"] for r in sheet_rows)
    print(f"  ⎿ cut list: {n_pieces} pieces "
          f"({len(lum_rows)} lumber rows, {len(sheet_rows)} sheet rows)"
          + (f", {len(stages)} build stages" if stages else "")
          + (f"  ⚠ {len(warnings)} warning(s)" if warnings else ""))


if __name__ == "__main__":
    main()
