---
name: cochrane-style-check
description: >
  Audit a finance/economics .tex file against John H. Cochrane's "Writing Tips for Ph.D. Students"
  (2005). Read-only. Single markdown report under `.claude/cc/cochrane-style-check/`. Only invoked
  via the /skills/cochrane-style-check slash command. Do NOT trigger based on intent inference or
  keywords.
---

# Cochrane Style Check

This skill runs the Cochrane (2005) checklist against a finance/economics manuscript or a
single section file. It produces a markdown report with one finding per violation, grouped by
category. **Read-only**: never edits the manuscript or any other file. The only write is the
report.

Source of truth (read at session start if available):
`C:/Users/dimut/OneDrive/github/paper-repo/mds/phd_paper_writing.md`

**Project overrides applied** (these Cochrane rules are NOT enforced here, by user instruction):
- Intro length cap of 3 pages — overridden; project standard is 4–6 pages.
- "Every number in a table must be discussed in the text" — not enforced.

---

## Inputs

- **`$ARGUMENTS`**: `<track-name>` (required) — the track folder name under `tracks/`, e.g. `did-april2026`. The skill resolves the default file to `tracks/<track-name>/latex/main.tex`. The user may instead pass an explicit `.tex` path (e.g. `tracks/<track>/latex/sections/intro/intro_current.tex`) to override the default.
- **Authorship** (auto-detected): read `**Authorship**:` field in the project `CLAUDE.md`.
  - `solo` → enforce Cochrane voice rule: first-person singular ("I"); flag royal "we".
  - `coauthored` (default) → first-person plural ("we"); do not flag.

If the .tex `\input{}`s other files, recurse into them. Locate file/line for every finding.

Output path: `.claude/cc/cochrane-style-check/<YYYYMMDD>_<track>_<filename-stem>.md`.
Create the folder if it does not exist.

---

## Categories and checks

Each finding records: file:line, category, severity (High/Med/Low), the offending excerpt, the
Cochrane principle violated, and the suggested fix.

### A. Macro-structure (read-and-judge)

These require reading the relevant section, not just grepping.

| # | Check | Severity |
|---|---|---|
| A1 | **Central contribution** stated in one paragraph in the abstract or first two paragraphs of intro? Concrete, not "we examine the relationship between..." | High |
| A2 | **Abstract** ≤ 150 words, no literature citations, says what the paper finds (not "data are analyzed") | High |
| A3 | **Intro opens with the contribution**, not philosophy, not "the literature has long…", not "[Topic] is a fundamental question…", not policy-importance preamble, not a quotation | High |
| A4 | **Literature review** is a separate (or set-off) section, focused on 2–3 closest papers, and does not block the contribution | Med |
| A5 | **"Nothing before the main result that a reader doesn't need to know to understand it"** — flag warmup exercises, dataset travelogues, replications of others' work, or descriptive stats placed before the main result | High |
| A6 | **Theory** (if present) is the minimum needed for the empirical work, not a general model that gets specialized | Med |
| A7 | **Conclusion** is short, restates nothing already in the abstract/intro/body, contains no "future research" punch list | Med |

### B. Writing micro-rules (mostly grep-able)

