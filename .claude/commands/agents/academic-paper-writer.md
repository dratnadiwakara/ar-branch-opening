---
name: academic-paper-writer
description: Draft economics papers with proper structure and academic style
workflow_stage: writing
compatibility:
  - claude-code
author: Awesome Econ AI Community
version: 1.0.0
tags:
  - LaTeX
  - academic-writing
  - papers
  - economics
---

# Academic Paper Writer

## Purpose

This skill helps economists draft, structure, and polish academic papers with proper conventions for economics journals. It provides templates for different paper types and guidance on academic writing style.

## When to Use

- Starting a new research paper from scratch
- Restructuring an existing draft
- Writing specific sections (introduction, literature review, conclusion)
- Preparing papers for journal submission

## Inputs

- **`$ARGUMENTS`** (required first argument): `<track-name>` — the track folder name under `tracks/`, e.g. `did-april2026`. Drafted section files are written under `tracks/<track-name>/latex/sections/...` and `\input{}`-ed from `tracks/<track-name>/latex/main.tex`. Project root paths `data/raw/`, `data/constructed/`, and `code/common.R` are unchanged.

## Instructions

### Step 1: Identify Paper Type

Ask the user:
1. Is this empirical or theoretical?
2. What is the target journal/audience?
3. What stage is the paper at? (outline, first draft, revision)
4. What sections need help?

### Step 2: Follow the IMRAD Structure

For empirical papers, use:
1. **Introduction** - Motivation, research question, contribution
2. **Literature Review** - Related work and positioning
3. **Data & Methods** - Sources, sample, empirical strategy
4. **Results** - Main findings with tables/figures
5. **Discussion** - Interpretation, mechanisms, limitations
6. **Conclusion** - Summary and implications

### Step 3: Apply Economics Writing Conventions

- **First paragraph** opens with the result, stated concretely (give the fact, not the conclusion). Cochrane (2005) §1.
- **Nothing before the main result** that the reader does not need to read in order to understand it. No warmup exercises, no extensive description of well-known datasets, no replications of others' work in the body.
- **Use present tense** for established facts, past tense for your findings
- **Be precise** with causal language (effect vs. association)
- **Generous, focused** literature review: 2–3 closest papers, set off so a reader can skip if they want.
- **Lead with results** in the results section
- **No "future research" punch list** in the conclusion. Cochrane: "We're less interested in your plans than your memoirs."
- **No adjectives on your own work** — no "striking results," no "very significant," no "interesting finding." Let the world give you the adjectives.

## Example Output: Introduction Template

Cochrane (2005) §1: open with the contribution. Skip philosophy, "the literature has long…",
policy-importance preludes, and quotations. Give the fact behind the result, not just the
conclusion.

```latex
\section{Introduction}

% Open with the result — give the fact, not the conclusion.
We show that [CONCRETE RESULT WITH NUMBERS: e.g., "a one-standard-deviation
increase in X is associated with a Y basis-point change in Z"]. This holds
in [SAMPLE: unit, period, source] using [IDENTIFICATION: natural experiment /
shift-share IV / RDD / staggered DiD]. The estimate is robust to 
[ONE OR TWO MOST IMPORTANT CHECKS] and survives [MOST OBVIOUS THREAT].

% Why this is hard / why prior work could not answer it.
The question is hard because [CONCRETE OBSTACLE: identification, data
availability, measurement]. [1–2 sentences on what new variation, data,
or method this paper brings to the question.]

% Mechanism / interpretation, in one paragraph, with the key piece of evidence.
The effect operates through [CHANNEL]. [Cite the column/figure that shows
the channel — not "we explore mechanisms in Section X".]

% Contribution relative to 2–3 closest papers — generous, specific, brief.
This paper builds on \citet{Author2020} and \citet{OtherAuthor2019}; we
differ in that [SHARP, CONCRETE DIFFERENCE — sample, design, or object of
inference]. We are not the first to study [TOPIC]; we are the first to
[SPECIFIC CLAIM TIED TO THE NEW VARIATION OR DATA].

% Roadmap is OPTIONAL (Cochrane). Omit unless the paper's organization is
% non-obvious. If kept, one short sentence — not a section-by-section table
% of contents.
```

**What this template avoids** (Cochrane violations the old template made):
- "[TOPIC] is a fundamental question in economics" → throat-clearing.
- "Despite extensive research, we still lack clear evidence on…" → bait
  framing; says nothing concrete.
