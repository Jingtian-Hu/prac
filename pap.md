# Pre-Analysis Plan: Does Bagging Bananas in Paper Accelerate Peel Browning?

**Author:** Jingtian Hu
**Course:** GU4724 Experimental Research (Prof. Donald Green), Fall 2026 — practicum experiment
**Status:** Registered by Git commit before random assignment. The commit hash and timestamp of this file serve as the registration record.
**Date registered:** 2026-11-03 (fill in exact time of commit: `____`)

> **Revision before registration (2026-11-03 evening).** 32 bananas in 6 hands, not 31 in 5. No pilot banana: the image-analysis parameters were calibrated on the Day-0 photos of all 32 bananas against the researcher's visual ratings, before assignment and before any outcome existed, and are frozen at the registered commit (no v2). `02_randomize.R` was test-run on these baseline data with the same seed while debugging; the registered run reproduces it. Outcomes are measured once, on Day 3 (72 h after bagging); there are no daily follow-up photos.

> Items marked `[FILL]` are completed on the morning of Day 0 **after** baseline measurement and **before** running `R/02_randomize.R`. No outcome data exist at the time of registration.

---

## 1. Research question and hypothesis

**Question.** Does storing an individual banana in a closed kraft paper bag at room temperature accelerate peel browning, relative to leaving it uncovered in the same room?

**Hypothesis (directional, but tested two-sided).** Bagging increases the share of peel area that is brown on the primary measurement day. Proposed mechanism: bananas emit ethylene; a paper bag traps ethylene near the fruit and accelerates ripening.

**Estimand.** The average treatment effect among the 32 experimental bananas,
ATE = (1/32) Σᵢ [Yᵢ(1) − Yᵢ(0)],
where Yᵢ(1) is banana *i*'s percent brown peel area on the primary day if bagged and Yᵢ(0) if not bagged.

The treatment is a bundle. A paper bag changes ethylene concentration, humidity, and light exposure at once. The experiment identifies the effect of the bundle, not of any single mechanism.

## 2. Units and sample

- 32 bananas, bought on 2026-11-03 from one store, in 6 hands: 18 conventional (hands of 6/5/7, ids 1–18) and 14 USDA Organic (hands of 5/3/6, ids 19–32).
- At least one hand is labeled USDA Organic and has a different crown wrap. Hands differ visibly in ripeness at purchase.
- Pre-treatment history: the bananas were refrigerated for about `[FILL]` hours after purchase on 2026-11-03, then returned to room temperature for about `[FILL]` hours before Day 0. Both arms share this history because it happened before assignment.
- No pilot banana. Experimental N = 32 (16 pairs).

## 3. Treatment and control

- **Treatment (Z = 1):** the banana alone in one standard kraft paper lunch bag `[FILL: bag brand/size]`, with the opening folded over twice. It is placed in its assigned table slot.
- **Control (Z = 0):** the banana lies uncovered in its assigned table slot.
- **All units:** the hands are separated at the crown on Day 0 so that every banana is a single fruit with a comparable cut. All units are in the same room in 16 slots, each made of two letter-size white sheets side by side, one banana per sheet (slots randomly assigned to pairs; layout: `[FILL]`), with at least 10 cm between any two objects (actual spacing: `[FILL]`), away from other fruit, with the door open and no fan blowing on them. Room temperature is logged daily.
- **Handling:** between Day 0 and Day 3 no banana is touched; treated bananas stay sealed in their bags. Bag condition is checked visually each day without opening the bags.

## 4. Pilot selection, blocking, and random assignment

Implemented in `R/00_pick_pilot.R` (seed `20261103`), `R/03_measure_photos.R`, and `R/02_randomize.R` (seed `20261104`). Steps, in order:

1. **Label** each banana 01–32 on the stem and record its hand (`bunch` = 1–6).
2. **Baseline** (Day 0, before assignment): photos of both sides and weight (g), recorded in `data/baseline.csv`. A 1–7 color grade is also recorded, for description only.
3. **No pilot.** `00_pick_pilot.R` is not used.
4. **Measurement calibration (v1, final).** The parameters of `03_measure_photos.R` were set on the Day-0 photos of all 32 bananas, checked against the researcher's 1–5 visual ratings of the 64 photos (Spearman 0.78; `data/eye_vs_photo_day0.csv`), and frozen at the registered commit. `brown0_v1` is the Day-0 percent brown from this script.
5. **Within-hand pairing** (`02_randomize.R`). Within each hand, sort the bananas by `brown0_v1`, then by photo-measured greenness (`hue0_v1`, the mean hue of non-brown peel; this breaks ties among bananas with no spots), then `weight0`, and pair adjacent bananas. In each of the four hands with an odd count, one banana is set aside at random. The four set-aside bananas are paired across hands within organic status (conventional with conventional, organic with organic), sorted by `brown0_v1`. The result is 16 pairs.
6. **Assignment.** In each of the 16 pairs, one banana is assigned to treatment with probability 1/2 (`randomizr::block_ra(blocks = pair)`).
7. **Placement.** The 16 slots (each two letter-size sheets side by side) are randomly assigned to pairs, and left/right position within a slot is randomized. Both members of a pair sit in the same slot, so local conditions such as window or radiator exposure difference out within pairs.

Disclosure: `02_randomize.R` was test-run on these baseline data with seed 20261104 before registration, while debugging the pipeline. The registered run reproduces that test run exactly; the assignment is generated by the script with no manual input.

