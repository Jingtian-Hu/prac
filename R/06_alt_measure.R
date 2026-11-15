# Revised measure: percent brown within a fruit outline (post hoc; added after the endline photos
# were processed, not in the pre-analysis plan). Reported next to the pre-registered measure.
#
# The pre-registered peel test in R/03_measure_photos.R keeps only saturated yellow/orange pixels and
# the black spots next to them. On heavily browned endline bananas, large areas of dull brown peel fail
# that test and are left out of the measure entirely. This script defines the fruit as
# the pre-registered peel plus dark brown pixels touching it (brightness < 0.42, hue < 0.12), closed
# with a ~50-pixel morphological closing so that brown patches enclosed by peel are filled in, and
# eroded by the same 4 pixels; any remaining hole enclosed by fruit on all four sides is filled.
# Cast shadows on the paper are lighter (brightness ~0.5) and lie outside the outline, so they are not
# counted. Glare and white paper (saturation < 0.15, brightness > 0.75) are left out of both counts.
# Percent brown = 100 x (fruit pixels that are not clean yellow peel) / (fruit pixels), where clean
# yellow peel is the pre-registered script's peel & !brown. Pixels the pre-registered rule accepted as
# peel keep their classification; pixels it did not accept as peel (dull brown areas, stem and tip
# ends) enter the numerator and the denominator together.
#
# Run with Rscript to write data/brown_alt_fruitmask.csv (id, day, brown_alt; mean of the two sides).
# source() only loads the functions.
source("R/03_measure_photos.R")   # loads classify(), boxmean() and PARAMS only

alt_classify <- function(file, p = PARAMS) {
  r <- classify(file, p)
  hsv <- rgb2hsv(as.vector(r$img[, , 1]), as.vector(r$img[, , 2]), as.vector(r$img[, , 3]),
                 maxColorValue = 1)
  h <- hsv["h", ]; s <- hsv["s", ]; v <- hsv["v", ]
  d <- r$d
  inner <- as.vector(outer(1:d[1], 1:d[2], function(i, j)
    i > p$margin * d[1] & i < (1 - p$margin) * d[1] &
    j > p$margin * d[2] & j < (1 - p$margin) * d[2]))
  M      <- function(x) matrix(as.numeric(x), d[1], d[2])
  dilate <- function(x, k) as.vector(boxmean(M(x), k)) > 0
  erode  <- function(x, k) as.vector(boxmean(M(x), k)) >= k^2 - 0.5
  # Dark brown/black pixels touching the peel (cast shadows on the paper are lighter, v ~ 0.5)
  dark   <- v < 0.42 & h < 0.12 & inner & dilate(r$peel, 31)
  # Morphological closing (~50 px) fills brown patches enclosed by peel without reaching the shadows
  fruit0 <- erode(dilate(r$peel | dark, 101), 101) & inner
  kk     <- 2 * p$erode + 1                                     # same erosion as the peel mask
  fruit  <- erode(fruit0, kk) & !(s < 0.15 & v > 0.75)          # drop white paper and glare (not counted either way)
  # Fill holes: a pixel enclosed by fruit on all four sides (same row and same column) is fruit.
  # The open side of the banana's curve is not enclosed on all four sides, so it stays out.
  F  <- M(fruit) > 0
  cm <- function(x) as.logical(cummax(x))
  lr <- t(apply(F, 1, cm)) & t(apply(F[, ncol(F):1], 1, cm))[, ncol(F):1]
  ud <- apply(F, 2, cm) & apply(F[nrow(F):1, ], 2, cm)[nrow(F):1, ]
  fruit  <- fruit | (as.vector(lr & ud) & inner & !(s < 0.15 & v > 0.75))
  clean  <- r$peel & !r$brown
  list(img = r$img, d = d, fruit = fruit | clean, brown = fruit & !clean)
}

alt_pct <- function(file, p = PARAMS) {
  r <- alt_classify(file, p)
  100 * sum(r$brown) / sum(r$fruit)
}

if (sys.nframe() == 0) {
  files <- list.files("data/photos", pattern = "\\.jpe?g$", recursive = TRUE, full.names = TRUE)
  out <- data.frame(
    id   = as.integer(sub("_.*", "", basename(files))),
    day  = as.integer(sub(".*day(\\d+).*", "\\1", files)),
    brown_alt = sapply(files, alt_pct)
  )
  res <- aggregate(brown_alt ~ id + day, out, mean)
  write.csv(res, "data/brown_alt_fruitmask.csv", row.names = FALSE)
}
