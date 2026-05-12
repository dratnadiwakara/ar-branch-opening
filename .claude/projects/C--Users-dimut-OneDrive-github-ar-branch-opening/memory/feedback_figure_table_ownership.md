---
name: Figure/table floats live in results section --- other sections only \ref
description: All figure and table floats live in tracks/<track>/latex/sections/results/results_current.tex (or the section that owns them). Data/intro/methods sections must \ref existing labels, never create duplicate \begin{figure}/\begin{table} blocks.
type: feedback
---

Do not embed `\begin{figure}` or `\begin{table}` blocks in data, intro, institutional-background, identification, or other non-results sections. All floats (including descriptive figures and summary-stat tables) are owned by `tracks/<track>/latex/sections/results/results_current.tex` (or whichever section first introduces them). Other sections refer to them only via `\ref{...}` or `\autoref{...}` against the label defined in the owning section.

**Why:** User correction on first-draft-may2026 data section: I had inlined `\begin{figure}` blocks for `fig_map_*` and `fig_openings_by_size_stacked` into the data section, but those floats already lived in `results_current.tex` with their own labels and `\adddescription` captions. The result was duplicate floats. User's intent: floats stay in one section (results), every other section references them.

**How to apply:**
1. Before drafting a non-results section, grep `tracks/<track>/latex/sections/results/results_current.tex` (and other sibling sections) for existing `\label{fig:...}` and `\label{tab:...}` definitions. Build a label-map for the section being drafted.
2. When prose calls for showing a figure or table, write `Figure~\ref{fig:existing_label}` against the discovered label. Do not create a new figure environment.
3. If a figure or table genuinely belongs to the section being drafted and does not yet exist anywhere, ask the user where the float should live before adding it --- the default answer is "in `results_current.tex`."
4. The same rule covers summary-stats tables: the data section references them via `\ref` but does not host the table.
5. When verifying the draft compiles, confirm that every `\ref` resolves --- but the resolution lives in the owning section, not in the section being drafted.
