# 随机化：（试点已由 00 选出）手内按照片基线配对 -> 剩余跨把配对 -> 对内随机 -> 格位随机
# 前置：00_pick_pilot.R 已运行；03_measure_photos.R 的 v1 阈值已用试点照片定好并 commit；
#       已算出全部第 0 天照片的 brown_pct；pap.md 已在 OSF 注册
library(randomizr)
library(ggplot2)

set.seed(20261104)
b     <- read.csv("data/baseline.csv")                 # id, bunch(1-6), organic(0/1), weight0, damaged(0/1)
pilot <- if (file.exists("data/pilot.txt")) as.integer(readLines("data/pilot.txt")) else integer(0)   # 00_pick_pilot.R 选出的试点（练习数据没有试点）
ph    <- read.csv("data/brown_from_photos_v1.csv")    # 03_measure_photos.R 用 v1 阈值算出
b <- merge(b, setNames(ph[ph$day == 0, c("id", "brown_pct", "hue")], c("id", "brown0_v1", "hue0_v1")), by = "id")
b <- b[!b$id %in% pilot, ]
stopifnot(nrow(b) %% 2 == 0, !anyNA(b$brown0_v1))   # 正式实验：31 根去掉试点 = 30 根
n_pairs <- nrow(b) / 2

# 1. 手内配对：每把内按照片测得的基线褐变 %（v1 阈值）排序；褐变相同（如都是 0）时按绿度（色相，越大越生），再按重量；相邻两根一对
b <- b[order(b$bunch, b$brown0_v1, -b$hue0_v1, b$weight0), ]
b$pair <- NA
next_pair <- 1
leftover <- integer(0)
for (h in unique(b$bunch)) {
  ids <- b$id[b$bunch == h]
  if (length(ids) %% 2 == 1) {              # 去掉试点后仍为奇数的把：随机留出一根
    out <- ids[sample(length(ids), 1)]
    leftover <- c(leftover, out)
    ids <- setdiff(ids, out)
  }
  k <- length(ids) / 2
  if (k > 0) b$pair[match(ids, b$id)] <- rep(next_pair:(next_pair + k - 1), each = 2)
  next_pair <- next_pair + k
}

# 2. 留出的几根（偶数根）跨把配对：先按有机/非有机分开（第 1–3 把非有机，4–6 把有机），再按基线褐变 % 排序相邻配对
if (length(leftover) %% 2 == 1) stop("奇数把的个数是奇数，留出的香蕉无法两两配对")
if (length(leftover) > 0) {
  lo <- b[b$id %in% leftover, ]
  if (any(table(lo$organic) %% 2 == 1)) stop("留出的香蕉里有机/非有机各自不是偶数根，无法在同类内配对")
  lo <- lo[order(lo$organic, lo$brown0_v1, -lo$hue0_v1, lo$weight0), ]
  b$pair[match(lo$id, b$id)] <- rep(next_pair:(next_pair + nrow(lo) / 2 - 1), each = 2)
}

ex <- b
stopifnot(all(table(ex$pair) == 2), length(unique(ex$pair)) == n_pairs)

# 3. 对内随机：每对 1 根装袋（block_ra 默认每区组 prob = 0.5）
ex$Z <- block_ra(blocks = ex$pair)

# 4. 格位：n_pairs 个格位随机分给各对；每对内左右也随机
ex$slot <- sample(n_pairs)[ex$pair]   # 格位随机，不按把集中摆放
ex$side <- ifelse(block_ra(blocks = ex$pair) == 1, "L", "R")

stopifnot(all(tapply(ex$Z, ex$pair, sum) == 1))
write.csv(ex[order(ex$pair, ex$id), c("id", "bunch", "organic", "pair", "brown0_v1", "hue0_v1", "Z", "slot", "side")], "data/assignment.csv", row.names = FALSE)

# 5. 设计图（Coppock 2021）；跨把的对单独放一个面板
ex$panel <- ave(ex$bunch, ex$pair, FUN = function(x) if (length(unique(x)) == 1) x[1] else 0)
ex$panel <- factor(ex$panel, levels = c(sort(unique(ex$bunch)), 0), labels = c(paste0("第", sort(unique(ex$bunch)), "把", ifelse(tapply(ex$organic, ex$bunch, max) == 1, "(有机)", "")), "跨把"))
p <- ggplot(ex, aes(factor(pair), brown0_v1, colour = factor(Z, labels = c("对照", "纸袋")))) +
  geom_line(aes(group = pair), colour = "grey70") +
  geom_point(size = 3) +
  facet_grid(~ panel, scales = "free_x", space = "free_x") +
  labs(x = "配对（按把分面）", y = "第 0 天褐变 %（照片，v1 阈值）", colour = NULL) +
  theme_minimal()
dir.create("figures", showWarnings = FALSE)
ggsave("figures/design.png", p, width = 7, height = 4, dpi = 200)