| # | Pattern (regex / phrase) | Cochrane principle | Severity |
|---|---|---|---|
| B1 | `\bin other words\b` | "If you said it once, don't say it again." | Med |
| B2 | `\bit (should|must) be noted that\b` | Just say it. | Med |
| B3 | `\bit is (easy|straightforward|trivial) to show that\b` | Means it isn't. | Low |
| B4 | `\b(very|highly) (significant|novel|important|interesting|striking|robust)\b` | No double adjectives, no adjectives on own work. | Med |
| B5 | `\b(striking|remarkable|fascinating|surprising) (results?|findings?|evidence)\b` | World gives adjectives, not author. | Med |
| B6 | Sentence-initial `Interestingly,` / `Notably,` / `Importantly,` / `Surprisingly,` | Significance announcements. | Med |
| B7 | `\b(utilize|utilization)\b` | Use "use". | Low |
| B8 | `\b(diverse|various|several|numerous)\b` standing for "many/varied" without specificity | Concrete > abstract. | Low |
| B9 | `\bAs we will see in (Table|Figure|Section) \d` / `\bRecall (from|that) Section` / `\bas (previously|already) (discussed|noted)\b` | Previews/recalls = bad organization. | Med |
| B10 | `\bI leave (this|.+) (for|to) future research\b` / `\b(opens|leaves) (several |many )?(avenues|directions) for future (work|research)\b` | "We're less interested in your plans than your memoirs." | Med |
| B11 | `\billustrative (empirical (work|results?)|test)\b` | Never do illustrative work. | High |
| B12 | `\bmodels? where\b` (when describing a model, not a place) | Use "in which" for models. | Low |
| B13 | Author-name abbreviations like `\b[A-Z]{2,4} (show|find|argue|document)s?\b` standing for an author pair (e.g. "FF show", "DKS find") | Spell out names. | Low |
| B14 | Naked `this` — `\bThis (shows|implies|suggests|means|illustrates|demonstrates)\b` at sentence start with no following noun | Clothe naked "this". | Med |
| B15 | `\bIt is assumed that\b` / `\bdata (were|are) (constructed|collected) as follows\b` / `\b(\w+) (is|are) (estimated|computed|specified|calculated)\b` clusters in same paragraph | Active voice; passive search-for-is/are. | Med |
| B16 | `\b(We|I) assume (that )?(consumers|agents|firms|investors|households)\b` followed by a structural model statement | Don't "assume" model structure; just state. | Low |
| B17 | Sign-of-effect parens: `\bgoes (up|down) \((down|up)\)\b` or `\bincreases? \(decreases?\)\b` | One direction, not (down) parens. | Low |
| B18 | Cute opening quotation immediately under `\section{Introduction}` or before first sentence (look for `\epigraph`, `\begin{quote}`, or `\textit{"..."}` at very top) | Don't open with a quote. | Med |
| B19 | Compound modifier hyphenation per JFE rule: `\b(after tax|risk free|two day|value weighted) (income|rate|return|index)\b` (should be hyphenated) and adverb-`ly` exceptions `\b(equally-weighted|publicly-traded)\b` (should NOT be hyphenated) | JFE hyphen rule. | Low |
| B20 | Greek letters (`\\alpha`, `\\beta`, `\\theta`, etc.) used in prose without a definition in the same or prior paragraph (heuristic: first use in the file/section without a nearby `=`, `\equiv`, "where" clause, or named gloss) | Define Greeks in an easy-to-find place. | Low |
| B21 | Sentence-initial `It is (clear|obvious|evident) that\b` / `\bThere (is|are) .+ that\b` followed by claim — kill everything before "that" | "Everything before 'that' should be deleted." | Med |
| B22 | Voice rule (authorship-conditional): if `Authorship: solo` → flag `\b(W|w)e (find|show|argue|document|estimate|propose)\b` and recommend "I". If `coauthored` (default) → flag `\bI (find|show|argue|document|estimate|propose)\b` and recommend "we". | Cochrane §2 voice rule, project-conditioned. | Med |
| B23 | Paper length > 40 pages (heuristic: count `\section{}` blocks plus tables/figures, or rely on a `\thepage` if obvious) | "Final papers should be no more than 40 pages." | Low |

### C. Tables and figures

| # | Check | Severity |
|---|---|---|
| C1 | **Self-contained captions** — every `\begin{table}`/`\begin{figure}` has a caption that names the dependent variable (or what is plotted), the sample, and (for regression tables) the regression equation or a reference to it | Med |
| C2 | **Significant digits** — scan tabular bodies for cells with > 3 significant digits in coefficients (e.g. `4.56783`) and flag for reduction to 2–3 sig figs | Med |
| C3 | **Sensible units** — flag any cell with absolute value < 0.001 or > 10,000 in a regression-coefficient row (likely needs unit rescaling: percentages, basis points, thousands, etc.) | Low |
| C4 | **Figures**: `\includegraphics` without an axis label / units / line-type definition in the caption | Low |
| C5 | **Footnotes**: scan `\footnote{}` content; if the footnote is a parenthetical aside (single short sentence with no citation, formula, or concrete documentation), flag — Cochrane: footnotes only for skip-able material | Low |
| C6 | **Italics overuse**: count `\textit{}` and `\emph{}` per page; > 5 per page flag as overuse | Low |

