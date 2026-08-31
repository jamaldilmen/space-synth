#!/usr/bin/env python3
"""Verify every `file:line` citation in the crucial docs against the live tree.

His law, 2026-08-30: a doc comment is not written until it is code-verified.
A citation that no longer points at the code it claims is a FALSE STATEMENT
in the reference of truth, and nothing else in the repo will flag it.

Two checks, because the first one alone gives false confidence:
  1. RANGE  — does the cited line exist at all?
  2. ANCHOR — do the code identifiers the doc names near the citation actually
              appear within +/-WINDOW lines of it?

(2) is the one that matters. After a large deletion every line number below it
still RESOLVES; it just points somewhere else. That is the most dangerous kind
of stale citation. `bhmarch_fragment` (~410 lines, deleted 2026-08-27 00741f2)
silently shifted the whole bottom of render.metal this way.

Usage:  python3 tools/verify_citations.py [--window N] [--quiet]
Exit 1 if any citation fails RANGE. ANCHOR failures are reported, not fatal:
a row may legitimately name a symbol that lives elsewhere.
"""
import glob
import re, os, sys, collections

# Core boards + every design/handoff/library doc that carries file:line claims.
# WIDENED 2026-08-31 16:52:00: the sweep only saw 4 files, so a decayed anchor in
# docs/blackhole-library/ or a DESIGN_* doc was invisible to it — which is exactly
# how the 14th sighting was found by hand instead of by this tool.
DOCS = ["docs/BOARD.md", "docs/BOARD_BLACKHOLE.md", "docs/TODO.md", "docs/STATUS.md"]
# LIVE docs — the fatal gate applies here. A DEAD citation in one of these is a
# claim about code that does not exist, sitting in a doc someone will act on.
# ⛔ DEDUPED 2026-08-31 18:15:00 — "docs/DESIGN*.md" and "docs/DESIGN_BH_*.md" BOTH
# match the DESIGN_BH_* files, so every citation in them was counted twice and the
# LIVE total was inflated. set() before sorting.
DOCS += sorted(set(glob.glob("docs/blackhole-library/*.md")
               + glob.glob("docs/DESIGN*.md")
               + glob.glob("docs/DESIGN_BH_*.md")
               # ⛔ ADDED 2026-08-31 17:20:00. These were NOT swept at all, which is
               # how SCIENCE_2026-08-31_INDEX.md:26 and ADDENDUM_03:90 kept citing
               # `F_BH_CLUSTER` at a live line number after the constant was deleted.
               # The check existed; it simply never ran on these files.
               + glob.glob("docs/SCIENCE_*.md")
               + glob.glob("docs/SWEEP_*.md")) - set(DOCS))

# FROZEN docs — swept and REPORTED, but never fatal. A past handoff legitimately
# cites code that was deleted after it was written (e.g. bhmarch_fragment, ~410
# lines, deleted 2026-08-27 — every render.metal citation past 3119 lands there).
# ⛔ Do NOT "repair" a dead anchor in one of these: rewriting a frozen record to
# point at unrelated live code turns an honest history into a false one. The O0
# rule already says it — if the code is GONE, the row is HISTORY.
DOCS_HISTORY = sorted(glob.glob("docs/HANDOFF_*.md") + glob.glob("docs/PLAN_*.md"))
SKIP_DIRS = {"build", "third_party", ".git", "SpaceSynth.app", "docs", "scratchpad"}
WINDOW = 18

_LINE_COMMENT = re.compile(r"//.*?$|/\*.*?\*/", re.S | re.M)


def strip_comments(text):
    """Code with // and /* */ removed.

    A symbol that survives ONLY in a comment is not live code. Deleting a
    constant nearly always leaves a comment naming it, so without this the
    obituary keeps the citation looking healthy.
    """
    return _LINE_COMMENT.sub("", text)

CITE = re.compile(r'`?([A-Za-z0-9_]+\.(?:metal|mm|cpp|h|hpp))\s*:\s*(\d+)')
TOKEN = re.compile(r'`([A-Za-z_][A-Za-z0-9_]{4,})`')


def build_index(root):
    idx = collections.defaultdict(list)
    for dp, dn, fn in os.walk(root):
        dn[:] = [d for d in dn if d not in SKIP_DIRS]
        for f in fn:
            idx[f].append(os.path.join(dp, f))
    return idx


