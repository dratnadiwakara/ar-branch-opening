---
name: latex-figure-inserter
description: Insert a LaTeX figure environment into an existing .tex file, following project conventions. Default is a single, no-panel figure; multi-panel layout (Panel A, Panel B, ...) is opt-in. Agent infers track, target file, insertion line, caption, label, and description from the figure path(s) and surrounding context.
workflow_stage: writing
compatibility:
  - claude-code
  - cursor
  - codex
  - gemini-cli
author: Project Assistant
version: 2.1.0
tags:
  - LaTeX
  - figures
  - papers
  - automation
---

# LaTeX Figure Inserter

## Purpose

This skill inserts a LaTeX `figure` environment into an existing `.tex` file. By default it inserts a **single, no-panel figure** — one image wrapped in one `\begin{figure}...\end{figure}` environment. Multi-panel layout (Panel A, Panel B, ...) is opt-in: the user must either pass multiple image paths or explicitly request panels. The skill is **append-only** in the target file: it never deletes or rewrites existing content there.

The agent should infer everything it can from the figure path(s) the user provides, only asking the user as a last resort.

## Inputs Expected

The user provides one of the following call shapes:

1. `$ARGUMENTS = <track-name>` (required first arg) — e.g. `first-draft-may2026`. Used to resolve the default target file and graphics root.
2. **Figure image path(s)** (required) — e.g. `figures/fig_us_branches_total.png` or `figures/fig_us_branches_total` (extension optional). One path = single (no-panel) figure. Multiple paths = panels in order. Paths are relative to the track's `latex/` directory (i.e., the LaTeX graphics root).
3. **Insertion line number** (optional) — 1-based; if provided, the figure is inserted *before* that line in the target file. If omitted, the figure is appended at the bottom of the target file (immediately before any closing macros such as `\end{document}`, or at end-of-file if none).
4. **Target `.tex` file** — always `tracks/<track>/latex/sections/results/results_current.tex`. No fallback. If that file does not exist, stop and ask the user.

Everything else — caption, label, description, and (in the multi-panel case) panel titles — is inferred by the agent. The agent only asks the user when inference is genuinely ambiguous (e.g., no usable signal for a description).

### How the agent infers each field

| Field | How to infer |
|---|---|
| **Track** | Read from `$ARGUMENTS`. |
| **Target file** | Always `tracks/<track>/latex/sections/results/results_current.tex`. Stop if it does not exist. |
| **Insertion line** | If user passes a line number, use it (insert *before* that line). Otherwise append: scan the target file for the last `\end{document}` (or `\end{frame}`, or trailing `\input{...}` block) and insert immediately before it; if none found, append at end-of-file. |
| **Caption** | Strip `fig_` / `fig-` prefix and `_YYYYMMDD` date suffix from the filename, replace `_` with space, title-case. e.g. `fig_us_branches_total.png` → `"US Branches Total"` (then lightly polish: `"Total U.S. Bank Branches"`). When multiple panels share a stem and differ only in a qualifier, prefer the shared stem for the caption. |
| **Label key** | Filename stem (no extension, no date suffix), lowercased, with `fig_` prefix stripped, underscores kept. e.g. `fig_us_branches_total.png` → `\label{fig:us_branches_total}`. For multi-panel figures, derive from the shared stem; if no shared stem, concatenate the unique qualifiers (e.g., `fig_map_jpm_2016` + `fig_map_boa_2018` + `fig_map_wfc_2022` → `fig:map_candidate_markets`). |
| **Description** | Draft per the style guide in `/skills/table-figure-descriptions` (figures section). For figures, cover: (1) what is plotted (axes, units, what each line/bar/color represents), (2) sample and time period, (3) empirical construction (regression / aggregation underlying the figure if applicable), (4) any counterfactual or predicted-value construction, (5) line/color legend describing each element, (6) reference to the relevant paper section if known. **Never interpret results** ("we find", "consistent with", "shows that"). Read the target file's surrounding prose (closest preceding paragraph that mentions the figure topic, or the section heading) plus the figure-generation script under `tracks/<track>/code/result-generation/` plus filename metadata (year ranges, bank names, units) to ground the description in actual specification details. Use third-person, present tense, declarative sentences; 3–8 sentences typical. If there is genuinely no signal, omit `\adddescription{...}` rather than fabricate. |
| **Panel titles** *(multi-panel only)* | Derive each title from its filename the same way as caption derivation. If filenames share a stem and differ only in a qualifier (e.g., `_jpm_2016` vs. `_boa_2018`), use the differing qualifier as the panel title (`"JPMorgan Chase, 2016"`, `"Bank of America, 2018"`). |

If the agent makes a non-obvious choice (chosen target file, append vs. line-N insertion, caption polish, omitted description, label disambiguation), it states the choice in its summary so the user can override.

## Formatting Requirements

### Default: single, no-panel figure

```latex
\clearpage
\begin{figure}
    \centering
    \adddescription{
    \small
<DESCRIPTION_TEXT>
    }
    \includegraphics[width=0.75\textwidth]{<IMAGE_PATH>}
    \caption{<CAPTION_TEXT>}
    \label{fig:<LABEL_KEY>}
\end{figure}
```

- `IMAGE_PATH` is the user-provided path with extension preserved if given; if no extension, leave it unextended (LaTeX will resolve via `\DeclareGraphicsExtensions`).
- If no description is inferred, omit the `\adddescription{...}` block entirely.

