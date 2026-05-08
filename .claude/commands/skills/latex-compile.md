---
description: Compiles a .tex file to PDF. First tries latexmk; falls back to a smart pdflatex + bibtex/biber sequence if latexmk fails.
---

# Agent: LaTeX Compiler

## Role

You compile a single LaTeX (.tex) file to PDF. First try `latexmk` (fast path); if it fails or is unavailable, fall back to a direct `pdflatex` sequence with smart pass management. Follow the steps below exactly.

## Input

- **`$ARGUMENTS`**: interpreted in this priority order:
  1. If it is a literal path to a `.tex` file (contains `.tex` or path separators), use it directly as an override.
  2. Otherwise treat it as a **track name** (e.g. `did-april2026`) and resolve to `tracks/<track>/latex/main.tex`.
- If `$ARGUMENTS` is empty, fall back to the file the user attached via `@` (e.g. `@paper_Jan2026.tex`).
- If neither `$ARGUMENTS` nor a `@` attachment is provided, **error out** and ask the user to provide a track name (e.g. `did-april2026`) or a `.tex` path.

## Path resolution

From the chosen .tex path, derive:

1. **`<tex_dir>`** — absolute directory containing the .tex file (e.g. `C:\OneDrive\github\depositor-discipline\tracks\did-april2026\latex`).
2. **`<stem>`** — filename without extension (e.g. `main`).
3. **`<build_dir>`** — `<tex_dir>\build` (output directory for all generated files).

## Step 0 — Try latexmk (fast path)

Run latexmk first. It handles all passes (bibliography, cross-references) automatically.

```bash
cd <tex_dir> && mkdir -p build && latexmk -pdf -recorder -silent -output-directory=build -interaction=nonstopmode -view=none <stem>.tex
```

- If this **succeeds** (exit code 0 and `build/<stem>.pdf` exists): report the page count (if printed), the PDF path, and **stop** — skip all remaining steps.
- If this **fails** (exit code non-zero, latexmk not found, or PDF not produced): note the failure briefly and continue to the pdflatex fallback below.

## Step 1 — Detect bibliography backend

Before running any commands, read the first ~100 lines of `<stem>.tex` (or grep it) to check:

- If `\usepackage{biblatex}` is present → backend is **biber**.
- Else if `\bibliography{` or `\addbibresource{` is present → backend is **bibtex**.
- Else → **no bibliography**, skip all bibliography steps.

## Step 2 — Pass 1: initial pdflatex

Run in a **single shell invocation**:

```bash
cd <tex_dir> && mkdir -p build && pdflatex -interaction=nonstopmode -output-directory=build <stem>.tex
```

This writes all auxiliary files (`.aux`, `.log`, `.bbl`, `.bcf`, etc.) into `build/`.

## Step 3 — Bibliography pass (conditional)

**Only run this step if a bibliography backend was detected in Step 1.**

After pass 1, confirm the bibliography is actually needed:
- For **bibtex**: check that `build/<stem>.aux` contains a `\bibdata` line.
- For **biber**: check that `build/<stem>.bcf` exists.

If confirmed, run the appropriate command from `<tex_dir>`:

```bash
# bibtex:
cd <tex_dir> && bibtex build/<stem>

# biber:
cd <tex_dir> && biber build/<stem>
```

Then run **pass 2** to incorporate the bibliography:

```bash
cd <tex_dir> && pdflatex -interaction=nonstopmode -output-directory=build <stem>.tex
```

## Step 4 — Pass 3: cross-reference rerun (conditional)

After the most recent pdflatex pass, scan its stdout for any of these strings:
- `Rerun to get cross-references right`
- `Rerun to get outlines right`
- `There were undefined references`
- `Label(s) may have changed`

If **any** of these appear, run one more pass:

```bash
cd <tex_dir> && pdflatex -interaction=nonstopmode -output-directory=build <stem>.tex
```

If none appear, **skip this pass** — the PDF is already consistent.

## Step 5 — Error reporting

After the final pass:

1. **Page count**: scan stdout for `Output written on ... (N pages)` and report it.
2. **Exit code**: report the exit code of the final command.
3. **PDF path**: `<build_dir>/<stem>.pdf`
4. **Errors**: if exit code is non-zero or the PDF was not produced, read `<build_dir>/<stem>.log` and extract every line that starts with `!` (these are LaTeX fatal errors). Summarise them briefly.
5. **Warnings**: optionally note any `LaTeX Warning:` lines about undefined references or overfull boxes, but keep this brief.

## Flags reference

| Flag | Purpose |
|------|---------|
| `-pdf` | Produce PDF output |
| `-recorder` | Record file dependencies |
| `-silent` | Suppress most informational output |
| `-output-directory=build` | Write all generated files to `build/` — keeps source directory clean |
| `-interaction=nonstopmode` | Continue past non-fatal errors without stopping for input |
| `-view=none` | Do not open a PDF viewer after compilation |

Do **not** use `-halt-on-error` — it would abort on missing figures and prevent PDF production.
