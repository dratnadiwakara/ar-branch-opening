# Skill: Result Snapshot

## Trigger
This skill is **only** activated when the user explicitly invokes it with the `/skills/snapshot-results` command. Do NOT apply this skill based on context or intent inference.

**Valid triggers**: `/skills/snapshot-results did-april2026 baseline`, `/skills/snapshot-results iv-april2026 robustness-v1`
**Not a trigger**: "snapshot my results", "save current figures", "export results to docs".

## Purpose
Capture the current state of `tracks/<track>/latex/tables/` and `tracks/<track>/latex/figures/` into a versioned snapshot under `docs/snapshots/`. Generates a markdown report for GitHub Pages sharing with coauthors. Updates the snapshot registry in `docs/index.md`.

## Inputs
- **`$ARGUMENTS`**: `<track-name> [<label>]` (two space-separated args). `<track-name>` (required) is the track folder name under `tracks/` (e.g. `did-april2026`). `<label>` (optional) is a short descriptive slug for this snapshot (e.g., `baseline`, `with-controls`). If `<label>` is empty, use `snapshot`.

---

## Execution Steps

### Step 1 — Resolve names and paths

Determine today's date in `YYYYMMDD` format using Bash: `date +%Y%m%d`.

Parse `$ARGUMENTS` as two space-separated tokens: `TRACK` and `LABEL`. Strip surrounding quotes/whitespace from each.
- If `TRACK` is blank, error out and ask the user to supply a track name.
- If `LABEL` is blank, use `snapshot`.

Set:
- `TRACK` = first token of `$ARGUMENTS` (e.g. `did-april2026`).
- `LABEL` = second token of `$ARGUMENTS` (or `snapshot` if absent).
- `SNAPSHOT_DIR` = `docs/snapshots/YYYYMMDD-TRACK-LABEL` (relative to project root)
- `SNAPSHOT_DATE` = human-readable date, e.g. `2026-04-09`

### Step 2 — Create snapshot directory structure

Create the following directories (use `mkdir -p`):
- `SNAPSHOT_DIR/figures/`
- `SNAPSHOT_DIR/tables/`

### Step 3 — Copy figures

List all files in `tracks/<TRACK>/latex/figures/` matching `*.png` and `*.pdf`. For each file:
- Copy it to `SNAPSHOT_DIR/figures/` preserving the filename.
- Use Bash `cp` for each file.

If `tracks/<TRACK>/latex/figures/` is empty or does not exist, note this in the report and skip.

### Step 4 — Convert tables

List all `.tex` files in `tracks/<TRACK>/latex/tables/`. For each file (call it `[name].tex`):

1. Read the file contents.
2. Attempt to extract the tabular body:
   - Find `\begin{tabular}` ... `\end{tabular}` (or `tabularx`, `longtable`).
   - Parse rows separated by `\\`, columns separated by `&`.
   - Strip LaTeX formatting commands (e.g., `\textbf{}`, `\multicolumn{}{}{}`, `\hline`, `\cmidrule`, etc.) to get plain text values.
   - Significance stars: render as `***` = 1%, `**` = 5%, `*` = 10% and add a note line below the table: `*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*`
   - Render as a GFM markdown table.
3. If the table is too complex to parse cleanly (multicolumn spanning, nested environments, `\multirow`, panel headers), wrap the entire file content in a ```` ```latex ```` code block instead. Still append the significance note below the code block if the table contains regression output.
4. Write the result to `SNAPSHOT_DIR/tables/[name].md` with a header:
   ```markdown
   # Table: [name]
   *Source: `tracks/<TRACK>/latex/tables/[name].tex`*
   
   [GFM table OR latex code block]
   ```

If `tracks/<TRACK>/latex/tables/` is empty or does not exist, note this in the report and skip.

### Step 5 — Read project name

Read `CLAUDE.md` from the project root. Extract the value of the `**Paper**:` field (first line after the frontmatter block). Use this as `PROJECT_NAME`. If not found, use `[PAPER_TITLE]`.

### Step 6 — Write snapshot index

Write `SNAPSHOT_DIR/index.md` following the formatting rules below exactly. Use any existing `index.md` in `docs/snapshots/` as ground truth for formatting.

#### Frontmatter & header

```markdown
---
layout: default
title: "[TRACK / LABEL] — SNAPSHOT_DATE"
---

# Snapshot: TRACK / LABEL
```

Do **not** repeat the date or project name in the body.

#### Summary block

Open with a blockquote (`>`). One paragraph. Cover: what's significant, what's null, key contrasts across periods/specs.

```markdown
> Summary paragraph here...
```

#### Section structure (tables and figures interleaved)

Number each section. Put variable definitions **directly above** each table or figure — not in a single block at the top.

**For each table section:**

```markdown
## N. Title — Unit

