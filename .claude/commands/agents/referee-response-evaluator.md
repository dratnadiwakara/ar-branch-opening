---
name: referee-response-evaluator
description: >
  Evaluate and improve responses to referee/editor comments for academic finance papers targeting
  top journals (Journal of Finance, Review of Financial Studies, Journal of Financial Economics,
  Management Science, etc.). ONLY use this skill when the user explicitly asks for it by name
  (e.g., "run the referee response evaluator", "use the referee-response-evaluator skill",
  "evaluate my referee responses"). Do NOT trigger automatically based on file contents or
  keywords alone.
---

# Referee Response Evaluator

## Purpose

Given a LaTeX referee response file and the revised paper .tex, produce a structured Markdown
evaluation report saved to `.claude/cc/referee-response-evaluator/evaluation_YYYY-MM-DD.md`.

For each referee point, the report contains:
1. The referee comment (verbatim, cleaned of LaTeX)
2. The current author response (verbatim, cleaned of LaTeX)
3. A star rating (1-5) with brief justification
4. Suggestions from existing paper content (NO new analysis)
5. Things not addressed or inadequately addressed
6. A full suggested replacement response

---

## Step 0: Gather Required Inputs

This skill requires:
1. **`$ARGUMENTS`** (required first argument): `<track-name>` — the track folder name under `tracks/`, e.g. `did-april2026`. Resolves paper paths to `tracks/<track-name>/latex/...`.
2. The referee response .tex (containing \begin{point} and \begin{reply} environments)
3. The revised paper .tex (the manuscript being sent back with the revision)

If either file is missing, apply these defaults before asking:
- If the referee response .tex is missing: ask for it.
- If the revised paper .tex is not specified: default to `tracks/<track-name>/latex/main.tex`. If `tracks/<track-name>/latex/main.tex` does not exist, ask the user for it.

Only proceed to Step 1 once both files are in hand.

---

## Step 1: Parse the LaTeX Input

### Extract referee points and replies

The referee response .tex uses these environments:

  \begin{point} ... \end{point}         % numbered referee comment
  \begin{point*} ... \end{point*}       % unnumbered continuation comment
  \begin{point1} ... \end{point1}       % AE / editor comment
  \begin{reply} ... \end{reply}         % author's response

Parse ALL \begin{point}, \begin{point*}, and \begin{point1} blocks and their
immediately following \begin{reply} blocks. Treat \begin{point*} as a continuation
sub-point of the preceding numbered point (label it e.g. "Comment 1.3 (continued)").

LaTeX cleaning rules (apply to both points and replies):
- Strip LaTeX commands: \textbf{}, \textit{}, \emph{}, \textcolor{blue}{}, \cite{},
  \citep{}, \citet{}, \ref{}, \label{}, \footnote{}, \url{}, \\, \noindent,
  \medskip, \bigskip, \par, \begin{itemize}, \end{itemize}, \item, etc.
