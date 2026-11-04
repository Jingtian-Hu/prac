# Primary analysis: within-pair differences + exact randomization inference
# (all 2^16 = 65,536 within-pair assignments enumerated)
library(randomizr)
library(ri2)
library(estimatr)

PRIMARY_DAY <- 3   # pre-registered: outcomes are measured once, on Day 3

a <- read.csv("data/assignment.csv")
b <- read.csv("data/baseline.csv")
o <- read.csv("data/outcomes.csv")                 # id, day, brown_pct, brown_index, grade_blind
d <- merge(a, b[, setdiff(names(b), c("bunch", "organic"))], by = "id")
d <- merge(d, setNames(o[o$day == PRIMARY_DAY, c("id", "brown_pct")], c("id", "Y")), by = "id")
d$brown0   <- d$brown0_v1                          # Day-0 percent brown from the frozen script
d$brown0_c <- d$brown0 - mean(d$brown0)

# 1. Point estimate and SE (within-pair differences)
dj  <- with(d, tapply(Y * Z, pair, sum) - tapply(Y * (1 - Z), pair, sum))
ate <- mean(dj)
se  <- sqrt(var(dj) / length(dj))
c(ATE = ate, SE = se)
difference_in_means(Y ~ Z, blocks = pair, data = d)   # should match the line above

# 2. Exact randomization inference under the sharp null
decl <- declare_ra(blocks = d$pair)
perm <- obtain_permutation_matrix(decl, maximum_permutations = 70000)   # 65,536 < 70,000 -> full enumeration
ncol(perm)
ri_out <- conduct_ri(Y ~ Z, declaration = decl, sharp_hypothesis = 0,
                     data = d, permutation_matrix = perm)
summary(ri_out)
plot(ri_out)

# 3. Confidence interval (FEDAI ch. 3: impute potential outcomes under a constant effect)
Y0 <- d$Y - ate * d$Z
Y1 <- Y0 + ate
sim <- apply(perm, 2, function(z) mean(Y1[z == 1]) - mean(Y0[z == 0]))
quantile(sim, c(0.025, 0.975))

# 4. Covariate adjustment (secondary)
lm_robust(Y ~ Z + brown0_c, fixed_effects = ~ pair, data = d)
ri_cov <- conduct_ri(Y ~ Z + brown0_c, declaration = decl, sharp_hypothesis = 0,
                     data = d, permutation_matrix = perm)
summary(ri_cov)