**Assignment output:** `data/assignment.csv` (id, bunch, pair, Z, slot, side), committed right after the script is run.

## 5. Outcomes

### Primary outcome
**Percent of visible peel area that is brown on Day 3** (72 hours after bagging), averaged over the two photographed sides. Outcomes are measured once; the original plan of daily photos through Day 7 was dropped before registration for feasibility.

### Measurement protocol
- Photos are taken on Day 0 and Day 3 at about 17:00, under the same lamp, against a white paper background, with the phone at a fixed height and auto-HDR off.
- File names: `data/photos/day{d}/{id}_{a|b}.jpg`. File names carry the banana ID only, never the treatment arm. No labels appear in the frame.
- Percent brown is computed by `R/03_measure_photos.R`: peel pixels are identified by saturation and hue; a peel pixel is brown if its brightness is below 0.75 × the brightest peel within about 1 cm and its hue is below 0.115, or its hue is below 0.09, or its brightness is below 0.3. **The parameters are frozen at the registered commit and will not be re-tuned.** The same script gives `brown_index`, a threshold-free mean darkness of peel relative to local clean peel. The covariate `brown0` equals `brown0_v1`.

### Secondary outcomes (reported, but not the basis of the main conclusion)
1. The 1–7 ripeness grade on the Day-3 photos, rated by a person who does not know the assignment.
2. `brown_index` on Day 3.

## 6. Analysis plan

Implemented in `R/04_analysis.R`.

1. **Estimator.** The mean of the 16 within-pair differences, d̄ = (1/16) Σⱼ (Y_treated,j − Y_control,j). With equal pair sizes and p = 1/2, this equals the block-weighted difference in means (FEDAI eq. 3.10).
2. **Standard error.** SE = √[ Σⱼ (dⱼ − d̄)² / (16 × 15) ]. This is conservative when effects are heterogeneous.
3. **Hypothesis test.** The sharp null of no effect for any banana, Yᵢ(1) = Yᵢ(0). Randomization inference enumerates all 2¹⁶ = 65,536 possible assignments (`ri2::conduct_ri` with the full permutation matrix). Two-sided p-value = share of assignments with |estimate| ≥ |observed estimate|. α = 0.05.
4. **Confidence interval.** Assume a constant effect equal to the estimate, impute the full schedule of potential outcomes, and take the 2.5th and 97.5th percentiles of the randomization distribution (FEDAI ch. 3).
5. **Covariate-adjusted estimate (secondary).** `lm_robust(Y ~ Z + brown0_c, fixed_effects = ~ pair)` plus the matching randomization-inference test. It is reported next to the primary estimate. The primary estimate is the main result whatever the adjusted estimate shows.
6. **Secondary outcomes** use the same estimator and test, and are labeled secondary. There is no multiple-comparison correction, and no conclusion rests on them.
7. **Exploratory (labeled as such).** (a) Treatment effects by hand, by organic vs. conventional (7 vs. 8 within-hand pairs), or by baseline ripeness above vs. below the median (FEDAI ch. 9). Descriptive only. (b) The number of uncovered neighbors within 30 cm of each banana, as a descriptive check on ethylene spillover (FEDAI ch. 8).

### Figures
- **Design figure** (made at randomization): baseline color grade by pair, colored by arm, faceted by hand.
- **Results:** the 16 pair differences with the estimate and its CI; mean percent brown by arm on Day 0 and Day 3; the randomization distribution with the observed estimate marked.

## 7. Power

Assumptions: SD of the primary outcome = 15 percentage points, a constant effect, α = 0.05 two-sided, and a randomization-inference test. Simulation with 16 pairs: 2,000 datasets × 2,000 sign-flips (`R/01_power.R`).

| Within-pair correlation ρ | τ = 5 pp | 10 pp | 15 pp | 20 pp |
|---|---|---|---|---|
| 0 (pairing uninformative) | 0.13 | 0.42 | 0.75 | 0.93 |
| 0.5 | 0.23 | 0.69 | 0.95 | 1.00 |
| 0.7 | 0.37 | 0.90 | 1.00 | 1.00 |

The approximate minimum detectable effect at 80% power with ρ = 0.6 is about 10 pp.

## 8. Deviations, noncompliance, and missing data

- **Bag noncompliance** (torn or open bag): logged daily in `data/daily_log.csv`. The analysis is intention-to-treat by original assignment. No unit switches arm and none is dropped (FEDAI ch. 5).
- **Rot:** a banana that rots or splits counts as 100% brown and is not treated as missing.
- **Loss** (eaten, dropped, or destroyed): the whole pair is dropped from the primary analysis. Extreme-value bounds are reported, with the missing banana set to 0% and to 100% brown (FEDAI ch. 7).
- **Other deviations:** any departure from this plan is recorded in `README.md` with its date and reason, and is reported in the essay.

## 9. Timeline

| Date | Step |
|---|---|
| 2026-11-03 (Day 0) | Baseline photos → calibrate and freeze `03_measure_photos.R` → `brown0_v1` for all 32 → fill `[FILL]` fields → **commit + OSF registration** → `02_randomize.R` → commit `assignment.csv` → bag and place |
| 11-04 to 11-05 (Days 1–2) | Visual bag check and room temperature only; bananas not touched |
| 11-06 (Day 3) | Outcome photos; blind 1–7 rating; run `03` and `04`; commit |
| 11-07 to 11-09 | 750-word essay |
