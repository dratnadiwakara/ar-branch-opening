---
name: latex-figure-inserter
description: Insert LaTeX figure environments with optional panels into an existing .tex file at a specified line, following project conventions.
workflow_stage: writing
compatibility:
  - claude-code
  - cursor
  - codex
  - gemini-cli
author: Project Assistant
version: 1.0.0
tags:
  - LaTeX
  - figures
  - papers
  - automation
---

# LaTeX Figure Inserter

## Purpose

This skill inserts a complete LaTeX `figure` environment into an existing `.tex` file at a user‑specified line. It supports single‑image figures and multi‑panel figures (Panel A, Panel B, etc.) and is designed **only** to append content (no deletions or rewrites of existing text).

## Inputs Expected

When this skill is used, you should obtain (either from the user or from the calling tool):

0. **`$ARGUMENTS`**: `<track-name>` (required) — the track folder name under `tracks/`, e.g. `did-april2026`. The skill resolves the figures directory to `tracks/<track-name>/latex/figures/` and the default target file to `tracks/<track-name>/latex/main.tex`.
1. **Target LaTeX file path** (required)  
   - Default: `tracks/<track>/latex/main.tex`. If no file is specified, use that default.
   - Example: `tracks/<track>/latex/main.tex` or `tracks/<track>/latex/sections/results/results_current.tex`.
   - Then figure out what is the file with tables/figures from this file.
2. **Insertion line number** (required)  
   - The 1‑based line number *before which* the new figure should be inserted.
3. **Image list** (required)  
   - A non‑empty ordered list of image paths, relative to the LaTeX file's graphics root.  
   - Example: `["figures/univar_branch_closure_20260312.png"]` or  
     `["figures/univar_branch_closure_20260312.png", "figures/univar_opening_20260312.png"]`.
4. **Caption text** (required)  
   - Short LaTeX‑safe sentence describing the figure, used in `\caption{...}`.
5. **Label key** (required)  
   - Used inside `\label{fig:<key>}`; must be LaTeX‑safe (no spaces).
6. **Description text** (optional but recommended)  
   - Longer paragraph for `\adddescription{...}`, ideally following the narrative style of the example:
   - Example:
     `This figure presents the percentage of branches closed and opened by decile of deposit beta value across three interest rate cycles. ...`

If any of these are missing, ask the user for them rather than guessing, especially for `caption`, `label`, and `description`.

## Formatting Requirements

The inserted block **must** follow this structure:

```latex
\clearpage
\begin{figure}
    \centering
    \adddescription{
    \small
<DESCRIPTION_TEXT>
    }
<PANEL_BLOCKS>
    \caption{<CAPTION_TEXT>}
    \label{fig:<LABEL_KEY>}
\end{figure}
```

### Panel blocks

- **Single image** (no panels, but keep the same indentation and width pattern):

```latex
    \includegraphics[width=0.75\textwidth]{<IMAGE_PATH_1>}
```

- **Multiple images** (each becomes a panel in order; use capital letters, line breaks, and spacing consistent with the example):

```latex
    Panel A: <SHORT_TITLE_1>\\
    \includegraphics[width=0.75\textwidth]{<IMAGE_PATH_1>}
    \vspace{0.5cm}\\
    Panel B: <SHORT_TITLE_2>\\
    \includegraphics[width=0.75\textwidth]{<IMAGE_PATH_2>}
    % (and so on for C, D, ... if needed)
```

Guidelines:
- Use `Panel A`, `Panel B`, `Panel C`, ... in order.
- Ask the user for each `<SHORT_TITLE_k>` (e.g., `"Closures"`, `"Openings"`).  
  - If none are provided, you may omit the titles (`Panel A:\\`), but **do not** invent economic content.
- Keep `width=0.75\textwidth` unless explicitly instructed otherwise.
- Keep a `\vspace{0.5cm}\\` between panels, matching the project example.

### Description and caption

- Wrap the long description inside `\adddescription{ ... }` with an inner `\small` as:

```latex
    \adddescription{
    \small
<DESCRIPTION_TEXT>
    }
```

- `\caption{...}` should be a compact, journal‑style title sentence (e.g., `"Univariate Evidence"`).
- `\label{fig:...}` must immediately follow the caption and use the `fig:` prefix.

## Editing Rules

When applying this skill:

1. **Only edit the provided LaTeX file.**  
   - Do not modify any other files (no changes to `.qmd`, `.R`, etc.).
2. **Do not delete or overwrite existing content.**  
   - Insert new lines at the specified line, shifting existing content downward.
   - Never remove or change text outside the inserted block.
3. **Preserve surrounding formatting.**  
   - Match indentation (4 spaces inside `figure`), blank lines, and spacing style.
4. **Insert exactly one figure environment per invocation** unless explicitly told otherwise.

## Implementation Steps (for the agent)

1. **Gather inputs**: Confirm the `.tex` file path, line number, list of images, caption, label key, and description text (plus optional panel titles if multiple images).
2. **Read the target file**: Use the workspace read tool to load the `.tex` file.
3. **Construct the figure block string**:
   - Start with `\clearpage`.
   - Add `\begin{figure}`, `\centering`, and the `\adddescription` block.
   - Add one or more panel blocks according to the number of images.
   - Add `\caption{...}` and `\label{fig:...}`.
   - Close with `\end{figure}` and a trailing newline.
4. **Insert at the requested line**:
   - Treat the insertion line as the line *before which* the new figure is inserted.
   - Use a patching tool (e.g., `ApplyPatch`) to splice the constructed block into the correct position.
5. **Do not touch any other part of the file**.
6. **Optionally summarize** to the user:
   - Report which file was changed, the line where the figure was inserted, the number of panels, and the final label (e.g., `fig:pct_closed_df_bin`).

## Example Target Style

Use this as the canonical style reference:

```latex
\clearpage
\begin{figure}
    \centering
    \adddescription{
    \small
This figure presents the percentage of branches closed and opened by decile of deposit beta value across three interest rate cycles. Panel A shows closures by decile of predicted branch-level beta. Panel B shows the percent of candidate zip codes with openings by decile of zip code-level beta. Each point represents the average branch closure rate or opening rate within a given beta decile. The figure includes data for the Early cycle (gray circles), Mid cycle (orange triangles), and Late cycle (blue squares). Beta deciles are constructed separately for each cycle, with lower deciles corresponding to lower beta values.
    }
    Panel A: Closures\\
    \includegraphics[width=0.75\textwidth]{figures/univar_branch_closure_20260312.png}
    \vspace{0.5cm}\\
    Panel B: Openings\\
    \includegraphics[width=0.75\textwidth]{figures/univar_opening_20260312.png}
    \caption{Univariate Evidence}
    \label{fig:pct_closed_df_bin}
\end{figure}
```

Your inserted figures should match this pattern unless the user explicitly requests a deviation.
