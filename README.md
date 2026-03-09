# RMarkdown Paper Template

A template for writing scientific papers in RMarkdown, with a custom LaTeX template, APA bibliography support, line numbers, figure handling, and an optional Word export pipeline.

---

## File structure

```
.
├── 0-index.Rmd              # Entry point — YAML header lives here
├── 1-main-text.Rmd          # Main manuscript text
├── 2-appendix1.Rmd          # Appendix (optional)
├── packages.bib             # Auto-generated R package citations
├── template/
│   ├── template.tex         # LaTeX template
│   └── filter-affiliations.lua  # Lua filter for author/affiliation numbering
└── toword/                  # Word export utilities (see below)
```

---

## YAML header options

### Title and output

```yaml
title: "Your paper title"

output:
  bookdown::pdf_document2:
    template: "./template/template.tex"
    keep_tex: true             # keep the intermediate .tex file
    latex_engine: xelatex
    citation_package: biblatex
    pandoc_args:
      - "--lua-filter=./template/filter-affiliations.lua"
      # - "--variable=mainfont:Latin Modern Sans"  # uncomment to change font
```

### Authors

Each author entry supports four fields:

```yaml
author:
  - name: "First Last"
    affiliation: "1"           # affiliation id(s), comma-separated: "1,2"
    corresponding: true        # mark as corresponding author
    email: "you@example.com"   # shown only if corresponding: true
  - name: "Second Author"
    affiliation: ""            # leave empty if no affiliation number needed
```

The Lua filter (`filter-affiliations.lua`) automatically renumbers affiliations in the order authors appear, so you don't need to manually keep IDs consistent.

### Affiliations

```yaml
affiliations:
  - id: "1"
    text: "Department, University, City, Country"
  - id: "2"
    text: "Another Institute, City, Country"
```

IDs can be arbitrary strings — the filter will renumber them sequentially in the final output.

### Bibliography

```yaml
bibliography:
  - /absolute/path/to/zotero.bib   # your main Zotero library
  - ./packages.bib                  # R package citations (optional)
```

To regenerate `packages.bib` from your currently loaded R packages, uncomment this line in the setup chunk of `0-index.Rmd`:

```r
# knitr::write_bib(c(installed.packages()), "./packages.bib")
```

### Figures at end

```yaml
figures_at_end: false   # true: collect all figures at end of document (journal style)
                        # false: figures appear inline
```

When `true`, the template uses the `endfloat` LaTeX package to move all figures to the end, with a "Figure Captions" list preceding them. The `\stopEndfloat` command (placed manually in `2-appendix1.Rmd`) stops this behaviour for appendices.

### Render params

Control which child documents get compiled:

```yaml
params:
  render_main: true        # render 1-main-text.Rmd
  render_appendix1: false  # render 2-appendix1.Rmd
```

Set `render_appendix1: true` to include the appendix in the compiled PDF.

---

## Word export

The `toword/` folder contains a shell utility for converting the compiled `.tex` to `.docx` via pandoc. Copy your `.tex`, `.bib`, and `.csl` files into `toword/` and source the script:

```bash
source toword/convert-utils.sh
toword -i manuscript.tex -o manuscript.docx        # basic
toword -m -i manuscript.tex -o manuscript.docx     # move figures to end
```

**Dependencies for Word export:** `pandoc`, `pandoc-crossref`, and the Lua filters in `toword/`.

The `fix-titleblock.lua` filter reconstructs the title block at the correct position in the Word document. You will need to update the `PAPER_TITLE` variable inside that file to match your paper's title.

---

## Dependencies

- R packages: `rmarkdown`, `bookdown`, `knitr`
- LaTeX: XeLaTeX distribution with `biblatex`, `biber`, `endfloat`, `lineno`, `siunitx`
- Pandoc ≥ 2.19.1 (for Word export)
