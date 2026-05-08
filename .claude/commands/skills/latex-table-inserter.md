---
name: latex-table-inserter
description: Insert LaTeX table environments (with optional panels) into an existing .tex file at a specified line, following project conventions.
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
  - tables
  - papers
  - automation
---

# LaTeX Table Inserter

## Purpose

This skill inserts a complete LaTeX `table` environment into an existing `.tex` file at a user‑specified line. It supports single‑panel and multi‑panel tables (Panel A, Panel B, etc.) where each panel's content is provided via LaTeX table files (e.g., `\input{tables/closure_regime_large_20260311}`), and is designed **only** to append content (no deletions or rewrites of existing text).

## Inputs Expected

When this skill is used, you should obtain (either from the user or from the calling tool):

0. **`$ARGUMENTS`**: `<track-name>` (required) — the track folder name under `tracks/`, e.g. `did-april2026`. The skill resolves the tables directory to `tracks/<track-name>/latex/tables/` and the default target file to `tracks/<track-name>/latex/main.tex`.
1. **Target LaTeX file path** (required)  
   - Default: `tracks/<track>/latex/main.tex`. If no file is specified, use that default.
   - Example: `tracks/<track>/latex/main.tex` or `tracks/<track>/latex/sections/results/results_current.tex`.
   - Then figure out what is the file with tables/figures from this file.
2. **Insertion line number** (required)  
   - The 1‑based line number *before which* the new table should be inserted.
3. **Panel list** (required)  
   - An ordered, non‑empty list where each panel has:
     - `panel_title` (short, LaTeX‑safe; e.g., `"Large Banks"`, `"Small Banks"`).
     - `table_input_path` (path used inside `\input{...}`, relative to the track's `latex/` directory and usually under `tables/`; e.g., `"tables/closure_regime_large_20260311"`).
4. **Caption text** (required)  
   - Short LaTeX‑safe sentence describing the table, used in `\caption{...}`.
5. **Label key** (required)  
   - Used inside `\label{tab:<key>}`; must be LaTeX‑safe (no spaces).
6. **Description text** (optional but strongly recommended)  
   - Longer paragraph for `\adddescription{...}`, typically describing the model, sample, dependent variable, panels, and notation, similar to the example block below.

If any of these are missing, ask the user for them rather than guessing, especially for `caption`, `label`, and `description`.

## Formatting Requirements

The inserted block **must** follow this structure:

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
\end{table}
```

### Panel blocks

For each panel \(k = 1, 2, \dots\):

```latex
    \vspace{0.25cm}
{\small Panel <LETTER_k>: <PANEL_TITLE_k>}\\
    \resizebox{0.8\textwidth}{!}{
\input{<TABLE_INPUT_PATH_k>}
    }
```

Guidelines:
- Use `Panel A`, `Panel B`, `Panel C`, ... in order.
- `PANEL_TITLE_k` should come from the user‑provided `panel_title`.
- `TABLE_INPUT_PATH_k` should be the user‑provided `table_input_path` (don't add `.tex`; mirror the existing style unless the user specifies otherwise).
- Keep `\vspace{0.25cm}` and `\resizebox{0.8\textwidth}{!}{ ... }` unless explicitly instructed otherwise.
- Insert blank lines between panel blocks if that matches surrounding style, but do not change existing spacing elsewhere.

### Description, caption, and label

- Wrap the long description inside `\adddescription{ ... }` with an inner `\small` exactly as:

```latex
    \adddescription{
\small
<DESCRIPTION_TEXT>
    }
```

- `\caption{...}` should be a concise, journal‑style title (e.g., `"Closures by Regime"`).
- `\label{tab:...}` must immediately follow the caption and use the `tab:` prefix.

## Editing Rules

When applying this skill:

1. **Only edit the provided LaTeX file.**  
   - Do not modify any other files (no changes to `.qmd`, `.R`, or other `.tex` files).
2. **Do not delete or overwrite existing content.**  
   - Insert new lines at the specified line, shifting existing content downward.
   - Never remove or change text outside the inserted block.
3. **Preserve surrounding formatting.**  
   - Match indentation and spacing style.
4. **Insert exactly one table environment per invocation** unless explicitly told otherwise.

## Implementation Steps (for the agent)

1. **Gather inputs**: Confirm the `.tex` file path, insertion line, panel list (titles + table input paths), caption, label key, and description text.
2. **Read the target file**: Use the workspace read tool to load the `.tex` file.
3. **Construct the table block string**:
   - Start with `\clearpage`.
   - Add `\begin{table}[]`, `\centering`, and the `\adddescription` block.
   - Append one panel block per entry in the panel list.
   - Add `\caption{...}` and `\label{tab:...}`.
   - Close with `\end{table}` and a trailing newline.
4. **Insert at the requested line**:
   - Treat the insertion line as the line *before which* the new table is inserted.
   - Use a patching tool (e.g., `ApplyPatch`) to splice the constructed block into the correct position.
5. **Do not touch any other part of the file**.
6. **Optionally summarize** to the user:
   - Report which file was changed, the line where the table was inserted, the number of panels, and the final label (e.g., `tab:closures_by_regime`).

## Example Target Style

Use this as the canonical style reference:

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

Your inserted tables should match this pattern unless the user explicitly requests a deviation.