def main():
    args = sys.argv[1:]
    window = WINDOW
    if "--window" in args:
        window = int(args[args.index("--window") + 1])
    quiet = "--quiet" in args

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)
    idx = build_index(".")
    cache = {}

    def lines(p):
        if p not in cache:
            cache[p] = open(p, errors="replace").read().split("\n")
        return cache[p]

    total = dead = anchor_fail = mismatch = 0
    h_total = h_dead = h_anchor = 0
    for doc in DOCS + DOCS_HISTORY:
        historical = doc in DOCS_HISTORY
        if not os.path.exists(doc):
            print(f"MISSING DOC: {doc}")
            continue
        d_dead, d_anchor, d_tot = [], [], 0
        d_mismatch = []
        for ln, line in enumerate(open(doc, errors="replace"), 1):
            # a citation the doc has already labelled dead is provenance, not a claim
            labelled_dead = "⛔" in line and "dead" in line.lower()
            cites = list(CITE.finditer(line))
            if not cites:
                continue
            toks_at = [(t.group(1), t.start()) for t in TOKEN.finditer(line)
                       if not t.group(1).endswith((".metal", ".mm", ".cpp", ".h"))]
            toks = [t[0] for t in toks_at]
            for m in cites:
                f, n = m.group(1), int(m.group(2))
                d_tot += 1
                cands = idx.get(f)
                if not cands:
                    d_dead.append((ln, f, n, "no such file"))
                    continue
                L = lines(cands[0])
                if n > len(L):
                    if not labelled_dead:
                        d_dead.append((ln, f, n, f"file is {len(L)} lines"))
                    continue
                if toks and not labelled_dead:
                    ctx = "\n".join(L[max(0, n - 1 - window): n - 1 + window])
                    if not any(t in ctx for t in toks):
                        d_anchor.append((ln, f, n, toks[:3]))
                    else:
                        # ── MISMATCH (added 2026-08-31 17:20:00) ─────────────────
                        # ANCHOR passes if ANY token on the doc line resolves. A row
                        # that cites several symbols therefore passes on its weakest
                        # claim. MISMATCH is stricter and narrower: the ONE token
                        # written nearest this citation must itself resolve.
                        # WHY IT IS A DIFFERENT CLASS, not a stricter anchor-miss:
                        #   anchor-miss = "this line MOVED"   (number drifted)
                        #   mismatch    = "this line is about SOMETHING ELSE now"
                        # The second is the dangerous one — it looks verified. It is
                        # what a deletion leaves behind: the number resolves, the
                        # symbol is gone from the whole file, and nothing objects.
                        # ⚠️ NON-FATAL, deliberately. A citation may legitimately point
                        # at a BLOCK rather than a symbol, so false positives are
                        # expected. Report, do not gate.
                        near = min(toks_at, key=lambda ta: abs(ta[1] - m.start()),
                                   default=None)
                        if near and near[0] not in ctx:
                            d_mismatch.append((ln, f, n, near[0], "not near that line"))
                        elif near and near[0] not in strip_comments(ctx):
                            # ⭐ THE CASE THAT ACTUALLY BIT US, 2026-08-31.
                            # `F_BH_CLUSTER` was DELETED from particles.metal, yet a
                            # citation of `particles.metal:277` still "passed" — because
                            # the symbol survives a few lines away inside the RETRACTION
                            # COMMENT that records its death. Present as prose, absent as
                            # code, and a plain string search cannot tell those apart.
                            # A deletion almost always leaves a comment behind explaining
                            # it, so this is the NORMAL shape of a decayed citation, not
                            # an exotic one.
                            # ⚠️ Legitimately noisy: a doc may cite a COMMENT on purpose
                            # (e.g. "the note at render.metal:828 claims..."). Hence its
                            # own sub-class and non-fatal, like the rest of MISMATCH.
                            d_mismatch.append((ln, f, n, near[0], "ONLY inside a comment — not live code"))
        if historical:
            h_total += d_tot; h_dead += len(d_dead); h_anchor += len(d_anchor)
            d_mismatch = []   # frozen docs: a deleted symbol is honest history
        else:
            total += d_tot; dead += len(d_dead); anchor_fail += len(d_anchor)
            mismatch += len(d_mismatch)
        tag = " [FROZEN — reported, never fatal]" if historical else ""
        print(f"=== {doc}: {d_tot} citations | DEAD {len(d_dead)} | anchor-miss {len(d_anchor)}{tag}")
        for x in d_dead:
            print(f"    DEAD  L{x[0]}  {x[1]}:{x[2]}  ({x[3]})")
        for x in d_mismatch:
            print(f"    MISMATCH L{x[0]}  {x[1]}:{x[2]}  names `{x[3]}` — {x[4]}")
        if not quiet:
            for x in d_anchor[:40]:
                print(f"    anchor L{x[0]}  {x[1]}:{x[2]}  names {x[3]} — not within ±{window}")

    print(f"\nLIVE    {total} citations | DEAD {dead} | anchor-miss {anchor_fail} (window ±{window})")
    print(f"        of which MISMATCH {mismatch} — cited symbol is not near the cited line "
          f"(looks verified; is not). Non-fatal: a citation may point at a block.")
    print(f"FROZEN  {h_total} citations | DEAD {h_dead} | anchor-miss {h_anchor}  "
          f"(past handoffs/plans — reported, NEVER fatal)")
    print("DEAD is fatal IN LIVE DOCS ONLY. A frozen handoff may legitimately cite deleted code;")
    print("do NOT repoint it at live code — that turns an honest record into a false one.")
    print("anchor-miss is a strong hint the line number drifted — verify by hand.")
    return 1 if dead else 0


if __name__ == "__main__":
    sys.exit(main())
