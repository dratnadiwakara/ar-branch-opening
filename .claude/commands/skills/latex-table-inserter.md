---
name: latex-table-inserter
description: Insert a LaTeX table environment into an existing .tex file, following project conventions. Default is a single, no-panel table; multi-panel layout is opt-in. Agent infers track, insertion line, caption, label, and description from the inputs and target file context.
workflow_stage: writing
compatibility:
  - claude-code
  - cursor
  - codex
  - gemini-cli
author: Project Assistant
version: 4.1.0
tags:
  - LaTeX
  - tables
  - papers
  - automation
---

# LaTeX Table Inserter

## Purpose

This skill inserts a LaTeX `table` environment into an existing `.tex` file. By default it inserts a **single, no-panel table** — one input file wrapped in one `\begin{table}...\end{table}` environment. Multi-panel layout (Panel A, Panel B, ...) is opt-in: the user must explicitly request panels, either by passing multiple input paths together with a request to use panels, or by stating something like "use panels", "multi-panel", "Panel A and Panel B", etc. The skill is **append-only** in the target file: it never deletes or rewrites existing content there.

The agent should infer everything it can from the two paths the user provides, only asking the user as a last resort.

## Inputs Expected

The user provides:

1. `$ARGUMENTS = <track-name>` (required first arg) — e.g. `first-draft-may2026`. Used to resolve the target file.
2. **Table `.tex` file path** (required) — e.g. `tables/tab_first_stage.tex` (or just `tables/tab_first_stage`). One path = one (no-panel) table. Multiple paths = panels in order (multi-panel layout is automatically used when more than one path is supplied, or when the user explicitly asks for panels).
3. **Insertion line number** (optional) — 1-based; if provided, the table is inserted *before* that line in the target file. If omitted, the table is appended at the bottom of the target file (immediately before any closing macros such as `\end{document}`, or at end-of-file if none).

The target `.tex` file is **always** `tracks/<track>/latex/sections/results/results_current.tex`. No fallback. Stop and ask the user if it does not exist.

Everything else — caption, label, description, and (in the multi-panel case) panel titles — is inferred by the agent. The agent only asks the user when inference is genuinely ambiguous (e.g., no usable context for a description).

### How the agent infers each field

| Field | How to infer |
|---|---|
| **Track** | Read from `$ARGUMENTS`. |
| **Target file** | Always `tracks/<track>/latex/sections/results/results_current.tex`. Stop if it does not exist. |
| **Insertion line** | If user passes a line number, use it (insert *before* that line). Otherwise append: scan the target file for the last `\end{document}` (or `\end{frame}`, or trailing `\input{...}` block) and insert immediately before it; if none found, append at end-of-file. |
| **Caption** | Strip `tab_` / `tab-` prefix and `_YYYYMMDD` date suffix from the filename, replace `_` with space, title-case. e.g. `tab_first_stage_20260508` → `"First Stage"`. If the source file's pre-strip `\caption{...}` text is more descriptive, prefer that wording (and flag the choice in the summary). |
| **Label key** | Filename stem with `tab_` prefix and date suffix stripped, lowercase, underscores kept. e.g. `tab_first_stage_20260508.tex` → `\label{tab:first_stage}`. |
| **Description** | Draft per the style guide in `/skills/table-figure-descriptions` (tables section). For tables, cover: (1) what the table shows (DV, unit of observation, regression / test being run), (2) sample and time period plus key sample restrictions, (3) specification context (estimation setup when not obvious from headings — e.g., "baseline linear probability model from Equation (5a)"; do **not** enumerate every control / FE unless one of them is the focus), (4) estimation method (OLS, IV, probit; if IV, name the instrument and the section that discusses it), (5) standard-error clustering, (6) the standard significance-stars sentence (`*, **, and *** denote statistical significance at the 10\%, 5\%, and 1\% level, respectively.`), (7) variable construction for any non-obvious transformation (e.g., `log(1 + experience)`). **Never interpret results** ("we find", "consistent with"). Read the target file's surrounding prose, the source table `.tex` (column headers, row labels, FE / cluster lines), and the script that emits the table under `tracks/<track>/code/result-generation/` to ground the description in actual specification details. Use third-person, present tense, declarative sentences; 3–8 sentences typical (longer if multi-panel, with each panel described separately). If there is genuinely no signal, omit `\adddescription{...}` rather than fabricate. |
| **Panel titles** *(multi-panel only)* | When user opts into panels: derive each title from its filename the same way as caption derivation. If filenames share a stem and differ only in a qualifier (e.g., `_large` vs. `_small`), use the differing qualifier as the panel title (`"Large Banks"`, `"Small Banks"`). |

If the agent makes a non-obvious choice (chosen insertion line, caption from source vs. filename, omitted description, etc.), it states the choice in its summary so the user can override.