- Replace ``...'' with "..." and `...' with '...'
- Replace \emph{X} with *X* (preserve italics as markdown)
- Collapse multiple blank lines to one
- Preserve paragraph breaks as blank lines

### Scan the revised paper .tex

Scan the FULL paper .tex, including all appendix sections (Internet Appendix, Online
Appendix, or any section beginning with \appendix or labeled IA/OA), for:

- Tables referenced in replies (e.g., "Table 6", "Table IA.1", "Appendix Table XX")
- Figures referenced in replies (e.g., "Figure 7", "Figure IA.1")
- Page numbers cited in replies (e.g., "page 31")
- Sections or subsections mentioned by name
- Specific claims made in replies about what was added or changed
- Any \begin{table}, \begin{figure}, \section, \subsection labels in the appendix
  that are referenced from the reply letter

Use these to:
1. Verify whether the reply's claims about the paper are borne out in the actual manuscript
2. Surface additional paper content (from the appendix or main text) that could strengthen replies
3. Flag discrepancies: reply says "see Table XX" where XX is still a placeholder, or
   reply claims a result was added but no corresponding content is found in the paper

---

## Step 2: For Each Point, Produce the Evaluation Block

Output format for each point (in Markdown):

---

## Comment [N] (Referee [R])

### Referee Comment
[cleaned text of \begin{point}]

### Current Response
[cleaned text of \begin{reply}]

### Rating: [X/5]
**Justification:** [2-4 sentences explaining the rating]

### Suggestions from Paper Content
[Bullet list of specific content already in the paper - including appendix sections - that
could strengthen the response. Draw ONLY from: (a) content visible in the reply itself,
(b) content visible in the provided paper .tex (main body and appendix),
(c) cross-references to other comments/replies in the same letter.
DO NOT suggest new analyses, new data, new tests, or new empirical work.]

If no additional paper content is available to draw on, write:
> No additional paper content identified to strengthen this response.

### Issues Not Addressed
[Bullet list of sub-questions or concerns raised by the referee that the current reply
does not answer, or answers only partially.]

If fully addressed: write "None identified."

### Suggested Full Response
[Write a complete, polished replacement for the \begin{reply} block. Style guidelines:
- Match the register of a top finance journal revision letter (formal but direct)
- Begin by acknowledging the point briefly, then address each sub-issue in order
- Reference specific tables, figures, pages, and sections from the paper where applicable
- Draw on paper content (including appendix) surfaced in "Suggestions" above
- Do NOT invent new results, new analyses, or new citations not present in the materials
- Flag placeholders with [XX] where information is missing
- Length: proportional to complexity of the comment; do not pad]

---

## Step 3: Rating Rubric

1/5 - Response largely ignores the comment, is evasive, or contradicts itself
2/5 - Partial engagement; key sub-questions left unanswered; relies on vague reassurances
3/5 - Addresses the main thrust but misses important sub-points or lacks specificity
4/5 - Strong response; addresses most sub-points with evidence; minor gaps only
5/5 - Comprehensive, specific, directly tied to paper content; referee concern fully resolved

Special flags to note in justification:
- PLACEHOLDER: Placeholder present (e.g., "Table XX", "Figure XX", "XXX...") - always flag
- CONTRADICTION: Reply claims one thing, paper suggests another
- OVER-QUOTED: Over-reliance on quotes from the paper without synthesis
- WELL-CITED: Good use of specific cross-references to tables/figures/pages

---

## Step 4: Summary Header

Prepend the report with:

# Referee Response Evaluation

**Paper:** [title if extractable from .tex, else "Untitled"]
**Date evaluated:** [today's date]
**Number of points evaluated:** [N]
**Unresolved placeholders:** [list any "XX" or "XXX" tokens found in replies]

## Overall Assessment
[3-5 sentences: quality of response letter, major strengths, major weaknesses, priorities]

## Priority Action Items
[Numbered list of most important fixes, ordered by urgency:
1. Unresolved placeholders
2. Referee sub-questions not answered
3. Responses strengthened with content already in paper or appendix]

---

## Step 5: Output

Save the complete Markdown report to:

  .claude/cc/referee-response-evaluator/evaluation_<track>_YYYY-MM-DD.md

where `<track>` is the track name from `$ARGUMENTS` and YYYY-MM-DD is today's date (e.g., evaluation_did-april2026_2026-03-23.md).

Create the directory if it does not exist. Then present the file to the user.

---

## Constraints and Style Notes

- Never suggest new analyses. All suggestions must be grounded in content already
  present in the provided materials (the response letter and the paper .tex including appendix).
- Always scan the appendix. Claims about Internet Appendix tables/figures are common;
  verify them against the actual appendix content in the paper .tex.
- Never fabricate table/figure contents. If a table is referenced but not found in the
  paper .tex, flag it explicitly.
- Preserve author voice in suggested responses.
- Be direct about weaknesses. The goal is to help the authors submit the strongest
  possible revision letter, not to validate whatever they have written.
- Placeholders are serious. Any "XX", "XXX", or "TODO" in a reply going to a referee
  is a submission error. Flag every instance prominently.
- Point* environments (unnumbered continuations) are still referee comments and
  must be evaluated - do not skip them.
