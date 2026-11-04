# Percent brown from photos: peel mask + "darkness relative to the brightest nearby peel" threshold
#
# Calibrated on the Day-0 photos of all 32 bananas (2026-11-03), checked against the researcher's
# 1-5 visual ratings of the 64 photos (Spearman 0.78; data/eye_vs_photo_day0.csv), and frozen at the
# registered commit. The parameters are not re-tuned after registration.
#
# Earlier rules that were rejected during calibration:
#   (1) global HSV threshold (v < 0.55 & h < 0.11): yellow peel in lamp shadow was classified brown
#       (median hue of yellow peel is about 0.11);
#   (2) "darker than the local mean": in densely speckled regions the local mean is itself brown,
#       so the reference collapses and large areas are missed.
# Current rule:
#   peel  = saturated yellow/orange pixels (s > peel_s, h < peel_h) plus very dark pixels adjacent to peel
#           (black spots); a border of width `margin` is cropped; the mask is eroded by `erode` pixels
#   ref   = brightest peel pixel within a (2w-1) x (2w-1) window (about 1 cm at step = 2) after 5-px smoothing,
#           i.e. the brightness of clean yellow peel in that neighbourhood; unaffected by one-sided lamp shading
#   brown = (brightness < k * ref and hue < yellow_h) or hue < brown_h (reddish brown) or brightness < dark_v
#           The hue gate (yellow_h) removes most ridge-line and back-facet shading, whose hue stays above 0.115.
# Mean-RGB / mean-brightness measures were also tried and rejected (rho with eye ratings 0.2-0.3;
# dominated by shading and exposure).
THRESHOLD_VERSION <- "v1"
library(jpeg)

PARAMS <- list(step = 2, peel_s = 0.4, peel_h = 0.2, dark_v = 0.3, brown_h = 0.09, yellow_h = 0.115,
               k = 0.75, w = 32, smooth = 5, erode = 4, margin = 0.04)

boxmean <- function(m, k) {   # k x k window sums via an integral image; truncated at the edges
  n <- nrow(m); p <- ncol(m); r <- k %/% 2
  I <- matrix(0, n + 1, p + 1); I[-1, -1] <- t(apply(apply(m, 2, cumsum), 1, cumsum))
  r1 <- pmax(1, 1:n - r); r2 <- pmin(n, 1:n + r); c1 <- pmax(1, 1:p - r); c2 <- pmin(p, 1:p + r)
  I[r2 + 1, c2 + 1] - I[r1, c2 + 1] - I[r2 + 1, c1] + I[r1, c1]
}

locmax <- function(M, w) {    # maximum within a (2w-1) x (2w-1) window (separable, doubling steps)
  run <- function(M, down) { F <- M; s <- 1
    while (s < w) { n <- nrow(F)
      sh <- if (down) rbind(F[-(1:s), , drop = FALSE], matrix(0, s, ncol(F))) else rbind(matrix(0, s, ncol(F)), F[1:(n - s), , drop = FALSE])
      F <- pmax(F, sh); s <- s * 2 }
    F }
  M <- pmax(run(M, TRUE), run(M, FALSE)); t(pmax(run(t(M), TRUE), run(t(M), FALSE)))
}

