# Randomization: pair within hand on photo-measured baseline browning -> pair the set-aside bananas
# across hands within organic status -> assign one banana per pair -> assign slots.
# Prerequisites: 03_measure_photos.R has been run on the Day-0 photos (data/brown_from_photos_v1.csv);
# pap.md has been registered on OSF.
library(randomizr)
library(ggplot2)

set.seed(20261104)
b  <- read.csv("data/baseline.csv")                 # id, bunch (1-6), organic (0/1), weight0, damaged (0/1)
ph <- read.csv("data/brown_from_photos_v1.csv")    # from 03_measure_photos.R
b <- merge(b, setNames(ph[ph$day == 0, c("id", "brown_pct", "hue")], c("id", "brown0_v1", "hue0_v1")), by = "id")
stopifnot(nrow(b) %% 2 == 0, !anyNA(b$brown0_v1))
n_pairs <- nrow(b) / 2

# 1. Within-hand pairing: sort by Day-0 percent brown, then by hue of non-brown peel (higher = greener),
#    then by weight if recorded; adjacent bananas form a pair.
b <- b[order(b$bunch, b$brown0_v1, -b$hue0_v1, b$weight0), ]
b$pair <- NA
next_pair <- 1
leftover <- integer(0)
for (h in unique(b$bunch)) {
  ids <- b$id[b$bunch == h]
  if (length(ids) %% 2 == 1) {              # hand with an odd count: set one banana aside at random
    out <- ids[sample(length(ids), 1)]
    leftover <- c(leftover, out)
    ids <- setdiff(ids, out)
  }
  k <- length(ids) / 2
  if (k > 0) b$pair[match(ids, b$id)] <- rep(next_pair:(next_pair + k - 1), each = 2)
  next_pair <- next_pair + k
}

# 2. Set-aside bananas: pair across hands within organic status, sorted by Day-0 percent brown
if (length(leftover) %% 2 == 1) stop("Odd number of set-aside bananas; cannot pair them")
if (length(leftover) > 0) {
  lo <- b[b$id %in% leftover, ]
  if (any(table(lo$organic) %% 2 == 1)) stop("Set-aside bananas cannot be paired within organic status")
  lo <- lo[order(lo$organic, lo$brown0_v1, -lo$hue0_v1, lo$weight0), ]
  b$pair[match(lo$id, b$id)] <- rep(next_pair:(next_pair + nrow(lo) / 2 - 1), each = 2)
}

ex <- b
stopifnot(all(table(ex$pair) == 2), length(unique(ex$pair)) == n_pairs)

# 3. Within-pair assignment: one banana per pair is bagged (block_ra, prob = 0.5 within each block)
ex$Z <- block_ra(blocks = ex$pair)

# 4. Slots: n_pairs slots assigned to pairs at random; left/right within a slot randomized
ex$slot <- sample(n_pairs)[ex$pair]
ex$side <- ifelse(block_ra(blocks = ex$pair) == 1, "L", "R")

stopifnot(all(tapply(ex$Z, ex$pair, sum) == 1))
write.csv(ex[order(ex$pair, ex$id), c("id", "bunch", "organic", "pair", "brown0_v1", "hue0_v1", "Z", "slot", "side")], "data/assignment.csv", row.names = FALSE)

# 5. Design figure (Coppock 2021): one panel per hand, cross-hand pairs in their own panel
ex$panel <- ave(ex$bunch, ex$pair, FUN = function(x) if (length(unique(x)) == 1) x[1] else 0)
hands <- sort(unique(ex$bunch))
ex$panel <- factor(ex$panel, levels = c(hands, 0),
                   labels = c(paste0("Hand ", hands, ifelse(tapply(ex$organic, ex$bunch, max) == 1, " (organic)", "")), "Cross-hand"))
p <- ggplot(ex, aes(factor(pair), brown0_v1, colour = factor(Z, labels = c("Control", "Paper bag")))) +
  geom_line(aes(group = pair), colour = "grey70") +
  geom_point(size = 3) +
  facet_grid(~ panel, scales = "free_x", space = "free_x") +
  labs(x = "Pair (faceted by hand)", y = "Day-0 percent brown (photo, v1)", colour = NULL) +
  theme_minimal()
dir.create("figures", showWarnings = FALSE)
ggsave("figures/design.png", p, width = 7, height = 4, dpi = 200)
