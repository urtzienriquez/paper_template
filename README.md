# R Markdown Paper Template

A template for scientific papers written in **R Markdown**, knitted by
[knitrmini](https://github.com/urtzienriquez/knitrmini) into clean, publication-ready LaTeX (no
pandoc template: the prose goes through pandoc, the chunks as LaTeX, the document from a few YAML
keys), with an APA bibliography, line numbers, appendices with their own references and numbering,
and figures at the end when a journal asks for it.

It is made for [manuscript.nvim](https://github.com/urtzienriquez/manuscript.nvim), which builds it,
exports it to Word and back, and makes the files a journal asks for (anonymous or not).

---

## File structure

```
.
├── 0-index.Rmd          Entry point: its YAML header, the setup chunk, the parts
├── 1-main-text.Rmd      Main text
├── 2-appendix1.Rmd      Appendix 1 (its own title block, references, numbering: Fig. S1.1)
├── 00_preamble.tex      The LaTeX preamble (and the switches of the variants)
├── 01_metadata.tex      Title, authors and affiliations (the authors: left out of an anonymous version)
├── title_page.tex       The title page, for journals that ask for it apart (a document of its own)
├── cover_letter.tex     The cover letter (a document of its own)
└── .manuscript.lua      manuscript.nvim's options for this paper: a journal's variant
```

## The YAML header

knitrmini reads a few keys:

```yaml
documentclass: article
classoption: 12pt
preamble: 00_preamble.tex        # LaTeX files read before the document
bibliography:
  - /home/urtzi/Documents/zotero.bib
  # - packages.bib                # R packages' citations, once knitrmini::write_pkg_bib() wrote it
```

The title and authors are LaTeX (`01_metadata.tex`, with `authblk`), so that an
anonymous version can leave the authors out.

## With manuscript.nvim

`:Manuscript new paper_template paper` makes a paper from this template (with
`templates = "~/Templates"` in its setup). Then, from any of its files:

| Command | |
| --- | --- |
| `:Manuscript build` | the PDF of the part you are in (`main-text.pdf`), or of the whole |
| `:Manuscript build anon` | the same, anonymous; `review`: double spacing |
| `:Manuscript export` / `merge` | Word files for your collaborators, and their edits back |
| `:Manuscript submit geb` | the files for a journal: PDFs, and a zip of the LaTeX that compiles them |
| `:Manuscript diff @geb` | the tracked changes since that submission |
| `:Manuscript respond` | the response to the reviewers, from their comments |

The switches (`\ifanonymous`, `\iffiguresatend`, `\ifdoublespacing`, `\ifdraftversion`) are set by the
variant a build is made with, and are all off when the paper is knitted by hand. A journal's
variant goes in `.manuscript.lua`:

```lua
return {
  variants = {
    geb = { anonymous = true, figuresatend = true },
  },
}
```

With `figuresatend`, the main text's figures go to its end (endfloat), with their captions; the
appendices keep theirs in place (`\stopEndfloat` in `2-appendix1.Rmd`).

## Knitting by hand

```r
knitrmini::knit("0-index.Rmd", engine = "pdflatex") # (or "lualatex": both work; pdfLaTeX is faster)
```

## Dependencies

- R with knitrmini (a version that knits `.Rmd` files) and pandoc
- LaTeX with `latexmk`, `biber`, `biblatex`, `authblk`, `endfloat`, `lineno`, `siunitx`