## Formatting Requirements

### Default: single, no-panel table

```latex
\clearpage
\begin{table}[]
    \centering
    \adddescription{
\small
<DESCRIPTION_TEXT>
    }

    \resizebox{0.8\textwidth}{!}{
\input{<TABLE_INPUT_PATH>}
    }
    \caption{<CAPTION_TEXT>}
    \label{tab:<LABEL_KEY>}
\end{table}
```

- `\resizebox{0.8\textwidth}{!}{ ... }` wraps `\input{...}` so the body scales to 80% of text width.
- `TABLE_INPUT_PATH` is the user-provided path with `.tex` stripped (e.g., `tables/tab_first_stage`).
- If no description is inferred, omit the `\adddescription{...}` block entirely (and the blank line after it).
- **Do not** add `Panel A: ...` headings in the default (single-table) case.

### Opt-in: multi-panel table

Used **only** when the user explicitly asks for panels. Block structure:

```latex
\clearpage
\begin{table}[]
    \centering
    \adddescription{
\small
<DESCRIPTION_TEXT>
    }

<PANEL_BLOCKS>
    \caption{<CAPTION_TEXT>}
    \label{tab:<LABEL_KEY>}
\end{table>
```

For each panel \(k = 1, 2, \dots\):

```latex
    \vspace{0.25cm}
{\small Panel <LETTER_k>: <PANEL_TITLE_k>}\\
    \resizebox{0.8\textwidth}{!}{
\input{<TABLE_INPUT_PATH_k>}
    }
```

Guidelines (multi-panel):
- Use `Panel A`, `Panel B`, `Panel C`, ... in order.
- Keep `\vspace{0.25cm}` and `\resizebox{0.8\textwidth}{!}{ ... }` unless the user explicitly requests otherwise.

## Editing Rules

1. **Edit the target `.tex` file (insertion).** Do not modify unrelated files.
2. **Edit the source table `.tex` file(s) only to strip a self-contained wrapper.** If a source table file under `tables/` already contains its own `\begin{table}...\end{table}` environment, `\caption{...}`, `\label{...}`, or `\centering`, strip those so only `\begin{tabular}...\end{tabular}` (or equivalent core content like `tabularx`, `longtable`, etc.) remains. The canonical wrapper, caption, and label must come from the inserted block in the target file — never from the input file. This avoids nested `table` environments and duplicate labels.
3. **Do not delete or overwrite content in the target file.** Insert new lines at the chosen line, shifting existing content downward.
4. **Preserve surrounding formatting.** Match indentation and spacing style.
5. **Insert exactly one table environment per invocation** unless the user explicitly asks for more.
6. **Do not add panels by default.** A single input path → a single, no-panel block. Use the multi-panel structure only when the user explicitly requests panels.

### Source-file wrapper stripping (details)

When reading each source table file, detect and remove (in the source file, in-place) any of the following so the file becomes a bare `tabular`-style fragment ready to be `\input{}`-ed:

- Outer `\begin{table}[...]` ... `\end{table}` (and any `\begin{table*}` variant)
- `\centering` directly inside the stripped wrapper
- `\caption{...}` lines
- `\label{...}` lines (the canonical label is set by the target wrapper)
- **`\label{}` *nested inside* `\caption{}`.** `fixest::etable(tex = TRUE, title=, label=)` emits `\caption{\label{tab:foo} Title text}` — the label is inside the caption, not on its own line. Match this pattern explicitly (e.g. `\\caption\{\\label\{[^}]*\}\s*[^}]*\}`) and remove the whole caption line, not just standalone `\label{...}`.
- Stray surrounding blank lines created by the strip

Keep `\begin{tabular}{...}` ... `\end{tabular}` (and content like `\midrule`, footer rows, etc.) untouched. The result is a fragment that produces the same body when `\input{}`-ed inside the new wrapper.

### Source caption text: clean before adopting

When inferring the target caption and the source's pre-strip `\caption{...}` text is preferred over the filename, **clean common encoding artifacts** before using it:

- `â€"` / `â€"` → `---` (em dash) or `--` (en dash)
- `â€¦` → `\ldots`
- `â€™` → `'`
- Other UTF-8-mis-encoded characters: either fix or fall back to the filename-derived caption.

These artifacts come from `etable()` titles round-tripped through Windows-1252 / UTF-8. Never copy them verbatim into the target — a clean fallback is better than a corrupt-looking caption.

### siunitx S-column wrap pass (when source uses `S[table-format=...]` columns)

If the source `tabular` declares `S[table-format=...]` columns (siunitx decimal-aligned), every non-numeric cell in the source file will break the compile until it is wrapped in `\multicolumn{1}{c}{...}`. The wrap is required for:

- Text headers (`Early-F`, `>=\$100B`)
- Yes/No FE / control rows
- Math-macro cells (`$-7.93\times 10^{-5}$`, fractions)
- Thousands-separator integers (`1,164,694`)
- Cells containing bare `$` or other math-mode characters

After stripping the wrapper, run a wrap pass over the source file: walk every `&`-separated row between `\begin{tabular}` and `\end{tabular}` (skip whole-row `\multicolumn{N}{l|c|r}{...}` banner rows; split on unescaped `&` only — use `(?<!\\)&`); for each cell that does **not** match `^[-+0-9.()*$^{}\s]+$` (note: no comma, no backslash, no letters), wrap it as `\multicolumn{1}{c}{<cell>}`. Project convention: this is implemented by the `align_decimals()` helper in `code/result-generation/*.qmd`. Re-run that helper logic on the stripped source file or hand off to the upstream emit step.

If the source has no S columns (plain `c` columns), skip this pass.

### Duplicate-label guard

Before insertion, grep the target file for the proposed `\label{tab:<key>}`. If it already exists, do **not** silently insert — the duplicate produces `LaTeX Warning: Label tab:<key> multiply defined` and breaks every `\ref{}` to that label. Either:

1. Append a disambiguating suffix (`_v2`, `_panel`, `_robustness`) and flag the choice in the summary, or
2. Stop and ask the user before proceeding.

The same guard applies in the multi-panel case: the canonical wrapper label must be unique across the project.

## Implementation Steps (for the agent)

1. **Parse the inputs.** Resolve `<track>` from `$ARGUMENTS`. Target file is always `tracks/<track>/latex/sections/results/results_current.tex` — stop if missing. Decide single vs. multi-panel from the number of source paths supplied (or an explicit user request).
2. **Read the target file** and each table `.tex` file.
3. **Strip wrappers from each source table file** if present (see *Source-file wrapper stripping* above), including the `\label{}`-nested-inside-`\caption{}` pattern emitted by `fixest::etable`. Note in the summary which source files were stripped.
4. **Run the siunitx wrap pass** on each stripped source file *if* the source's `tabular` uses `S[table-format=...]` columns (see *siunitx S-column wrap pass* above). Skip otherwise.
5. **Decide insertion line:** explicit line number from user, or append-before-closing-macros / end-of-file.
6. **Infer** caption, label, description (and panel titles only in the multi-panel case) per the inference table. **Clean any encoding artifacts** in source-derived caption text (see *Source caption text: clean before adopting*).
7. **Duplicate-label check.** Grep the target for the proposed `\label{tab:<key>}`; resolve before inserting (see *Duplicate-label guard*).
8. **Construct the table block** using the **default single-table** structure unless multi-panel is required.
9. **Insert at the chosen line** (the line *before which* the block is spliced in, or end-of-file if appending). Use the workspace edit tool.
10. **Summarize** to the user: target file changed, line inserted at (or "appended at EOF"), source files stripped, wrap pass applied (yes/no), caption-clean edits, layout chosen, final label, and any non-obvious inference (omitted description, label disambiguation, etc.).

## Example Target Style

### Default (single, no-panel)

```latex
\clearpage
\begin{table}[]
    \centering
    \adddescription{
\small
This table reports first-stage regressions of the change in deposit expense on bank and market characteristics for three sub-periods (Early, Mid, Late). IID standard errors are reported in parentheses. *, **, and *** denote statistical significance at the 10\%, 5\%, and 1\% levels, respectively.
    }

    \resizebox{0.8\textwidth}{!}{
\input{tables/tab_first_stage}
    }
    \caption{Deposit Beta First Stage}
    \label{tab:first_stage}
\end{table}
```

### Multi-panel (only when user explicitly asks)

```latex
\clearpage
\begin{table}[]
    \centering
    \adddescription{
\small
This table presents linear probability model estimates of branch closure using Equation (5a), where the dependent variable equals one if a branch was closed in a given year. Panel A reports results for large banks ($>$\$100 billion in assets), and Panel B reports results for small banks ($<$\$100 billion). Each column corresponds to a distinct time period: 2001–2007, 2008–2011, 2012–2019, and 2020–2023. Standard errors (in parentheses) are clustered at the bank level. *, **, and *** denote statistical significance at the 10\%, 5\%, and 1\% levels, respectively.
    }

    \vspace{0.25cm}
{\small Panel A: Large Banks}\\
    \resizebox{0.8\textwidth}{!}{
\input{tables/closure_regime_large_20260311}
    }

\vspace{0.25cm}
{\small Panel B: Small Banks}\\
    \resizebox{0.8\textwidth}{!}{
\input{tables/closure_regime_small_20260311}
    }
    \caption{Closures by Regime}
    \label{tab:closures_by_regime}
\end{table}
```

Inserted tables should match these patterns unless the user explicitly requests a deviation.
