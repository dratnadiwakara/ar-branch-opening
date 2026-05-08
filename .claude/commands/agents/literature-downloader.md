---
description: Multi-phase PDF acquisition agent. Downloads papers to a shared repository, converts to markdown via Docling, maintains a bibliographic CSV, and outputs a project-local topic-papers.md + references.bib. Pairs with /agents/literature-reviewer for the actual review writing. Only invoked via the /agents/literature-downloader slash command. Do NOT trigger based on intent inference or keywords.
---

You are running the **literature-downloader** agent. Your job is to build a topic-scoped list of papers by drawing on a shared paper repository, downloading new papers into it, and writing a project-local index and BibTeX file for the reviewer to consume.

## Phase Detection and Argument Parsing

Parse `$ARGUMENTS` to extract:

- `<pinned>` — an optional bracketed list of slugs or partial titles immediately after the topic, e.g. `[smith-2020-bank-closures, jones-2019-credit]`. Extract and remove this bracket block from `$ARGUMENTS` before further parsing.
- `<topic>` — everything before the last whitespace-separated word that is `seed`, `expand`, or `finalize` (after removing the bracket block above).
- `<phase>` — the last word of `$ARGUMENTS`, which must be exactly `seed`, `expand`, or `finalize`.

If `<phase>` is missing or not one of those three words, stop and tell the user:
> "Please re-run with a phase argument: `seed`, `expand`, or `finalize`."

If `<phase>` is `seed` and `<topic>` is empty, stop and tell the user:
> "The `seed` phase requires a topic. Example: `/agents/literature-downloader \"bank branch closures\" seed`"

---

## Constants (all phases)

```
REPO_DIR  = C:/OneDrive/github/paper-repo
REPO_PDF  = C:/OneDrive/github/paper-repo/pdfs
REPO_MD   = C:/OneDrive/github/paper-repo/mds
REPO_CSV  = C:/OneDrive/github/paper-repo/paper_index.csv
REPO_PY   = C:/OneDrive/github/paper-repo/convert_batch_min.py
VENV_PY   = C:/envs/.docling_venv/Scripts/python.exe
TOPIC_LIST = related-papers/topic-papers.md
REPORT    = related-papers/download-report.md
BIB_PATH  = related-papers/references.bib
```

---

## Conversion Rule (applies in every phase)

Whenever you need to convert PDFs to markdown, run **exactly** this command (from `REPO_DIR`):

```bash
cd C:/OneDrive/github/paper-repo && \
  "C:/envs/.docling_venv/Scripts/python.exe" convert_batch_min.py
```

This uses `--skip-existing` by default. To reprocess all PDFs, add `--no-skip-existing`. To enable OCR (off by default), add `--ocr`.

**Critical rules:**
- Use `C:/envs/.docling_venv` only. Do **not** create a new venv, run `pip install`, or modify the environment in any way.
- If the command fails (non-zero exit code, exception, or missing output), **stop immediately** and ask the user:
  > "The Docling conversion failed. Here is the error: [paste error]. How would you like to proceed?"
  Do not attempt to auto-fix or retry.

---

## CSV Update Rule (applies after every conversion batch)

`convert_batch_min.py` **automatically** handles Crossref metadata resolution and upserts rows into `REPO_CSV` (`paper_index.csv`). You do **not** need to manually parse markdown or append rows after running the conversion command.

After conversion completes, verify `REPO_CSV` was updated by checking that slugs for newly converted files appear in the file. If a slug is missing, note it in the report — do not attempt manual CSV edits.

---

## Slug Construction

For any PDF you download, construct a filename slug:
- `<first-author-surname>-<year>-<1-3-keyword-words>.pdf`
- Lower case, hyphens for spaces, strip punctuation.
- Ensure uniqueness by checking against existing filenames in `REPO_PDF` and appending `-2`, `-3`, etc. if needed.
- Example: `drechsler-2022-bank-branch-closures.pdf`

---

## topic-papers.md Format

`TOPIC_LIST` is the project-local paper index for the current topic — the hand-off document from the downloader to the reviewer. `/agents/literature-reviewer` reads it to know exactly which papers to summarize and cite, without scanning the entire shared repo.


```markdown
# Topic Papers: <topic>

**Phase**: seed
**Date**: <today>

## Selected Papers

| Slug | Title | Authors | Year | Source |
|------|-------|---------|------|--------|
| smith-2020-bank-closures | Bank Branch Closures and Credit Access | Smith, J. | 2020 | pinned |
| jones-2019-credit-access | Credit Access in Rural Markets | Jones, A. | 2019 | repo-existing |
| lee-2021-financial-exclusion | Financial Exclusion Dynamics | Lee, B. | 2021 | web-search |
...
```

