---
name: academic-introduction-evaluator
description: >
  Evaluate and critique the introduction of an academic finance or economics paper against
  top-journal standards (JF, RFS, JFE, AER, QJE). Read-only: do not edit the manuscript.
  Output is a single .md report written to the `.claude/cc/academic-introduction-evaluator/`
  folder. Only invoked via the /skills/academic-introduction-evaluator slash command.
  Do NOT trigger based on intent inference or keywords.
---

# Academic Introduction Evaluator

This skill critically evaluates the introduction of a finance or economics research paper
as a **first-time reader** would experience it. The goal is to give the author specific,
actionable feedback on whether a reader coming in cold — a referee, editor, or interested
academic — can understand the paper's motivation, contribution, and fit in the literature.

The evaluation standard is submission to a top-5 finance or economics journal: Journal of
Finance (JF), Review of Financial Studies (RFS), Journal of Financial Economics (JFE),
American Economic Review (AER), or Quarterly Journal of Economics (QJE).

**Read-only.** This skill **only reads** the introduction (from pasted text, .tex, or .pdf).
It must **not** edit, rewrite, or modify the paper or any manuscript files. The agent
surfaces what is missing or misplaced; the author revises. The **only output** is one
markdown report file written to the **`.claude/cc/academic-introduction-evaluator/`**
folder (e.g. `.claude/cc/academic-introduction-evaluator/introduction_evaluation_<track>_YYYYMMDD.md`).
Do not write the evaluation elsewhere or only to the chat.

---

## The Introduction Formula (canonical standard)

Top economics and finance introductions follow this structure, distilled from Keith Head's
Introduction Formula and Claudia Sahm's framework, as practiced in AER/QJE/JF:

1. **Hook** — Why should the reader care about this topic right now? The hook makes Y
   interesting: Y matters (people are hurt or helped), Y is puzzling, Y is controversial,
   or Y is pervasive. Avoid: "bait and switch" (promising something interesting but
   delivering something narrower), or "all my friends are doing it" (no motivation beyond
   prior papers existing).

2. **Research Question** — What exactly does this paper do? The reader should be able to
   state the clean research question after one reading. Usually ends with an explicit
   sentence like "This paper asks whether..." or "We study the effect of X on Y." Avoid
   vague questions ("we examine the relationship between...") or questions only answerable
   with full institutional knowledge.

3. **Main Results / Contribution** — What do you find? State the core finding quantitatively
   if possible. A first-time reader should be able to summarize the paper's results after
   the introduction alone.

4. **Antecedents** — What prior work does this paper build on? Identify the 4–7 most closely
   related studies. The key mistake: listing too many tangentially related papers instead of
   focusing on the intellectual lineage that makes this paper's gap obvious.

5. **Value-Added** — How does this paper improve on the antecedents? Describe ~3 distinct
   contributions relative to prior work. This is often the most important paragraph for
   convincing referees. Contributions should only make sense in light of the antecedents
   (unlike the research question, which should stand alone).

6. **Identification / Method** (for empirical papers) — How do you know this is causal?
   Sketch the identification strategy. A first-time reader should understand why the
   estimates are credible without reading the body of the paper.

7. **Robustness Checks** (optional but common in top journals) — Signal that the main
   results are not a fluke. Brief. Avoid enumerating every robustness check; pick the
   one or two that address the most obvious concerns.

8. **Road Map** — Outline the paper's organization. Keep it short and customized (not
   "Section 2 contains the model, Section 3 has results…"). Many top papers omit or
   minimize this. **Do not penalize for omission** — Cochrane (2005) §1 explicitly
   treats the roadmap as optional.

---

## Workflow

### Step 1 — Ingest the introduction (read-only)

The user will provide the introduction as:
- Pasted text
- A `.tex` file — use the Read tool to open it; strip LaTeX markup mentally when evaluating
- A `.pdf` — use the Read tool if the environment supports it, or the Shell tool to extract
  text (e.g. with pdftotext or similar)
- A `.tex` file for the whole paper — locate the `\section{Introduction}` block (or equivalent)

