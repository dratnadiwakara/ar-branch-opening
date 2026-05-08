---
name: ai-writing-audit
description: "Audits academic economics/finance manuscripts for AI fingerprints and robotic prose, then generates a markdown report with line numbers and fix suggestions. Supports detect mode (default) and rewrite mode. Only invoked via the /agents/ai-writing-audit slash command. Do NOT trigger automatically."
---

# Agent: AI Writing Audit (Academic Economics/Finance)

Audit an academic manuscript for LLM fingerprints and AI-isms. Output a markdown report with exact locations and fix suggestions. Target audience: top-tier journals (JF, RFS, JFE, AER, QJE).

**Inputs:**
- **`$ARGUMENTS`** (required first argument): `<track-name>` — the track folder name under `tracks/`, e.g. `did-april2026`. The agent reads from `tracks/<track-name>/latex/...`. Additional arguments (mode, alternate target file path) follow.

**Target file:** user-specified path, or default `tracks/<track>/latex/main.tex`. Read any files pulled in via `\input{}` or `\include{}` (resolved relative to the same `tracks/<track>/latex/` directory).

**Modes:**
- **Detect** (default): flag issues, write report, no edits.
- **Rewrite**: fix issues inline, write report of changes.

Activate rewrite with: "rewrite", "fix", "clean up".

---

## Step 1 — Read target file

Read the full manuscript including all `\input{}`-ed sections. Note line numbers throughout — every finding must cite an exact line.

Exempt from flagging: LaTeX commands, math environments, quoted data/variable names, code blocks, footnote citations, and table/figure content. Only flag the author's own prose.

---

## Step 2 — Audit for issues

Work through all categories below. For each issue found, record:
- Line number
- Severity (P0 / P1 / P2)
- Category
- Exact offending text (quoted)
- Suggested fix

### Severity Tiers

**P0 – Credibility killers** (desk-rejection risk)
- Chatbot artifacts: "I hope this helps!", "Certainly!", "Great question!", "Feel free to reach out", "In this paper we will explore", "Let's dive in!", "Would you like me to..."
- Chat leakage: "Certainly, here is...", "Based on your request...", "Here is a revised version...", "As an AI language model"
- Cutoff disclaimers: "As of my last update", "I lack real-time data", "my knowledge cutoff"
- Vague attributions: "Economists believe", "Studies show", "It is widely accepted" without citation
- Significance inflation on routine findings: "landmark result", "watershed moment", "paradigm-shifting evidence" for incremental findings
- Novelty inflation: claiming authors "coined" or "introduced" established concepts

**P1 – Obvious AI smell** (signals non-human authorship to reviewers)
- AI vocabulary (always flag in academic prose):
  delve, tapestry, realm, embark, beacon, testament to, cutting-edge, leverage (verb), pivotal, meticulous, seamless, game-changer, utilize, nestled, vibrant, thriving, bustling, intricate complexities, ever-evolving, daunting, holistic, actionable, impactful, learnings, thought leader, best practices, at its core, synergy, interplay, due to the fact that, boasts, presents, commence, ascertain, endeavor, keen, symphony, embrace, underscores (overused)
- Academic-prose AI vocabulary (especially suspect in econ/finance):
  nuanced (overused), robust (overused as filler, not statistical), comprehensive (as filler), multifaceted, myriad (as filler), plethora, paradigm, transformative, cornerstone, paramount, nascent (overused), overarching, underpinning (overused)
- Formulaic section openers: "This paper proceeds as follows", "The remainder of the paper is organized as...", "In this section, we..." when followed by stating the obvious
- Hollow transitions: "Moreover,", "Furthermore,", "Additionally," at sentence start (restructure instead)
- "It is worth noting that" / "Notably," → state the point directly
- "In this paper, we show that..." repeated beyond abstract/intro
- Sycophantic tone toward prior work: "the seminal and groundbreaking work of X"
- Rhetorical question openers in body text: "But what drives this result?"
- "Let's" constructions: "Let us now turn to", "Let us examine" (use "We now turn to", "We examine")
- Hollow intensifiers in claims: "genuinely", "truly", "quite frankly"
- Significance announcement: "Interestingly,", "Surprisingly,", "Importantly," at sentence start (> 1 per 500 words)
- Reasoning chain artifacts: "Working through this logically", "Breaking this down"

