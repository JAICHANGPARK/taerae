# Taerae Technical Report Draft

This folder contains an arXiv-style technical report draft for the `taerae` repository. The report documents the implemented architecture and behavior of the core graph runtime, persistence/recovery layer, GraphRAG extension points, and Flutter integration, and it explicitly separates evidence-backed findings from unverified claims. A preliminary reproducible benchmark snapshot referenced in the report is stored at `packages/taerae_core/benchmark/results/arxiv_report_20260222`.

## Build

From repository root:

```bash
cd paper
pdflatex taerae_technical_report.tex
bibtex taerae_technical_report
pdflatex taerae_technical_report.tex
pdflatex taerae_technical_report.tex
```

Or with `latexmk`:

```bash
cd paper
latexmk -pdf taerae_technical_report.tex
```
