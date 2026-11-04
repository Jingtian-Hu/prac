# 第 0 步：在任何配对和分配之前选出试点香蕉
# 规则：有碰伤的（damaged == 1）优先，取编号最小的一根；
#       否则从根数为奇数的把里随机抽一根（若没有奇数把则从全部 31 根里抽）。
set.seed(20261103)
b <- read.csv("data/baseline.csv")   # id, bunch(1-5), weight0, damaged(0/1)

if (any(b$damaged == 1)) {
  pilot <- min(b$id[b$damaged == 1])
} else {
  cnt  <- table(b$bunch)
  odd  <- as.integer(names(cnt)[cnt %% 2 == 1])
  pool <- if (length(odd) > 0) b$id[b$bunch %in% odd] else b$id
  pilot <- pool[sample(length(pool), 1)]
}
writeLines(as.character(pilot), "data/pilot.txt")
cat("pilot banana:", pilot, "（只用它的照片校准阈值）\n")
