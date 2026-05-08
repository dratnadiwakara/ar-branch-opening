---
name: bib-validator
description: "Validate and correct BibTeX reference entries against Google Scholar. Only invoked via the /skills/bib-validator slash command. Do NOT trigger based on intent inference or keywords."
---

# BibTeX Validator Skill

Validate every entry in a `.bib` file against Google Scholar and produce a clean Markdown report showing the original entry, what was found on Scholar, and a corrected entry for each one.

---

## Environment

- **Use the global (system) Python installation.** Do not create or activate a virtual environment (venv). Run all Python and `pip` commands in the user's default environment.
- When installing dependencies, use `pip install <package>` (or `pip install <package> --break-system-packages` on systems that restrict modifying the system Python, e.g. some Linux distros). Do not use `python -m venv`, `source venv/bin/activate`, or equivalent.
- **Do not edit the user's .bib file.** The skill is read-only with respect to the bibliography. Parse and validate entries only; output must be a separate Markdown report (and optionally a separate corrected .bib file if the user requests one). Never overwrite, patch, or modify the original .bib file in place.

---

## Workflow

### Step 1 — Parse the .bib file

**`$ARGUMENTS`**: `<track-name>` (required) — the track folder name under `tracks/`, e.g. `did-april2026`. Default `.bib` path: `tracks/<track-name>/latex/main.bib`. The user may pass an explicit `.bib` path to override.

Read the `.bib` file (default `tracks/<track>/latex/main.bib`, or the path the user specified). Parse it into individual entries. Each entry starts with `@TYPE{CITEKEY,` and ends with a matching closing `}`.

Use Python with the `bibtexparser` library (install if needed, using global pip: `pip install bibtexparser` or `pip install bibtexparser --break-system-packages`). Extract for each entry:
- Citation key
- Entry type (article, book, inproceedings, etc.)
- All fields: title, author, year, journal/booktitle, volume, number, pages, doi, url, publisher, etc.

### Step 2 — Search Google Scholar for each entry

For each entry, use the `scholarly` Python library (install with global pip if needed: `pip install scholarly` or `pip install scholarly --break-system-packages`) to search Google Scholar.

**Build a targeted search query:**
- Primary: use `title` field if present — strip any LaTeX formatting (`{`, `}`, `\emph{}`, etc.) before searching
- Add first author's last name if available
- Add year if available
- Example query: `"Attention is All You Need" Vaswani 2017`

```python
from scholarly import scholarly
import time

def search_entry(entry):
    title = clean_latex(entry.get('title', ''))
    author = first_author_lastname(entry.get('author', ''))
    year = entry.get('year', '')
    query = f'{title} {author} {year}'.strip()
    
    try:
        results = scholarly.search_pubs(query)
        result = next(results, None)
        time.sleep(2)  # be polite, avoid rate-limiting
        return result
    except Exception as e:
        return None
```

**If `scholarly` is blocked or fails:** fall back to a `web_search` tool call using the query `site:scholar.google.com "{title}" {author}` or a plain Google Scholar URL fetch.

### Step 3 — Compare and build corrections

For each entry, compare the original fields against the Scholar result:

| Field       | Check for |
|-------------|-----------|
| `title`     | Capitalization, typos, missing subtitle |
| `author`    | Correct ordering, missing co-authors, name spelling |
| `year`      | Published vs. preprint year |
| `journal` / `booktitle` | Full official name vs. abbreviation |
| `volume`, `number`, `pages` | Missing or wrong values |
| `doi`       | Missing or incorrect DOI |
| `publisher` | Missing or wrong |

Build a `corrected` entry dict with all confirmed-correct fields. Mark any field that changed. If Scholar returns no result, mark the entry as **"Not verified — Scholar returned no match"** and leave the original unchanged.

### Step 4 — Write the Markdown report

Output a single `.md` file. Structure:

```
# BibTeX Validation Report
**File:** `references.bib`  
**Date:** YYYY-MM-DD  
**Entries checked:** N  
**Entries with corrections:** M  
**Entries not verified:** K  

---

## Summary Table

| # | Cite Key | Status | Fields Changed |
|---|----------|--------|----------------|
| 1 | author2017attention | ✅ Verified, corrections | title, pages |
| 2 | smith2020deep | ✅ Verified, no changes | — |
| 3 | unknown2019xyz | ⚠️ Not verified | — |

---

## Entry Details

### 1. `author2017attention`
**Status:** ✅ Verified — 2 field(s) corrected

**Original entry:**
```bibtex
@article{author2017attention,
  ...
}
```

**Scholar match:** "Attention Is All You Need" — Vaswani et al. (2017), NeurIPS

**Corrections made:**
- `title`: `attention is all you need` → `Attention Is All You Need`
- `pages`: missing → `5998--6008`

**Corrected entry:**
```bibtex
@article{author2017attention,
  ...
}
```

---
```

Repeat for every entry. Keep the code blocks as proper ` ```bibtex ` fenced blocks so the user can copy-paste directly.

### Step 5 — Save and present

Save the report as `.claude/cc/bib-validator/bib_validation_report_<track>_YYYY-MM-DD.md`,
using today's date in `YYYY-MM-DD` format. Ensure that the
`.claude/cc/bib-validator/` directory exists, creating it if necessary. Use
`present_files` to share it with the user. Do not write to or modify the original
.bib file.

---

## Helper Functions (reference implementations)

```python
import re

def clean_latex(text):
    """Strip LaTeX commands and braces from a string."""
    text = re.sub(r'\\[a-zA-Z]+\{([^}]*)\}', r'\1', text)  # \cmd{text} → text
    text = re.sub(r'[{}]', '', text)
    return text.strip()

def first_author_lastname(author_field):
    """Extract the last name of the first author."""
    if not author_field:
        return ''
    first = author_field.split(' and ')[0].strip()
    # Handle "Last, First" and "First Last" formats
    if ',' in first:
        return first.split(',')[0].strip()
    parts = first.split()
    return parts[-1] if parts else ''

def format_bibtex(entry_dict, entry_type, cite_key):
    """Format a dict back into a BibTeX string."""
    lines = [f'@{entry_type}{{{cite_key},']
    for k, v in entry_dict.items():
        if k not in ('ENTRYTYPE', 'ID'):
            lines.append(f'  {k} = {{{v}}},')
    lines.append('}')
    return '\n'.join(lines)
```

---

## Error Handling

- **Rate limiting / CAPTCHA from Scholar:** Add longer delays (`time.sleep(5)`), retry once, then fall back to web_search. Note in the report if a fallback was used.
- **`scholarly` install fails:** Use web_search with the query `"<title>" <author> site:scholar.google.com` and parse the snippet for metadata.
- **Entry parse error:** Skip the malformed entry, note it in the report as "⚠️ Parse error — skipped".
- **No Scholar match:** Mark as "⚠️ Not verified" and include the original entry unchanged in the corrected block so the user can still copy it.

---

## Status Legend

| Icon | Meaning |
|------|---------|
| ✅ Verified, no changes | Scholar confirmed — entry looks correct |
| ✅ Verified, corrections | Scholar found and corrections were applied |
| ⚠️ Not verified | No Scholar match found — manual review needed |
| ❌ Parse error | Entry could not be parsed from the .bib file |
