# 主分析：配对差值 + 精确随机化推断（2^16 = 65,536 种分配全部枚举）
library(randomizr)
library(ri2)
library(estimatr)

PRIMARY_DAY <- 3   # 预注册：只在第 3 天测一次

a <- read.csv("data/assignment.csv")
b <- read.csv("data/baseline.csv")
o <- read.csv("data/outcomes.csv")                 # id, day, brown_pct, grade_blind, weight
d <- merge(a, b[, setdiff(names(b), "bunch")], by = "id")
d <- merge(d, setNames(o[o$day == PRIMARY_DAY, c("id", "brown_pct")], c("id", "Y")), by = "id")
d <- merge(d, setNames(o[o$day == 0, c("id", "brown_pct")], c("id", "brown0")), by = "id")  # 第 0 天褐变 %（校准后的脚本算出）
d$brown0_c <- d$brown0 - mean(d$brown0)

# 1. 点估计与 SE（对内差值）
dj  <- with(d, tapply(Y * Z, pair, sum) - tapply(Y * (1 - Z), pair, sum))
ate <- mean(dj)
se  <- sqrt(var(dj) / length(dj))
c(ATE = ate, SE = se)
difference_in_means(Y ~ Z, blocks = pair, data = d)   # 应与上面一致

# 2. 精确随机化推断：尖锐零假设
decl <- declare_ra(blocks = d$pair)
perm <- obtain_permutation_matrix(decl, maximum_permutations = 70000)   # 65,536 < 70,000 -> 全部枚举
ncol(perm)
ri_out <- conduct_ri(Y ~ Z, declaration = decl, sharp_hypothesis = 0,
                     data = d, permutation_matrix = perm)
summary(ri_out)
plot(ri_out)

# 3. 置信区间（FEDAI 第 3 章：假设常数效应补全潜在结果）
Y0 <- d$Y - ate * d$Z
Y1 <- Y0 + ate
sim <- apply(perm, 2, function(z) mean(Y1[z == 1]) - mean(Y0[z == 0]))
quantile(sim, c(0.025, 0.975))

# 4. 协变量调整（次要）
lm_robust(Y ~ Z + brown0_c, fixed_effects = ~ pair, data = d)
ri_cov <- conduct_ri(Y ~ Z + brown0_c, declaration = decl, sharp_hypothesis = 0,
                     data = d, permutation_matrix = perm)
summary(ri_cov)