- "Our paper contributes to several strands of literature. First, … Second,
  …" → contribution-list; the contribution should be the result itself,
  stated up front.
- Mandatory roadmap paragraph → optional, often a waste of space.

## Example Output: Results Section Template

```latex
\section{Results}
\label{sec:results}

% Lead with the main finding
Table~\ref{tab:main} presents our main results. Column (1) shows 
the baseline OLS specification without controls. The coefficient 
on [TREATMENT VARIABLE] is [POINT ESTIMATE] (s.e. = [SE]), 
statistically significant at the [1/5/10] percent level.

% Add controls incrementally
In column (2), we add [CONTROL SET 1]. The point estimate 
[increases/decreases slightly/remains stable] to [ESTIMATE]. 
Column (3) includes [CONTROL SET 2] and adds [FIXED EFFECTS]. 
Our preferred specification in column (4) includes [FULL CONTROLS] 
and yields [FINAL ESTIMATE].

% Interpret magnitude
To gauge economic significance, note that [INTERPRETATION]. 
A one standard deviation increase in [X] is associated with 
a [Y] percent [increase/decrease] in [OUTCOME], or roughly 
[COMPARISON TO MEAN/OTHER BENCHMARK].

% Brief mention of mechanisms/heterogeneity if relevant
Table~\ref{tab:hetero} explores heterogeneity by [DIMENSION]. 
We find that the effect is [larger/concentrated among] 
[SUBGROUP], suggesting that [INTERPRETATION].

\begin{table}[htbp]
\centering
\caption{Main Results: Effect of X on Y}
\label{tab:main}
\begin{tabular}{lcccc}
\hline\hline
 & (1) & (2) & (3) & (4) \\
 & OLS & + Controls & + FE & Preferred \\
\hline
Treatment & 0.052*** & 0.048*** & 0.041** & 0.039** \\
          & (0.012)  & (0.011)  & (0.015) & (0.016) \\
\\
Controls       & No  & Yes & Yes & Yes \\
Fixed Effects  & No  & No  & Yes & Yes \\
Cluster SE     & No  & No  & No  & Yes \\
\\
Observations   & 10,000 & 9,850 & 9,850 & 9,850 \\
R-squared      & 0.05   & 0.12  & 0.35  & 0.35  \\
\hline\hline
\multicolumn{5}{l}{\footnotesize Notes: * p<0.10, ** p<0.05, *** p<0.01.} \\
\multicolumn{5}{l}{\footnotesize Standard errors in parentheses.} \\
\end{tabular}
\end{table}
```

## Example Output: Conclusion Template

Cochrane (2005) §1: conclusions short. No restate of findings beyond one
sentence. No "future research" punch list — "We're less interested in your
plans than your memoirs."

```latex
\section{Conclusion}
\label{sec:conclusion}

% One-sentence restate of the result.
[ONE-SENTENCE RESULT, paraphrased — not copied — from the abstract.]

% One short paragraph on the broadest implication that the design actually
% supports. No speculation, no policy advocacy, no "future research" list.
[IMPLICATION TIED DIRECTLY TO WHAT THE DESIGN IDENTIFIES.]
```

## Writing Tips

### For Introductions
- **First sentence should grab attention** - not "This paper examines..."
- **State your contribution clearly** - what's new about this paper?
- **Be specific about magnitudes** - don't just say "large effect"
- **Acknowledge limitations** preemptively in the last paragraph

### For Results
- **Lead with numbers** - put the coefficient in the first sentence
- **Interpret economically** - what does a 0.05 coefficient mean?
- **Guide the reader** through tables column by column
- **Don't oversell** - distinguish statistical from economic significance

### For Conclusions
- **Don't introduce new results** - synthesize what you've shown
- **Be honest about limitations** - reviewers will find them anyway
- **End on the contribution** - remind readers why this matters

## Common Pitfalls

- Burying the main result in the middle of the paper
- Using "significant" without specifying statistical or economic
- Over-claiming causality without proper identification
- Literature review that's just a list of papers
- Conclusion that's just a summary

## References

- [Cochrane (2005) Writing Tips for PhD Students](https://www.johnhcochrane.com/research-all/writing-tips-for-phd-studentsnbsp)
- [Shapiro (2019) How to Give an Applied Micro Talk](https://www.brown.edu/Research/Shapiro/pdfs/applied_micro_slides.pdf)
- [Thomson (2011) A Guide for the Young Economist](https://mitpress.mit.edu/books/guide-young-economist)
