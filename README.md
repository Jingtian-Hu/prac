# Does bagging bananas in paper accelerate peel browning?

Matched-pair randomized experiment, GU4724 Experimental Research (Columbia, Fall 2026). Pre-analysis plan: `pap.md`. OSF registration: https://osf.io/ev87w/ (submitted 2026-11-04, registered commit 08dd3de). Write-up: `practicum.Rmd`; knitted report: `banana_paper_bag_report.pdf`.

## Scripts (`R/`)
- `01_power.R` — power simulations for the plan (Section 7 of `pap.md`)
- `03_measure_photos.R` — pre-registered measure: percent brown and brown_index from photos (parameters frozen at the registered commit)
- `02_randomize.R` — within-hand pairing and random assignment (seed 20261104); writes `data/assignment.csv` and `figures/design.png`
- `04_analysis.R` — paired estimate and randomization inference over all 2^16 assignments (the same calls are in `practicum.Rmd`)
- `06_alt_measure.R` — revised measure (post hoc): percent brown within a fruit outline; writes `data/brown_alt_fruitmask.csv`
- `05_before_after.R` — Day-0/endline overlay figures for the write-up (`figures/before_after_wide.png`, `figures/before_after.png`, `figures/fruit_mask_sheet.png`)

## Data (`data/`)
- `baseline.csv` — id, hand, organic status
- `assignment.csv` — pairs, assignment (Z), slots; written after registration by `02_randomize.R`
- `brown_from_photos_v1.csv`, `brown_by_side_v1.csv` — pre-registered measure, Day 0 and Day 3 (banana level and side level)
- `brown_alt_fruitmask.csv` — revised measure, Day 0 and Day 3
- `eye_vs_photo_day0.csv` — researcher's 1-5 eye ratings of the Day-0 photos
- `photos/day0/`, `photos/day3/` — both sides of every banana (`{id}_{a|b}.jpg`); each folder's `rename_log.csv` maps original photo files to banana ids

## Write-up
`banana_paper_bag_report.pdf` is the knitted report. `practicum.Rmd` computes every number in the report from the files above: measurement method, balance check, results table, randomization inference, figures, and all code in the appendix. A knit takes several minutes because the randomization distribution is enumerated in full several times.

## Departures from the pre-analysis plan
1. 2026-11-09. Revised measure added (`R/06_alt_measure.R`). The pre-registered peel test does not cover peel that has turned fully brown at Day 3, so a fruit-outline version of the measure is reported as a post hoc robustness check next to the pre-registered measure, which remains the confirmatory result.
2. The blind 1-7 ripeness grade listed as a secondary outcome was not collected.
3. The brown_index secondary outcome is in `data/brown_from_photos_v1.csv` but is not reported in the write-up, because it is built on the same peel test.
4. `04_analysis.R` reads `data/brown_from_photos_v1.csv` directly; the `data/outcomes.csv` file it originally named was never produced.
