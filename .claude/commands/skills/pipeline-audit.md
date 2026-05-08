---
name: pipeline-audit
description: Retrospective code-simplicity audit for empirical finance papers. Maps every reported result back to the code that produces it, identifies dead code and unnecessary complexity, and produces a structured simplification report in `.claude/cc/pipeline-audit/`.
---

# Skill: Empirical Pipeline Audit

You are a **read-only auditor**. You do not modify any manuscript, code, or data file. Your only output is a single structured report (see Step 4).

Your task is a **retrospective parsimony audit**: given the paper as it is now — with its settled tables, figures, and claims — evaluate whether the current codebase is the minimal correct implementation of that paper. You are not looking for bugs or discrepancies (that is the harsh-editor's job). You are asking: **if someone were handed only this paper as a specification and asked to write the code from scratch, what would they write — and how does the current repository differ from that?**

Papers evolve. By the time a paper is final, the codebase typically carries residue from abandoned specifications, discarded samples, exploratory branches, and iterative accumulation. This audit surfaces that residue and proposes a cleaner pipeline.

---

## Inputs

- **`$ARGUMENTS`**: `<track-name>` (required) — the track folder name under `tracks/`, e.g. `did-april2026`. The audit is scoped to that track: it reads `tracks/<track-name>/code/` (all subfolders) and `tracks/<track-name>/latex/...`. The shared `code/common.R` at the project root is also read (it is shared across tracks).

---

## Step 1 — Read the paper

Identify the main manuscript: the user may specify a path (e.g. `tracks/<track>/latex/paper_Jan2026.tex`); otherwise default to `tracks/<track>/latex/main.tex`. Read that file and any files pulled in via `\input{}` or `\include{}`.

Extract and record:

- **Every table** — table number, caption, reported N, reported sample period, reported specification, reported fixed effects and standard error choices
- **Every figure** — figure number, caption, what it displays
- **Every in-text robustness claim** — "results are robust to X", "we also estimate Y", "Appendix Table Z shows" — these are asserted results that must exist in the code
- **Sample description** — the reported unit of observation, date range, data sources, stated filters
- **Variable definitions** — how key variables are defined, including any stated transformations (winsorization, logs, lags, ratios)
- **Identification strategy** — what the paper claims is the source of variation and how it is operationalized

This is your **results inventory**. Everything else in the code either serves this inventory or is residue.

---

## Step 2 — Survey and read the codebase

Scan the track's directory tree. Read every file under `tracks/<track>/code/` including subdirectories. Read shared code at the project root (`code/common.R` or equivalent — shared across all tracks) first, then `tracks/<track>/code/sample-construction/`, then `tracks/<track>/code/result-generation/`, then `tracks/<track>/code/archives/`. Note file types, naming conventions, apparent execution order, and any `source()` / `%run` / `do` / `import` chains.

Read **every file completely**. While reading, build a running inventory:

**For each script, record:**
- What datasets it reads
- What datasets or objects it writes/outputs
- What variables it constructs
- What filters it applies (every `filter()`, `subset()`, `drop if`, `WHERE`, `.query()`, `[condition]`)
- What functions it defines
- What tables or figures it produces

**For each function defined in shared code, record:**
- Its name
- What it does
- Which scripts call it (if any you can identify from reading)

After reading all files, cross-reference your running inventory against the results inventory from Step 1.

---

## Step 3 — Audit

### 3.1 — Build the results-to-code map

For every table and figure in the paper, trace the full pipeline:
- Which result-generation script produces it?
- Which sample-construction scripts does that result-generation script depend on (directly or via intermediate datasets)?
- Which shared functions does it call?
- Which raw data files does the full chain touch?

Record this as a **dependency chain** per result. This is the **minimal sufficient pipeline** — the set of code that must exist to reproduce the paper.

Flag anything in the codebase not reachable from this map.

### 3.2 — Dead code

Flag code that has no path to any reported result:

- **Scripts** in `tracks/<track>/code/sample-construction/` or `tracks/<track>/code/result-generation/` that are not part of any result's dependency chain and are not in `tracks/<track>/code/archives/`
- **Functions** defined in shared code (`code/common.R` or the track's own helpers) that are never called by any in-scope script
- **Variables** constructed (assigned, mutated, joined) in a script but never used downstream — not passed to a regression, not included in a merge key, not written to any output
- **Intermediate datasets** written to disk but never read by any subsequent script in the dependency chain
- **Stray scripts** under `tracks/<track>/code/` that produce results not in the paper — flag them; if they represent abandoned exploration, recommend moving to `tracks/<track>/code/archives/`

### 3.3 — Unnecessary filters and sample restrictions

For every filter in the sample-construction pipeline:
- Is it disclosed in the paper's data section or footnotes?
- Does removing it (hypothetically) change the reported sample size?
- Does it correspond to a standard screen with an established citation, or is it ad hoc?

Flag filters that are undisclosed **and** whose effect on the sample cannot be inferred from the paper. These may be vestigial (from an earlier sample definition) or they may be undisclosed restrictions — either way, they cannot be justified retrospectively and represent unnecessary or unexplained complexity.

### 3.4 — Structural complexity

Flag construction steps that are more complex than the paper requires:

- **Multi-step constructions that could be collapsed**: a variable is constructed in step A, passed through an intermediate dataset, then immediately transformed again in step B, where steps A and B could be a single expression
- **Roundabout merges**: a dataset is merged, subsetted to a small set of columns, then immediately merged again — where the two merges could be a single join
- **Flag variables and conditional branches** whose alternative branch is never triggered by the paper's actual sample or any reported specification (e.g., a `treatment_type` flag that always equals 1 for every observation in the final sample)
- **Parallel variable construction**: the same economic concept is built two or more times in different scripts with slightly different code — only one version feeds the reported results; the others are residue
- **Unnecessary persistence points**: intermediate datasets written to disk and read back in a subsequent script when the data could be passed through in memory, and the intermediate is not a checkpoint reused by multiple downstream scripts

### 3.5 — Minimal pipeline description

After the audit, write a brief description of what the **minimal correct pipeline** would look like: the smallest set of scripts, in the simplest form, that would reproduce every result in the paper from the raw data. This is not a rewrite recommendation — it is a benchmark against which the current complexity can be assessed.

---

## Step 4 — Write the report

Create the folder `.claude/cc/pipeline-audit/` if it does not exist. Save the report as:

`.claude/cc/pipeline-audit/pipeline_audit_<track>_YYYYMMDD.md`

Use the current date in YYYYMMDD format and the track name passed via `$ARGUMENTS`.

Use the following structure:

---

```markdown
# Pipeline Audit Report

**Paper:** [title from .tex]
**Date:** [today]
**Auditor note:** This audit evaluates whether the current codebase is the minimal correct implementation of the paper as it now stands. It does not test for bugs or paper-vs-code discrepancies — see the harsh-editor report for those.

---

## 1. Results Inventory

| Result | Script | Datasets Used | Key Variables | Sample |
|--------|--------|---------------|---------------|--------|
| Table 1 — [caption summary] | `tracks/<track>/code/result-generation/...` | ... | ... | ... |
| Table 2 — ... | | | | |
| Figure 1 — ... | | | | |
| [Robustness claim in text] | | | | |

---

## 2. Dependency Map

For each result, the full pipeline from raw data to output:

### Table 1 — [Short Title]
Raw data → `[sample script]` → `[intermediate dataset]` → `[result script]` → `tracks/<track>/latex/tables/[file]`

[Repeat for each result.]

---

## 3. Dead Code

### 3.1 Unreachable Scripts
[List scripts not in any dependency chain, with their apparent purpose and why they are not needed.]

### 3.2 Unused Functions
[List functions defined in shared code that are never called by any in-scope script.]

### 3.3 Unused Variables
[List variables constructed in scripts but never used downstream. Include file and approximate line.]

### 3.4 Orphaned Intermediate Datasets
[List intermediate files written to `data/constructed/` (project-root, shared) or `tracks/<track>/data/constructed/` (track-local) that are never read by any downstream script.]

### 3.5 Unarchived Exploratory Scripts
[List scripts under `tracks/<track>/code/` whose results do not appear in the paper and that have not been moved to `tracks/<track>/code/archives/`.]

---

## 4. Unnecessary Filters

| Filter | File / Line | Disclosed in Paper? | Hypothetical Effect on N | Assessment |
|--------|-------------|---------------------|--------------------------|------------|
| `filter(price > 5)` | `tracks/<track>/code/sample-construction/build_sample.R:42` | No | Unknown | Vestigial or undisclosed — cannot be justified retrospectively |
| ... | | | | |

---

## 5. Structural Complexity

[For each finding, cite file and approximate line. Describe the current construction and what a simpler equivalent would look like.]

### [Finding title]
**File:** `tracks/<track>/code/...`
**Current construction:** [describe]
**Simpler equivalent:** [describe]
**Why it matters:** [does it affect readability, replicability, or risk of error?]

---

## 6. Minimal Pipeline

If the paper were written from scratch with only the results it currently reports, the minimal correct pipeline would consist of:

**Sample construction:**
- [Script 1 purpose and inputs/outputs]
- [Script 2 purpose and inputs/outputs]

**Result generation:**
- [Script A → Table X, Table Y]
- [Script B → Figure 1, Figure 2]

**Shared code:**
- [What common.R actually needs to contain for this pipeline]

**What the current pipeline has in addition to this:**
- [Concise list of everything present but not needed]

---

## 7. Recommended Actions

Prioritized list of changes that would move the codebase toward the minimal pipeline:

1. **[High priority]** [Action — e.g., "Move `tracks/<track>/code/result-generation/foo_iv.R` to `tracks/<track>/code/archives/` — this script's outputs do not appear in the paper"]
2. **[Medium priority]** [Action]
3. **[Low priority]** [Action]

[Include only actions where there is concrete evidence from the audit. Do not speculate about what the authors intended.]

---

*This report is a read-only audit. No files were modified.*
```

---

## What You Do NOT Do

- Do not modify any manuscript, code, or data file
- Do not raise paper-vs-code discrepancies or methodological concerns — those belong in the harsh-editor report
- Do not speculate about whether a finding is a bug — flag it as residue or complexity and let the authors decide
- Do not recommend changes to the paper's specification or results
- Do not flag stylistic preferences (variable naming, code formatting) — only structural complexity that has a concrete cost in terms of replicability or maintenance
- Do not omit Section 6 (Minimal Pipeline) — this is the benchmark that gives the other findings meaning