### D. Empirical (read-and-judge for the identification/methods/results sections)

| # | Check | Severity |
|---|---|---|
| D1 | Identification strategy described in plain English, with the source of variation named | High |
| D2 | What economic mechanism causes dispersion in the RHS variable is stated | Med |
| D3 | What is in the error term, and why it is uncorrelated with the RHS, is stated | Med |
| D4 | Source of variation is described **per number** (esp. with FE: "with firm FE the coefficient is identified by within-firm variation over time") | Med |
| D5 | Reverse-causality story addressed (or explicitly ruled out by design) | Med |
| D6 | Demand-vs-supply distinction made when the regression mixes two equilibrium objects | Med |
| D7 | Controls discipline: no "left-shoes on right-shoes" regressors; high R² flagged | Med |
| D8 | Stylized facts shown (graphs/tables) that drive the main result — not just point estimates and p-values | Med |
| D9 | Economic significance reported alongside statistical significance | Med |
| D10 | Standard error attached to every important number | Med |

---

## Workflow

1. **Locate authorship**: Read `CLAUDE.md` from project root. Find `**Authorship**:` line. Treat
   `solo` and `coauthored` as the only valid values; anything else → default `coauthored`.

2. **Read the target file** plus any `\input{}`/`\include{}` it pulls in.

3. **Run grep-able checks** (B-series and C2/C3/C6) across all loaded text. Skip math
   environments, `\verb`, `\cite{}`, `\ref{}`, `\label{}`, code listings, and the tabular bodies
   themselves except where the check explicitly inspects them.

4. **Read-and-judge checks** (A-series and D-series): read each major section, then write one
   finding per failed check. If a section is absent from the supplied file (e.g. only intro was
   passed), mark the relevant checks as `N/A — section not in file`.

5. **Write the report** to `.claude/cc/cochrane-style-check/<YYYYMMDD>_<track>_<stem>.md`.

---

## Report format

```
# Cochrane Style Check — <filename>
**Date**: YYYY-MM-DD
**Authorship mode**: solo / coauthored
**File(s) audited**: <list>
**Total findings**: H=N, M=N, L=N

---

## A. Macro-structure
| # | Check | Verdict | File:Line | Excerpt | Fix |
|---|---|---|---|---|---|
| A1 | Central contribution in one paragraph | Pass / Fail / N/A | … | … | … |
| … |

## B. Writing micro-rules
| # | Pattern | File:Line | Excerpt | Fix |
|---|---|---|---|---|
| B1 | "in other words" | sections/results.tex:142 | "...in other words, the effect…" | Delete; restate the prior sentence cleanly. |
| … |

## C. Tables and figures
| # | Check | Table/Figure | Issue | Fix |
|---|---|---|---|---|
| C2 | Sig digits | Table 3, col (2), row 4 | "4.56783" with SE 0.6789 | "4.6 (0.7)" |
| … |

## D. Empirical
| # | Check | Verdict | File:Line | Notes | Fix |
|---|---|---|---|---|---|
| D1 | Identification stated plainly | Pass / Fail / N/A | … | … | … |
| … |

---

## Priority Action Items
**HIGH** (likely to draw a referee comment or undermine the paper):
1. …

**MEDIUM** (polish the prose toward Cochrane standard):
2. …

**LOW** (cosmetic):
3. …
```

---

## Boundaries

- **Read-only**. Never modify the .tex file, the bib file, code, or anything else. The only
  write is the report.
- **No autorewrite**. Do not produce corrected paragraphs unless the user asks; this skill
  surfaces violations and proposes minimal fixes per finding.
- **Never trigger automatically**. Only via `/skills/cochrane-style-check`.
- **Do not duplicate other audits**: this skill enforces Cochrane (2005) specifically. Style
  issues like AI tells live in `agents/ai-writing-audit`; cross-reference checks live in
  `skills/figure-table-crosscheck` and `skills/latex-preflight-check`. Where overlap exists
  (e.g. "interestingly," "utilize"), Cochrane attribution is the distinguishing feature.

## Reference

John H. Cochrane (2005), "Writing Tips for Ph.D. Students,"
University of Chicago GSB. Local copy:
`C:/Users/dimut/OneDrive/github/paper-repo/mds/phd_paper_writing.md`.