**Unit:** ...
**LHS:** `formula` — plain-English description of window/denominator
**Treatment:** `var` = definition
**Incumbent:** definition
**FE:** ... | **SE:** ...
**Controls:** list
*Note: any caveats or warnings*

```
| col1 | col2 | col3 |
|------|------|------|
| 0.0951***  | 0.0060 | ... |
| (0.0114) | (0.0082) | ... |
| N | 1234 | 1234 | ... |
| Zip FE | Yes | Yes | ... |
| County×Year FE | Yes | Yes | ... |
| SE | Zip | Zip | ... |
| Mean(DV) | 0.042 | 0.038 | ... |
| SD(treatment) | 0.183 | 0.191 | ... |
| Adj. R² | 0.15 | 0.11 | ... |
| Within R² | 0.12 | 0.08 | ... |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---
```

- Coefficients: plain text with stars only (`0.0951***`). Do not bold — stars already signal significance.
- SE row: separate row with `(se)` directly below coefficient row; first cell blank — no "se" label.
- Footer rows order: **N → FE indicators → SE clustering → Mean(DV) → SD(treatment) → Adj. R² → Within R²**
- **FE indicators**: one row per fixed effect (e.g., `Zip FE`, `County×Year FE`) with `Yes`/`No` per column. For R: extract from etable .tex output — do NOT strip these rows during parsing. For Python: derive from spec in header block and add manually.
- **SE clustering**: one row labeled `SE` with clustering level per column (e.g., `Zip`, `Bank`). For R: extract from etable vcov field. For Python: add manually from spec.
- **Adj. R²**: full (not within) adjusted R² — `r2(model, "ar2")` in fixest. Row label: `Adj. R²`.
- **Within R²**: keep as second R² row. Row label: `Within R²`.
- `Mean(DV)`: mean of dependent variable in that regression's sample (after all filters/dropna), rounded to 3 dp. Use actual variable name if cleaner: `Mean(gr_branch)`.
- `SD(treatment)`: SD of the key treatment variable (not controls) in same sample, rounded to 3 dp. Use actual variable name if cleaner: `SD(share_deps_closed)`.
- Compute from the exact `data=` subset passed to `feols()`:
  - R: `mean_dv <- mean(data$dep_var, na.rm = TRUE)` / `sd_treat <- sd(data$treatment_var, na.rm = TRUE)`
  - Python: `mean_dv = sub["dep_var"].mean()` / `sd_treat = sub["treatment_var"].std()`
- Wrap the GFM table in a fenced code block (gray background).
- Append significance note below every regression table.

**For each figure section:**

```markdown
## N. Title

**Unit:** ...
[any relevant spec notes]

![alt text](figures/filename.png)

[coefficient table if applicable, same format as above]

---
```

- Embed figures with `![alt](figures/filename.png)` (not `<img>` tag).
- Follow immediately with a coefficient table if the figure has associated estimates.

#### Footer

```markdown
*Sources: script1.R, script2.qmd*
```

No "generated by skill" boilerplate.

### Step 7 — Update the registry

Read `docs/index.md`. Locate the table separator line (`|---`). Insert a new row **immediately after** the separator line (so newest snapshots appear first):

```
| [SNAPSHOT_DATE](snapshots/SNAPSHOT_DIR_BASENAME/index.md) | TRACK / LABEL | |
```

where `SNAPSHOT_DIR_BASENAME` is `YYYYMMDD-TRACK-LABEL` (the final path component).

Use the Edit tool to make this insertion — do not overwrite the entire file.

### Step 8 — Report to user

Print a summary:
```
Snapshot created: docs/snapshots/YYYYMMDD-TRACK-LABEL/
  Figures copied : N
  Tables rendered: N
  Registry updated: docs/index.md

Next: fill in the Summary section in docs/snapshots/YYYYMMDD-TRACK-LABEL/index.md,
then commit and push to publish to GitHub Pages.
```

---

## Notes

- Never overwrite an existing snapshot folder. If `SNAPSHOT_DIR` already exists, append `-2`, `-3`, etc. to the label until the path is unique.
- Figures with identical filenames in `tracks/<TRACK>/latex/figures/` will overwrite each other in the snapshot — this is expected (last-write wins). The source folder is the authoritative reference.
- The snapshot is a point-in-time copy. It does not update automatically when `tracks/<TRACK>/latex/tables/` or `tracks/<TRACK>/latex/figures/` change.
- GitHub Pages setup (one-time): Go to repo Settings → Pages → Source: Deploy from a branch → Branch: `main`, Folder: `/docs`. After pushing, the site is available at `https://[username].github.io/[repo]/`.