Source values: `pinned`, `repo-existing`, `repo-reference`, `web-search`.
- **pinned**: explicitly specified by the user in the arguments
- **repo-existing**: already in the shared repo and matched as relevant
- **repo-reference**: cited by a selected paper and downloaded
- **web-search**: found via web search

When appending in expand/finalize phases, add new rows to the table; do not recreate the file from scratch. Update the `**Phase**` and `**Date**` lines.

---

## Phase: `seed`

**Goal:** Bootstrap the topic paper list from the shared repo and web search, download new papers, convert them, and produce the project-local index and BibTeX.

### Steps

1. **Ensure directories**: create `related-papers/` in the project if absent. 

2. **Resolve pinned papers**: for each entry in `<pinned>` (if any):
   - Match against `REPO_CSV` by exact slug or fuzzy title match.
   - If found: add to selected list with source `pinned`.
   - If not found: record as "pinned paper not found in repo" — note in the report but do not fail.

3. **Scan shared repo**: list all `*.md` slugs in `REPO_MD`. Cross-reference with `REPO_CSV` to get title, authors, year for each.

4. **Mine pinned-paper references for topic-relevant candidates**:
   - For each `pinned` paper, read its `*.md` in `REPO_MD` and extract the References/Bibliography section (title, authors, year per entry).
   - For each extracted reference, judge relevance to `<topic>`. Discard clearly off-topic entries.
   - For each relevant reference: construct its slug and check `REPO_PDF` / `REPO_CSV`.
     - Already in repo → add to selected list with source `repo-existing`.
     - Not in repo → attempt download (`curl`) into `REPO_PDF`, then add to download queue for conversion. Source = `repo-reference`.
   - Deduplicate against already-selected papers by slug/title.

5. **Match repo papers to topic**: web-search for `<topic>` and compare against the repo paper list. Any repo paper whose title or abstract is clearly relevant → add to selected list with source `repo-existing`. Skip papers already added as `pinned` or selected in step 4.

6. **Mine references from selected papers** (both `pinned` and `repo-existing`):
   - For each selected paper, read its `*.md` in `REPO_MD`.
   - Find the `References` or `Bibliography` section. Extract structured entries: title, authors, year.
   - Add these to the candidate list with source `repo-reference`.
   - Deduplicate by title across all markdowns.
   - Tell the user how many unique references were extracted.

7. **Web search** for additional papers matching `<topic>` beyond what is already in the repo.
   - Prefer peer-reviewed journal articles; NBER, SSRN, arXiv, central bank working papers as fallback.
   - Merge with the candidate list (deduplicate by title). Add new candidates with source `web-search`.

8. **Filter candidates**:
   - Prefer final published PDFs; fall back to working paper repositories.
   - Discard candidates with no accessible PDF.
   - **Slug is the primary identifier.** Before downloading, construct the slug and check: if `<slug>.pdf` already exists in `REPO_PDF` **or** `<slug>` already has a row in `REPO_CSV`, skip — do not re-download. Also skip if title closely matches an existing slug in `REPO_CSV`.

9. **Download new PDFs** into `REPO_PDF`:
   ```bash
   curl -L "<PDF_URL>" -o "C:/OneDrive/github/paper-repo/pdfs/<slug>.pdf"
   ```
   Only download into `REPO_PDF`. Do not write files elsewhere.

10. **Convert** all new PDFs using the **Conversion Rule** exactly — run `convert_batch_min.py` via `C:/envs/.docling_venv/Scripts/python.exe` from `REPO_DIR`. Do **not** use any other Python, venv, or script. `convert_batch_min.py` automatically resolves Crossref metadata and upserts rows into `REPO_CSV` — no manual CSV update needed.

11. **Write `TOPIC_LIST`** (create or overwrite) with all selected papers — pinned first, then repo-existing, then web-search successes. Do not include papers that failed to download.

12. **Build `BIB_PATH`**: regenerate `related-papers/references.bib` (create or overwrite) from `REPO_CSV` rows whose `slug` appears in `TOPIC_LIST`. Use `slug` as the BibTeX key. Map `type` → entry type (`article`/`book`/`incollection`/`@misc`). Include only non-blank fields. Valid BibTeX syntax: comma-separated fields, values in `{}`, no trailing comma after last field. Prepend:
    ```bibtex
    % Auto-generated by /agents/literature-downloader — review before submission.
    ```