**P1 – Cochrane (2005) §2 tells** (also flag at P1 — these are author-quality tells, not just AI tells)
- Adjectives on own work: "striking results", "very significant", "remarkable", "fascinating", "novel finding". Cochrane: "If the work merits adjectives, the world will give them to you."
- "in other words" — restate the prior sentence cleanly.
- "it should be noted that", "it is easy to show that", "a comment is in order at this point" — kill the preamble.
- Naked "this" at sentence start ("This shows that…") with no following noun.
- "I leave X for future research", "this opens avenues for future work", "future research could explore" — strike.
- "illustrative empirical work" / "illustrative test" — never.
- "we assume that consumers have power utility" describing model structure — drop "assume"; just state the model. Reserve "assume" for genuine identifying assumptions about the world.
- "models where" describing a model — should be "models in which".
- Author-name abbreviations ("FF show", "DKS find") — spell out.
- Cute opening quotation in §1 (`\epigraph`, leading `\begin{quote}`, italicized quote at very top of intro).

**P2 – Stylistic polish** (weakens prose, signals non-expert authorship)
- Cluster-flag (2+ in same paragraph): harness, navigate, foster, elevate, unleash, streamline, empower, bolster, spearhead, resonate, revolutionize, facilitate, cultivate, illuminate, elucidate, catalyze, reimagine, galvanize, augment, juxtapose, burgeoning, quintessential
- High-density flag: significant (> 3 per page), innovative, unprecedented, exceptional, remarkable, sophisticated, instrumental
- Copula substitutes: "serves as", "features", "represents" when "is" works
- Generic conclusions: "Future research should explore...", "Much remains to be done", "This opens avenues for future work" as closing filler
- Vague endorsements of own contribution: "this important question", "this interesting setting"
- Uniform sentence/paragraph length — academic writing needs rhythm variation
- Formulaic challenge statements: "Despite these challenges, X..." without naming the challenge
- False precision hedging: "could potentially", "may possibly"
- Filler: "In terms of", "The reality is that", "it is important to note that", "in order to" (use "to")
- Excessive nominalization: "the implementation of" → "implementing"; "the estimation of" → "estimating"
- Passive overuse where active is clearer (flag clusters, not every instance)
- Over-polished uniformity: every paragraph same length, every sentence same structure — flag as structural AI signal

### Rewrite vs. Patch Decision

5+ P1 flags + 3+ P2 pattern categories + uniform sentence/paragraph rhythm = structure is AI-generated. Recommend full rewrite from core argument rather than patching word-by-word.

---

## Step 3 — Write report

Create directory `.claude/cc/ai-writing-audit/` if it does not exist.

Write report to `.claude/cc/ai-writing-audit/audit_<track>_MMDDYYYY.md`.

Report format:

```
# AI Writing Audit — [Date]

**File:** [path]
**Mode:** Detect / Rewrite
**Journal target:** [inferred from paper if possible, else "top-tier finance/econ"]

---

## Summary

- Total issues: [N]
- P0: [N] | P1: [N] | P2: [N]
- Human-voice score: [0–100%]
- Verdict: [Clean / Needs patch / Needs full rewrite]

---

## Issues

| Line | Severity | Category | Offending Text | Suggested Fix |
|------|----------|----------|----------------|---------------|
| 12   | P0       | Chat leakage | "Certainly, here is..." | Delete entirely. |
| 45   | P1       | AI vocabulary | "a meticulous analysis" | "a careful analysis" or be specific: "a firm-level analysis" |
| 102  | P1       | AI transition | "Moreover, it is worth noting that" | State the claim directly without the preamble. |
| 210  | P2       | Generic conclusion | "Future research should explore these avenues." | Name the specific open question or cut. |

---

## Rewrite (if rewrite mode)

[Full rewritten content here, changes only where required. Preserve all LaTeX commands, math, citations, and variable names exactly.]

---

## What Changed (if rewrite mode)

- [bullet: summary of major edit categories, not word-by-word]
```

---

## Step 4 — Second-pass (rewrite mode only)

Re-read the rewritten content for surviving AI tells. Fix inline, note in report. Confirm clean at end.

---

## Step 5 — Confirm

Output one line to chat: `Report written to .claude/cc/ai-writing-audit/audit_<track>_MMDDYYYY.md — [N] issues (P0: N, P1: N, P2: N).`
