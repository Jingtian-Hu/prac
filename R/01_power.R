# 功效模拟：16 对配对 + 随机化推断（对内符号翻转）
# 假设：对照组第 4 天褐变 % 的 SD = 15 个百分点；常数处理效应；alpha = 0.05 双侧
# 注：同一模拟先用 Python 跑过（结果见方案文档的表），此 R 版本逻辑相同。
set.seed(20261103)
J <- 16; sd <- 15; sims <- 2000; flips <- 2000
signs <- matrix(sample(c(-1, 1), flips * J, replace = TRUE), flips, J)

power_paired <- function(tau, rho) {
  rej <- replicate(sims, {
    b  <- rnorm(J, 0, sd * sqrt(rho))                       # 对共同成分 -> 对内相关 rho
    y0 <- b + matrix(rnorm(2 * J, 0, sd * sqrt(1 - rho)), J, 2)
    d  <- (y0[, 1] + tau) - y0[, 2]                         # 对内差值（处理 - 对照）
    obs  <- mean(d)
    null <- as.vector(signs %*% d) / J                      # 尖锐零假设下的随机化分布
    mean(abs(null) >= abs(obs)) <= 0.05
  })
  mean(rej)
}

grid <- expand.grid(tau = c(5, 10, 15, 20), rho = c(0, 0.5, 0.7))
grid$power <- mapply(power_paired, grid$tau, grid$rho)
print(reshape(grid, idvar = "rho", timevar = "tau", direction = "wide"))

# 解析近似：MDE = (t_.975 + t_.80) * SE，SE = sd * sqrt(2 * (1 - rho)) / sqrt(J)
mde <- function(rho) (qt(.975, J - 1) + qt(.80, J - 1)) * sd * sqrt(2 * (1 - rho)) / sqrt(J)
sapply(c(0, 0.5, 0.6, 0.7), mde)