classify <- function(file, p = PARAMS) {
  img <- readJPEG(file)
  img <- img[seq(1, dim(img)[1], p$step), seq(1, dim(img)[2], p$step), ]   # subsample to save memory
  d <- dim(img)
  hsv <- rgb2hsv(as.vector(img[, , 1]), as.vector(img[, , 2]), as.vector(img[, , 3]), maxColorValue = 1)
  h <- hsv["h", ]; s <- hsv["s", ]; v <- hsv["v", ]
  sat   <- s > p$peel_s & h < p$peel_h
  near  <- as.vector(boxmean(matrix(as.numeric(sat), d[1], d[2]), 31)) > 0.3 * 31^2
  inner <- as.vector(outer(1:d[1], 1:d[2], function(i, j)
    i > p$margin * d[1] & i < (1 - p$margin) * d[1] & j > p$margin * d[2] & j < (1 - p$margin) * d[2]))
  peel0 <- (sat | v < p$dark_v) & near & inner
  kk    <- 2 * p$erode + 1
  peel  <- peel0 & as.vector(boxmean(matrix(as.numeric(peel0), d[1], d[2]), kk)) >= kk^2 - 0.5   # erosion
  vs    <- boxmean(matrix(v * peel0, d[1], d[2]), p$smooth) / pmax(boxmean(matrix(as.numeric(peel0), d[1], d[2]), p$smooth), 1)
  ref   <- as.vector(locmax(vs * matrix(peel0, d[1], d[2]), p$w))
  ratio <- v / pmax(ref, 1e-6)
  brown <- peel & ((ratio < p$k & h < p$yellow_h) | h < p$brown_h | v < p$dark_v)
  list(img = img, d = d, h = h, v = v, ratio = ratio, peel = peel, brown = brown)
}

# Percent brown: brown pixels / peel pixels
brown_pct <- function(file, p = PARAMS) { r <- classify(file, p); 100 * sum(r$brown) / sum(r$peel) }

# Continuous brown index (secondary, threshold-free): mean shortfall of peel brightness below 90% of the
# local clean-peel reference, x 100. 0 = as bright as clean peel everywhere; larger = more/darker browning.
brown_index <- function(file, p = PARAMS) { r <- classify(file, p); 100 * mean(pmax(0, 0.9 - r$ratio[r$peel]) / 0.9) }

# Greenness: mean hue of non-brown peel (yellow ~ 0.12-0.17, green ~ 0.20-0.30); tie-breaker for pairing only
peel_hue <- function(file, p = PARAMS) { r <- classify(file, p); mean(r$h[r$peel & !r$brown]) }

# File naming: data/photos/day3/07_a.jpg (banana 07, sides a/b)
# Calibration check: brown pixels painted red, non-peel painted blue, written to `out`
check_overlay <- function(file, out, ...) {
  p <- modifyList(PARAMS, list(...)); r <- classify(file, p); img <- r$img
  m <- matrix(r$brown, r$d[1], r$d[2]); np <- matrix(!r$peel, r$d[1], r$d[2])
  for (k in 1:3) { x <- img[, , k]; x[np] <- x[np] * 0.4 + 0.6 * (k == 3); x[m] <- c(1, 0, 0)[k]; img[, , k] <- x }
  writeJPEG(img, out)
  invisible(100 * sum(r$brown) / sum(r$peel))
}
# Example: check_overlay("data/photos/day0/12_a.jpg", "figures/check_12a.jpg", k = 0.7)

if (sys.nframe() == 0) {   # batch computation when run with Rscript; source() only loads the functions
  files <- list.files("data/photos", pattern = "\\.jpe?g$", recursive = TRUE, full.names = TRUE)
  rs <- lapply(files, function(f) { r <- classify(f)
    c(100 * sum(r$brown) / sum(r$peel), 100 * mean(pmax(0, 0.9 - r$ratio[r$peel]) / 0.9), mean(r$h[r$peel & !r$brown])) })
  out <- data.frame(
    id   = as.integer(sub("_.*", "", basename(files))),
    day  = as.integer(sub(".*day(\\d+).*", "\\1", files)),
    side = sub(".*_(a|b)\\..*", "\\1", basename(files)),
    pct  = sapply(rs, `[`, 1),
    idx  = sapply(rs, `[`, 2),
    hue  = sapply(rs, `[`, 3)
  )
  write.csv(out, paste0("data/brown_by_side_", THRESHOLD_VERSION, ".csv"), row.names = FALSE)
  res <- aggregate(cbind(pct, idx, hue) ~ id + day, out, mean)   # average of the two sides
  names(res)[3:5] <- c("brown_pct", "brown_index", "hue")
  res$version <- THRESHOLD_VERSION
  write.csv(res, paste0("data/brown_from_photos_", THRESHOLD_VERSION, ".csv"), row.names = FALSE)
}