### Opt-in: multi-panel figure

Used when the user passes multiple paths or explicitly asks for panels.

```latex
\clearpage
\begin{figure}
    \centering
    \adddescription{
    \small
<DESCRIPTION_TEXT>
    }
    Panel A: <PANEL_TITLE_1>\\
    \includegraphics[width=0.75\textwidth]{<IMAGE_PATH_1>}
    \vspace{0.5cm}\\
    Panel B: <PANEL_TITLE_2>\\
    \includegraphics[width=0.75\textwidth]{<IMAGE_PATH_2>}
    % (and so on for C, D, ...)
    \caption{<CAPTION_TEXT>}
    \label{fig:<LABEL_KEY>}
\end{figure}
```

Guidelines (multi-panel):
- Use `Panel A`, `Panel B`, `Panel C`, ... in order.
- Keep `\vspace{0.5cm}\\` between panels and `width=0.75\textwidth` unless the user explicitly requests otherwise.

## Editing Rules

1. **Edit only the target `.tex` file.** Do not modify `.qmd`, `.R`, image files, or anything else.
2. **Do not delete or overwrite content in the target file.** Insert new lines at the chosen line, shifting existing content downward.
3. **Preserve surrounding formatting.** Match indentation (4 spaces inside `figure`), blank lines, and spacing style.
4. **Insert exactly one figure environment per invocation** unless the user explicitly asks for more.
5. **Do not add panels by default.** A single image path → a single, no-panel block. Use the multi-panel structure only when there are multiple paths or the user explicitly requests panels.

### Duplicate-label guard

Before insertion, grep the target file for the proposed `\label{fig:<key>}`. If it already exists, do **not** silently insert — the duplicate produces `LaTeX Warning: Label fig:<key> multiply defined` and breaks every `\ref{}` to that label. Either:

1. Append a disambiguating suffix (`_v2`, `_extra`) and flag the choice in the summary, or
2. Stop and ask the user before proceeding.

### Image existence guard

Before insertion, verify each referenced image actually exists at `tracks/<track>/latex/<image-path>` (resolving with extensions `.png`, `.pdf`, `.jpg`, `.jpeg`, `.eps` if none was supplied). If any image is missing, stop and ask the user — do not insert a broken `\includegraphics{...}`.

## Implementation Steps (for the agent)

1. **Parse the inputs.** Resolve `<track>` from `$ARGUMENTS`. Target file is always `tracks/<track>/latex/sections/results/results_current.tex` — stop if missing. Decide single vs. multi-panel based on the number of image paths the user passed (and any explicit panel request).
2. **Verify each image exists** under `tracks/<track>/latex/`. Stop if any is missing.
3. **Read the target file.**
4. **Decide insertion line:** explicit line number from user, or append-before-closing-macros / end-of-file.
5. **Infer** caption, label, description (and panel titles only in the multi-panel case) per the inference table.
6. **Duplicate-label check.** Grep the target for the proposed `\label{fig:<key>}`; resolve before inserting (see *Duplicate-label guard*).
7. **Construct the figure block** using the **default single-figure** structure unless multi-panel is required.
8. **Insert at the chosen line** (the line *before which* the block is spliced in, or end-of-file if appending). Use the workspace edit tool.
9. **Summarize** to the user: target file changed, line inserted at (or "appended at EOF"), layout chosen, final label, and any non-obvious inference (omitted description, label disambiguation, etc.).

## Example Target Style

### Default (single, no-panel)

```latex
\clearpage
\begin{figure}
    \centering
    \adddescription{
    \small
This figure plots the total number of FDIC-insured bank branches in the United States by year, using the FDIC Summary of Deposits. The series spans 1994 through the most recent reporting year. The vertical axis reports the count of branch-year observations; the horizontal axis is calendar year.
    }
    \includegraphics[width=0.75\textwidth]{figures/fig_us_branches_total.png}
    \caption{Total U.S. Bank Branches, 1994--Present}
    \label{fig:us_branches_total}
\end{figure}
```

### Multi-panel (when user passes multiple paths or explicitly asks)

```latex
\clearpage
\begin{figure}
    \centering
    \adddescription{
    \small
This figure presents the candidate-market geography for three large banks in three different years. Each panel shades ZIP-level Census ZCTA polygons by the bank's status in that ZIP: blue if the bank operated at least one branch in the ZIP, gold if the ZIP was inside the bank's opportunity set (a CBSA where the bank operated, or a nonmetro county where the bank operated) but the bank had no branch in that ZIP. ZIPs outside the opportunity set are not filled.
    }
    Panel A: JPMorgan Chase, 2016\\
    \includegraphics[width=0.75\textwidth]{figures/fig_map_jpm_2016.png}
    \vspace{0.5cm}\\
    Panel B: Bank of America, 2018\\
    \includegraphics[width=0.75\textwidth]{figures/fig_map_boa_2018.png}
    \vspace{0.5cm}\\
    Panel C: Wells Fargo, 2022\\
    \includegraphics[width=0.75\textwidth]{figures/fig_map_wfc_2022.png}
    \caption{Candidate Markets for Three Large Banks}
    \label{fig:map_candidate_markets}
\end{figure}
```

Inserted figures should match these patterns unless the user explicitly requests a deviation.
