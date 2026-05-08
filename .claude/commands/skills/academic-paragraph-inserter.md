---
name: academic-paragraph-inserter
description: >
  Insert a new sentence or paragraph into an existing academic finance or economics paper
  at a specified line in a .tex file. Only invoked via the /skills/academic-paragraph-inserter
  slash command. Do NOT trigger based on intent inference or keywords. Only the specified line
  and immediately surrounding text may be changed; do not edit anywhere else.
---

# Academic Paragraph Inserter

This skill inserts a **new sentence or paragraph** into an academic finance or economics paper
**at a specified line number** in a **.tex file**. The insertion must: (1) communicate the
author's intended point precisely, (2) fit the voice and style of the surrounding text,
(3) connect smoothly to what comes before and after, and (4) meet the writing standards of
top finance/economics journals (JF, RFS, JFE, AER, QJE).

**Scope of edits (strict):** Insert only at the given line. Change **only** the text immediately
surrounding the insertion point (e.g., the sentence or line before/after) when necessary to
accommodate the new content (e.g., fixing a transition). **Do not change anything anywhere
else** in the manuscript.

---

## Writing Standards for Top Finance/Econ Journals

Before inserting any text, internalize these norms:

**Voice and tense**
- **Voice is authorship-conditional.** Read the project `CLAUDE.md` and locate the
  `**Authorship**:` field.
  - `solo` → use **first-person singular** ("I show", "I find", "My results"), per
    Cochrane (2005) §2 ("'I' is fine. Don't use the royal 'we' on a sole-authored paper").
  - `coauthored` (default if the field is missing or unrecognized) → use **first-person
    plural** ("We show", "We find", "Our results").
  Use third-person only when referring to others.
- Use **present tense** for statements about the paper ("we find", "Table 3 shows") and for
  economic claims that are general truths ("firms that are more levered pay higher spreads").
- Use **past tense** for describing what you did ("we collected", "we estimated").