**Inputs:** **`$ARGUMENTS`**: `<track-name>` (required) — the track folder name under `tracks/`, e.g. `did-april2026`. The skill resolves the default file to `tracks/<track-name>/latex/main.tex`. The user may pass an explicit `.tex` path to override.

**Default:** If no file is specified, use `tracks/<track>/latex/main.tex`. Use this file to figure out the introduction tex file.

**Do not modify the manuscript.** Only read. If the paper body (beyond the introduction) is
available, skim it briefly to understand the actual findings and methodology — this helps you
judge whether the introduction accurately represents the paper.

### Step 2 — First-time reader pass

Read the introduction **once**, as a cold reader would. After reading, answer these
questions from memory (do not re-read):

- What is the paper about? (Can you state the topic in one sentence?)
- What is the specific research question?
- What are the main findings?
- Why should I care about this topic?
- How does this paper differ from prior work?
- Why should I trust the results?

Write down your answers. Gaps in your answers reveal problems in the introduction.

### Step 3 — Structured evaluation

Evaluate each component of the Introduction Formula:

For each component, assess:
- **Present?** (Yes / Partial / No)
- **Where?** (Which paragraph or sentence handles this)
- **Quality** (Does it succeed? What's missing or weak?)

### Step 4 — Paragraph-by-paragraph audit

Go through each paragraph and assess:
- What is the purpose of this paragraph?
- Does it advance the narrative, or is it filler?
- Is it positioned correctly in the flow?

Flag:
- Paragraphs that bury the lede (the hook appears on page 3)
- Paragraphs where the research question is vague or unstated
- Over-long literature review sections that delay the contribution
- Results that are qualitative only ("we find a positive effect") when quantitative
  summary is possible ("we find a 15% increase in…")
- Identification strategy absent or buried
- Value-added paragraph that restates the research question instead of comparing to
  prior work
- **Throat-clearing opener** (Cochrane 2005 §1) — opening sentence of the form:
  - "Financial economists have long wondered whether…"
  - "The finance literature has long been interested in…"
  - "[Topic] is a fundamental / important / longstanding question in economics…"
  - "In recent years, the literature on X has grown…"
  - A paragraph of policy-importance preamble before the contribution
  - A cute opening quotation (`\epigraph`, `\begin{quote}`, italicized quote)
  - Flag these prominently. The intro must open with what the paper does.
- **Conclusion stated abstractly** instead of concretely — e.g. "we show that the
  pecking-order theory is rejected" without giving the underlying fact ("in a
  regression of x on y, controlling for z, the coefficient is q"). Cochrane: give
  the fact, not the conclusion.
- **Adjectives on own work**: "striking results", "very significant", "novel
  finding". Cochrane: let the world give you the adjectives.

### Step 5 — Write the evaluation report

Produce the structured report (see Output Format below) and **write it to a single file in
the `.claude/cc/academic-introduction-evaluator/` folder**. Use a track- and date-stamped filename:
`.claude/cc/academic-introduction-evaluator/introduction_evaluation_<track>_YYYYMMDD.md`
(or a user-specified name if provided). Ensure the `.claude/cc/academic-introduction-evaluator/`
directory exists, creating it if necessary. Do not write the evaluation to any other path.
Do not output the full report only in the chat — the canonical output is the .md file
in `.claude/cc/academic-introduction-evaluator/`.

---

## Output Format

Write the report to **`.claude/cc/academic-introduction-evaluator/introduction_evaluation_<track>_YYYYMMDD.md`**
(with the current date and track, or a name the user specified). The report must be structured as follows:

```
# Introduction Evaluation: [Paper Title or Topic]

## First-Time Reader Summary
> What a cold reader takes away after one read-through — state this honestly before
> the detailed critique. If important elements are missing, they will appear as gaps here.

**Research Question (as understood):** ...
**Main Findings (as understood):** ...
**Why This Matters (as understood):** ...
**Key Contribution vs. Prior Work (as understood):** ...
**Identification / Why I Trust the Results (as understood):** ...

---

## Scorecard

| Component              | Present?  | Quality  | Notes                        |
|------------------------|-----------|----------|------------------------------|
| Hook / Motivation      | Yes/No/Partial | ★★★☆☆ | ...                    |
| Research Question      | Yes/No/Partial | ★★★☆☆ | ...                    |
| Main Results           | Yes/No/Partial | ★★★☆☆ | ...                    |
| Antecedents            | Yes/No/Partial | ★★★☆☆ | ...                    |
| Value-Added            | Yes/No/Partial | ★★★☆☆ | ...                    |
| Identification/Method  | Yes/No/Partial | ★★★☆☆ | ...                    |
| Robustness             | Yes/No/Partial | ★★★☆☆ | ...                    |
| Road Map               | Yes/No/Partial | ★★★☆☆ | ...                    |

**Overall First-Time Reader Clarity: ★★★☆☆**

---

## Critical Issues (must fix before submission)

[List 2–5 issues that, if unresolved, would likely cause a referee to misunderstand
the paper or undervalue the contribution. Be specific — cite the paragraph or sentence
and explain the problem.]

1. **[Issue title]**: [Specific description]. *Suggested fix: ...*

---

## Paragraph-by-Paragraph Notes

**Paragraph 1:**
Purpose: ...
Assessment: ...

**Paragraph 2:**
...

---

## Positive Elements

[Note 2–4 things the introduction does well. Be specific.]

---

## Suggested Revision Priorities

[Rank-ordered list of what to address first. Focus on structural issues before polish.]

1. ...
2. ...
3. ...
```

---

## Tone and Standards

- Write as a **senior referee** at a top journal, not as a copy-editor. Focus on structure,
  completeness, and reader comprehension — not on sentence-level prose.
- Be specific. Do not say "the hook could be stronger." Say "The hook (paragraph 1) focuses
  on institutional background but does not explain why this question matters for asset prices
  or welfare. A reader does not know why they should care until paragraph 4."
- Do not suggest the paper is bad if only the introduction is weak. Many excellent papers
  have poor introductions. Your job is to fix the introduction.
- **Do not rewrite the introduction and do not edit the manuscript.** This skill is
  read-only. Surface what is missing or misplaced; let the author revise.
- For finance papers specifically: referees at JF/RFS/JFE are empiricists who will
  immediately look for the identification strategy and the economic magnitude of effects.
  If either is absent from the introduction, flag it prominently.

---

## Common Introduction Failures in Finance/Econ Papers

| Failure Pattern | Description | Fix |
|---|---|---|
| Burying the lede | The paper's main finding or question appears in paragraph 4+ | Move it to paragraph 1–2 |
| No research question sentence | Introduction describes a topic but never states "This paper asks..." | Add explicit question sentence by paragraph 2 |
| Results are qualitative only | "We find that X affects Y" with no magnitudes | State effect size or economic magnitude |
| Literature review substitutes for value-added | 2 pages of citation without explaining the gap | Cut to 5–7 key papers; explain what each cannot do that you can |
| Identification absent | Empirical paper with no description of research design | Add 1–2 sentences on the identification strategy in the intro |
| Hook is too narrow | Opens with "In recent years, the literature on X has grown..." | Replace with a fact, statistic, or question that motivates WHY X matters |
| Throat-clearing opener (Cochrane 2005) | Opens with "Financial economists have long…", "[Topic] is a fundamental question…", policy-importance preamble, or a quotation | Cut to the result. Open with what the paper does, stated concretely. |
| Conclusion-only result statement | "We show the pecking-order theory is rejected" without giving the underlying coefficient/fact | Give the fact: "In a regression of x on y, controlling for z, the coefficient is q." |
| Adjectives on own work | "striking results", "very significant", "novel finding" | Cut. Cochrane: let the world give you the adjectives. |
| Value-added = contribution list | Lists 3 things the paper does without explaining how they differ from prior work | Each contribution should be framed as "unlike [prior paper], we..." |
| Road map is generic | "Section 2 describes the data. Section 3 presents results." | Customize: mention what the reader will learn at each step |
