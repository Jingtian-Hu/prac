# Before/after figures for the write-up: Day-0 and endline photos of three pairs with a pixel
# classification painted on (red = brown, blue = not counted as fruit/peel).
#   figures/before_after_wide.png  revised measure, fruit outline (R/06_alt_measure.R)
#   figures/before_after.png       pre-registered peel test (R/03_measure_photos.R)
#   figures/fruit_mask_sheet.png   revised measure on six bananas spanning the endline range, Day 0 and endline
# Pairs shown (chosen on the revised measure): the largest positive within-pair difference, the one
# closest to the mean difference, and the most negative one. Run from the repository root.
source("R/06_alt_measure.R")   # loads classify(), alt_classify() and PARAMS only
library(grid)

a <- read.csv("data/assignment.csv")
o <- read.csv("data/brown_alt_fruitmask.csv")
endline <- max(o$day)
y <- setNames(o$brown_alt[o$day == endline], o$id[o$day == endline])
a$Y <- y[as.character(a$id)]
tr <- a[a$Z == 1, ]; co <- a[a$Z == 0, ]
tr <- tr[order(tr$pair), ]; co <- co[order(co$pair), ]
dj <- tr$Y - co$Y
pick <- unique(c(which.max(dj), which.min(abs(dj - mean(dj))), which.min(dj)))

overlay <- function(file, wide) {
  if (wide) { r <- alt_classify(file); keep <- r$fruit } else { r <- classify(file); keep <- r$peel }
  img <- r$img
  m <- matrix(r$brown, r$d[1], r$d[2]); np <- matrix(!keep, r$d[1], r$d[2])
  for (k in 1:3) { x <- img[, , k]; x[np] <- x[np] * 0.4 + 0.6 * (k == 3); x[m] <- c(1, 0, 0)[k]; img[, , k] <- x }
  if (dim(img)[1] > dim(img)[2]) img <- aperm(img[, dim(img)[2]:1, ], c(2, 1, 3))   # portrait -> landscape
  list(img = img, pct = 100 * sum(r$brown) / sum(keep))
}
photo <- function(id, day) sprintf("data/photos/day%d/%02d_a.jpg", day, id)

make_figure <- function(out, wide) {
  png(out, width = 2400, height = 560 * length(pick) + 120, res = 200)
  grid.newpage()
  lay <- grid.layout(length(pick) + 1, 5, widths = unit(c(0.12, rep(0.22, 4)), "npc"),
                     heights = unit(c(120, rep(560, length(pick))), "null"))
  pushViewport(viewport(layout = lay))
  heads <- c("Open air, Day 0", "Open air, endline", "Paper bag, Day 0", "Paper bag, endline")
  for (j in 1:4) grid.text(heads[j], vp = viewport(layout.pos.row = 1, layout.pos.col = j + 1),
                           gp = gpar(fontsize = 11, fontface = "bold"))
  for (i in seq_along(pick)) {
    j <- pick[i]
    grid.text(sprintf("Pair %d\ndiff. %+.1f pp", tr$pair[j], dj[j]),
              vp = viewport(layout.pos.row = i + 1, layout.pos.col = 1), gp = gpar(fontsize = 10))
    cells <- list(c(co$id[j], 0), c(co$id[j], endline), c(tr$id[j], 0), c(tr$id[j], endline))
    for (k in 1:4) {
      ov <- overlay(photo(cells[[k]][1], cells[[k]][2]), wide)
      pushViewport(viewport(layout.pos.row = i + 1, layout.pos.col = k + 1))
      grid.raster(ov$img, width = unit(0.96, "npc"), height = unit(0.82, "npc"), y = unit(0.55, "npc"))
      grid.text(sprintf("Banana %d (side a): %.1f%% brown", cells[[k]][1], ov$pct), y = unit(0.06, "npc"),
                gp = gpar(fontsize = 8))
      popViewport()
    }
  }
  dev.off()
}

make_figure("figures/before_after_wide.png", wide = TRUE)
make_figure("figures/before_after.png", wide = FALSE)

# Appendix sheet: six bananas at the 0, 20, 40, 60, 80 and 100th percentiles of endline percent brown
ids <- a$id[order(a$Y)][round(seq(1, nrow(a), length.out = 6))]
png("figures/fruit_mask_sheet.png", width = 2400, height = 1700, res = 200)
grid.newpage()
pushViewport(viewport(layout = grid.layout(3, 4)))
for (i in seq_along(ids)) {
  for (k in 1:2) {
    day <- c(0, endline)[k]
    ov  <- overlay(photo(ids[i], day), wide = TRUE)
    pushViewport(viewport(layout.pos.row = (i - 1) %/% 2 + 1, layout.pos.col = 2 * ((i - 1) %% 2) + k))
    grid.raster(ov$img, width = unit(0.94, "npc"), height = unit(0.78, "npc"), y = unit(0.52, "npc"))
    grid.text(sprintf("Banana %d, %s: %.1f%% brown", ids[i], if (day == 0) "Day 0" else "endline", ov$pct),
              y = unit(0.07, "npc"), gp = gpar(fontsize = 8))
    popViewport()
  }
}
dev.off()