**Sentence structure**
- Prefer shorter sentences over compound ones. Avoid "which" chains.
- Technical claims should be stated before caveats ("X increases Y; this effect is larger
  for small firms" — not "While the effect may vary, X generally increases Y").
- Do not pad. Each sentence should do work.

**Precision**
- Quantify when possible ("a one-standard-deviation increase in X is associated with a 12
  basis point increase in Y" is better than "X is positively associated with Y").
- Avoid weasel words: "somewhat", "relatively", "appears to", "seems to". State the finding
  directly.
- Define any new variable or term the first time it appears in the insertion.

**Cochrane (2005) micro-rules — apply to every insertion**
- Kill "in other words" — if the prior sentence needed a restate, fix the prior sentence.
- Kill "it should be noted that", "it is worth noting that", "it is easy to show that". Just
  state the point.
- Strike everything before "that" in sentences of the form "It is clear that…", "There is X
  that…". Lead with the noun.
- Clothe naked "this" — never start a sentence with "This shows…" / "This implies…" without
  a following noun ("This regression shows…", "This pattern implies…").
- "Where" refers to a place; "in which" refers to a model. Write "models in which", not
  "models where".
- No double adjectives ("very significant", "highly novel"). No adjectives on own work
  ("striking", "remarkable", "fascinating").
- For a causal sign, use one direction. Do not write "X increases (decreases) when Y
  decreases (increases)"; write the up-direction once, add "and vice versa" if needed.
- No "I leave X for future research" / "this opens avenues for future work."
- Do not abbreviate author names ("FF" → "Fama and French"; "DKS" → spell it out).
- Do not "assume" a model structure when stating it. Write "consumers have power utility,"
  not "we assume that consumers have power utility." Reserve "assume" for genuine
  identifying assumptions about the world.

**Citation style**
- Use author-year in parentheses: "(Fama and French, 1992)" or inline: "Fama and French
  (1992) show that..."
- Only cite papers that are directly relevant to the point being made. Do not add citations
  to pad the literature review.

**Transitions**
- New paragraphs should connect explicitly to the preceding one when the topic shifts.
  Use transitional phrases: "Beyond the main findings, ...", "A related concern is...",
  "To address this possibility, ...", "Consistent with this interpretation, ..."
- Do not use mechanical transitions: "Furthermore", "Moreover", "Additionally" at the
  start of every paragraph.

---

## Required inputs

- **`$ARGUMENTS`**: `<track-name>` (required, first token) — the track folder name under `tracks/`, e.g. `did-april2026`. The skill resolves the default file to `tracks/<track-name>/latex/main.tex`.
- **Path to the .tex file** — the manuscript to edit. Default: `tracks/<track>/latex/main.tex`. The user may supply an explicit path to a section file under `tracks/<track>/latex/sections/<sec>/<sec>_current.tex` instead.
- **Line number** — the line in that file where the new sentence or paragraph should be inserted (new content is placed at this line; existing content at this line moves down).
- **The point to communicate** — what the insertion should say (one sentence, a few sentences, or a full paragraph).

If any of these are missing, ask before proceeding.

## Workflow

### Step 1 — Read the .tex file and locate the insertion point

- Open the specified .tex file and go to the given line number.
- If the file is split across multiple `\input{}` or `\include{}` files, determine which file contains the line (e.g. the main .tex may `\input{sections/results/results_current}`; line numbers refer to the file the user specified).
- Extract **context**: the paragraph(s) or block of lines immediately before and after the insertion line (e.g. 10–30 lines around it, or until clear paragraph boundaries). This is the only text you may use to match voice and flow, and the only region you may modify (plus the new insertion).

### Step 2 — Understand the surrounding context

Using the extracted context:

- **Preceding paragraph/sentence**: What has just been established? What does the reader know at this point? What is the logical next step?
- **Following paragraph/sentence**: What comes next? Does the insertion need to create a bridge into it, or does it stand alone before a topic change?
- **Section type**: Introductions, data sections, results sections, and conclusions each have different norms. Calibrate tone accordingly.
- **Paper-level voice**: Note phrasing patterns — short declarative vs. longer sentences, use of passive voice. Match their style.

### Step 3 — Identify the insertion's logical role

Before drafting, determine:
- Is this insertion **extending an existing argument**? (Continue the thread)
- Is this insertion **adding a new point**? (New paragraph, explicit transition)
- Is this insertion **addressing an objection or caveat**? (Concessive framing)
- Is this insertion **linking to prior or subsequent content**? (Bridge paragraph)
- Is this insertion **stating a result or finding**? (Declarative, quantitative if possible)

This determines the structure and opening sentence of the insertion.

### Step 4 — Draft the insertion

Write the sentence or paragraph. Apply these checks before finalizing:

**Content checks:**
- [ ] The intended point is communicated clearly and completely
- [ ] The point is not already made in the surrounding text (no redundancy)
- [ ] Any new term, variable, or concept is defined inline
- [ ] If a finding: quantified where possible
- [ ] If a claim about the literature: supported by a citation

**Flow checks:**
- [ ] The first sentence of the insertion connects logically to the last sentence before it
- [ ] The last sentence of the insertion sets up the first sentence after it (or ends cleanly)
- [ ] No abrupt topic jumps within the insertion
- [ ] Transitions are specific, not mechanical ("Furthermore", "Moreover")

**Style checks:**
- [ ] Voice matches surrounding text and the project `## Authorship` setting (solo → "I"; coauthored → "we")
- [ ] Tense is consistent with surrounding text
- [ ] Sentence length is similar to the author's style
- [ ] No padding, weasel words, or unnecessary hedging
- [ ] No new notation or symbols introduced without definition

### Step 5 — Apply the edit to the .tex file

- **Insert** the new sentence or paragraph **at the specified line number** in the .tex file. The line that was at that position (and everything below) moves down.
- **Only if necessary for flow**, make minimal changes to the **immediately adjacent** line(s) (e.g. the line before or after the insertion) — for example, changing "In addition," to "Beyond that," to avoid redundancy with the new insertion. Do **not** change any other lines or any other part of the document.
- Use a single edit (e.g. one `search_replace`): the string that currently spans the insertion point (e.g. the line at the given line number, or the end of the previous paragraph plus the start of the next) is replaced by: [existing content that stays] + [new insertion] + [existing content that stays], with optional minimal tweaks to the boundary sentences only.

**Output format:** After applying the edit, report:

```
## Insertion applied

**File:** [path to .tex]
**At line:** [line number]

[The new sentence or paragraph that was inserted]

**Surrounding changes (if any):** [One sentence describing any minimal change to the line before/after, or "None — insertion only."]
```

---

## Section-Specific Norms

### Introduction insertions

Introductions in top journals are tightly structured (see `academic-introduction-evaluator`
skill for the full formula). When inserting into an introduction:
- New content should slot into an existing component (hook, research question, results,
  antecedents, value-added, identification, road map)
- Do not add a point that belongs in the body to the introduction
- Introduction sentences are typically more accessible and higher-level than body text;
  avoid technical notation and jargon
- If adding to the value-added section, frame the contribution relative to prior work
  ("Unlike [prior paper], we are able to...")

### Data section insertions

- Describe variables operationally (source, construction, unit of observation)
- Use past tense for data collection ("we obtained", "we constructed")
- Match the level of detail in surrounding variable descriptions

### Results section insertions

- State the finding first, then the mechanism or interpretation
- Include the column/table reference if relevant ("Column 3 of Table 4 shows...")
- Quantify effect sizes: use regression coefficients or economic magnitudes, not just
  significance ("the coefficient on X is 0.042, implying a [X] increase in Y for a
  one-standard-deviation increase in X")

### Conclusion insertions

- Conclusions restate, extend implications, or acknowledge limitations; they do not
  introduce new results
- Use present tense for implications ("our results suggest that...")
- Insertions about limitations should be concise and not undermine the paper's
  contribution

---

## Quality Checklist (run before finalizing)

- [ ] Inputs present: .tex path, line number, and point to communicate
- [ ] Point is clearly and fully communicated
- [ ] No redundancy with surrounding text
- [ ] Voice: first-person plural
- [ ] Tense: consistent with context
- [ ] No vague language ("somewhat", "relatively", "appears to")
- [ ] Quantified where the point involves a magnitude or effect size
- [ ] New terms defined inline
- [ ] First sentence of insertion connects to preceding text
- [ ] Last sentence of insertion connects to following text (or ends cleanly)
- [ ] No mechanical transitions ("Furthermore", "Moreover", "Additionally")
- [ ] Length is appropriate: a sentence if the point is minor; a paragraph if it is a distinct contribution or finding
- [ ] **Scope:** Only the specified line and immediately surrounding text are modified; no edits elsewhere in the file
