# Does bagging bananas in paper accelerate peel browning?

Matched-pair randomized experiment, GU4724 Experimental Research (Columbia, Fall 2026). Pre-analysis plan: `pap.md`. OSF registration: https://osf.io/ev87w/ (submitted 2026-11-04, registered commit 08dd3de).

- `R/03_measure_photos.R` — percent brown and brown_index from photos (parameters frozen at the registered commit)
- `R/02_randomize.R` — within-hand pairing and random assignment (seed 20261104)
- `R/04_analysis.R` — paired estimate and randomization inference over all 2^16 assignments
- `practicum.Rmd` — the write-up (knit to PDF); contains the measurement method, results figures, results table, balance check, appendix figures (including `figures/setup_day0.jpg`, the Day-0 layout), and all analysis code. Until Day-3 rows exist in `data/brown_from_photos_v1.csv` it runs on simulated placeholder outcomes and says so on the first page
- `data/baseline.csv`, `data/brown_from_photos_v1.csv`, `data/photos/day0/` — Day-0 data; `data/photos/day0/rename_log.csv` maps original photo files to banana ids
- `data/assignment.csv` — written after registration by `02_randomize.R`

## Deviations
(none yet)
