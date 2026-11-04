# Power simulation: 16 matched pairs + randomization inference (within-pair sign flips)
# Assumptions: SD of percent brown on the primary day = 15 percentage points; constant treatment effect;
# alpha = 0.05 two-sided
set.seed(20261103)
J <- 16; sd <- 15; sims <- 2000; flips <- 2000
signs <- matrix(sample(c(-1, 1), flips * J, replace = TRUE), flips, J)

power_paired <- function(tau, rho) {
  rej <- replicate(sims, {
    b  <- rnorm(J, 0, sd * sqrt(rho))                       # pair component -> within-pair correlation rho
    y0 <- b + matrix(rnorm(2 * J, 0, sd * sqrt(1 - rho)), J, 2)
    d  <- (y0[, 1] + tau) - y0[, 2]                         # within-pair difference (treated - control)
    obs  <- mean(d)
    null <- as.vector(signs %*% d) / J                      # randomization distribution under the sharp null
    mean(abs(null) >= abs(obs)) <= 0.05
  })
  mean(rej)
}

grid <- expand.grid(tau = c(5, 10, 15, 20), rho = c(0, 0.5, 0.7))
grid$power <- mapply(power_paired, grid$tau, grid$rho)
print(reshape(grid, idvar = "rho", timevar = "tau", direction = "wide"))

# Analytic approximation: MDE = (t_.975 + t_.80) * SE, SE = sd * sqrt(2 * (1 - rho)) / sqrt(J)
mde <- function(rho) (qt(.975, J - 1) + qt(.80, J - 1)) * sd * sqrt(2 * (1 - rho)) / sqrt(J)
sapply(c(0, 0.5, 0.6, 0.7), mde)