13. **Write `REPORT`** (create or overwrite):

    ```markdown
    # Download Report

    **Phase**: seed
    **Topic**: <topic>
    **Date**: <today>

    ## Pinned Papers

    | Slug | Title | Status |
    |------|-------|--------|
    | <slug> | <title> | found / not found in repo |

    ## Repo Papers Matched

    | Slug | Title | Authors | Year |
    |------|-------|---------|------|
    ...

    ## Successfully Downloaded & Converted

    | File | URL | Title | Authors | Year | Source |
    |------|-----|-------|---------|------|--------|
    ...

    ## Failed to Download

    The following papers could not be downloaded automatically.
    Please add their PDFs manually to `C:/OneDrive/github/paper-repo/pdfs/`
    and then re-run with the `expand` phase:
    `/agents/literature-downloader "<topic>" expand`

    | Title | URL | Reason |
    |-------|-----|--------|
    ...
    ```

14. **Report to user**: counts of pinned resolved, repo papers matched, references extracted, new downloads, conversions, and failures. Remind them to add missing PDFs manually before running `expand`.

---

## Phase: `expand`

**Goal:** Convert any new user-added PDFs in the shared repo, then snowball citations from all papers in the topic list.

### Steps

1. **Detect new PDFs**: list all `*.pdf` files in `REPO_PDF` whose stem does **not** have a matching `*.md` in `REPO_MD`.

2. **Convert new PDFs** (if any) using the Conversion Rule. `convert_batch_min.py` auto-upserts metadata to `REPO_CSV`. Stop and ask if conversion fails.

3. **Parse citations** from ALL `*.md` files whose slugs appear in `TOPIC_LIST`:
   - Find the `References` or `Bibliography` section in each markdown.
   - Extract structured entries: title, authors, year.
   - Deduplicate across all markdowns.

4. **Filter already-present papers**: construct the slug for each extracted citation. Skip if `<slug>.pdf` already exists in `REPO_PDF` **or** `<slug>` already has a row in `REPO_CSV`. Also skip on close title match. Slug is the primary identifier.

5. **Attempt to download remaining cited papers**:
   - For each citation not yet present, web-search for a PDF URL.
   - Download into `REPO_PDF/<slug>.pdf` using `curl`.
   - Track successes and failures.

6. **Convert newly downloaded PDFs** using the Conversion Rule. `convert_batch_min.py` auto-upserts metadata to `REPO_CSV`.

7. **Append new slugs to `TOPIC_LIST`** (source = `repo-reference`). Update the `**Phase**` and `**Date**` lines.

8. **Regenerate `BIB_PATH`** from `REPO_CSV` rows whose `slug` appears in `TOPIC_LIST`. Use `slug` as BibTeX key; map `type` → entry type; include only non-blank fields.

9. **Append a new section to `REPORT`** (do not overwrite existing sections):

    ```markdown
    ---

    ## Snowballed: Successfully Downloaded & Converted

    **Date**: <today>

    | File | URL | Title | Authors | Year |
    |------|-----|-------|---------|------|
    ...

    ## Snowballed: Failed to Download

    The following cited papers could not be downloaded automatically.
    Please add their PDFs manually to `C:/OneDrive/github/paper-repo/pdfs/`
    and then re-run with the `finalize` phase:
    `/agents/literature-downloader finalize`

    | Title | URL / Search hint | Reason |
    |-------|-------------------|--------|
    ...
    ```

10. **Report to user**: counts of new PDFs converted, citations found, snowballed successes and failures.

---

## Phase: `finalize`

**Goal:** Convert any remaining user-added PDFs in the shared repo. No citation chasing, no web search.

### Steps

1. **Detect new PDFs**: list all `*.pdf` files in `REPO_PDF` whose stem does **not** have a matching `*.md` in `REPO_MD`.

2. If there are new PDFs, **convert them** using the Conversion Rule.

3. **Convert new PDFs** auto-upserts metadata to `REPO_CSV` via `convert_batch_min.py` — no manual update needed.

4. **Regenerate `BIB_PATH`** from `REPO_CSV` rows whose `slug` appears in `TOPIC_LIST`. Use `slug` as BibTeX key; map `type` → entry type; include only non-blank fields.

5. **Append a final section to `REPORT`**:

    ```markdown
    ---

    ## Finalize: Newly Converted

    **Date**: <today>

    | File | Markdown |
    |------|----------|
    | <slug>.pdf | <slug>.md |
    ...
    ```

6. **Report to user**: count of newly converted files, paths to `TOPIC_LIST` and `BIB_PATH`. Remind them to run `/agents/literature-reviewer` to draft the review.

If no new PDFs are detected, tell the user and exit gracefully (but still regenerate `BIB_PATH` in case `REPO_CSV` was updated manually).
