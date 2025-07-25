# Load packages
library(devtools)
install_github("david-borchers/LT2Dcal",force=TRUE)
library('LT2D')

# Build function
simulate_chapman <- function(Fit.n.ip0, n_animals = 210, area = 100, 
                             beta = NULL, lphi = NULL, mismatch = FALSE) {
  # 1. Extract parameters
  if (is.null(beta)) {
    beta1 <- Fit.n.ip0$fit$par[1]
    beta2 <- Fit.n.ip0$fit$par[2]
  } else {
    beta1 <- beta[1]
    beta2 <- beta[2]
  }
  if (is.null(lphi)) {
    lphi1 <- Fit.n.ip0$fit$par[3]
    lphi2 <- Fit.n.ip0$fit$par[4]
  } else {
    lphi1 <- lphi[1]
    lphi2 <- lphi[2]
  }
  
  # 2. Simulate x-values (perpendicular distances)
  x_set <- rtruncnorm(n = n_animals, a = 0, b = 0.05, mean = lphi1, sd = exp(lphi2))
  
  # 3. Simulate forward distances for detections
  detected_xy <- detect2DLT(x = x_set, hr = "ip0", b = c(beta1, beta2),
                            ystart = 0.05, ny = 1000, getIDs = TRUE)
  if (nrow(detected_xy) < 5) return(NA)
  
  # 4. Move to 2nd observer location
  moving <- move.data(df = detected_xy, move = 2, keep_angle = FALSE)
  
  # 5. Simulate detection outcomes for observer 2
  df <- data.frame(
    id = rep(1:nrow(moving), each = 2),
    obs = rep(1:2, times = nrow(moving)),
    x = c(moving$x, moving$x2),
    y = c(moving$y, moving$y2),
    detect = NA
  )
  
  # Use approximation of detection probability for observer 2
  ys <- seq(0, 0.05, length.out = 100)
  obs2.probs <- p.approx(ys, df$x[df$obs == 2], ip0, b = c(beta1, beta2), what = "px")
  
  n_obs <- nrow(df) / 2
  df$detect[df$obs == 2] <- rbinom(n_obs, 1, obs2.probs)
  df$detect[df$obs == 1] <- 1  
  df$detect[abs(df$x) > 0.05] <- 0
  
  # 6. Apply Chapman estimator
  result <- tryCatch({
    chapman.mr(df = df, mismatch = mismatch)
  }, error = function(e) return(NA))
  
  return(result)
}

###############################################################################

set.seed(42)
n_simulations <- 100
#########################################################

# NO MOVEMENT
chapman_no_movement <- replicate(
  n_simulations,
  simulate_chapman(Fit.n.ip0, mismatch = FALSE),
  simplify = FALSE)

#########################################################
# Without mismatch
chapman_results_no_mismatch <- replicate(
  n_simulations,
  simulate_chapman(Fit.n.ip0, mismatch = FALSE),
  simplify = FALSE)

# With mismatch
chapman_results_mismatch <- replicate(
  n_simulations,
  simulate_chapman(Fit.n.ip0, mismatch = TRUE),
  simplify = FALSE)

# Clean and convert to data.frames
chapman_df_ym_nm <- as.data.frame(do.call(rbind, Filter(Negate(is.na), chapman_results_no_mismatch)))
chapman_df_ym_ym <- as.data.frame(do.call(rbind, Filter(Negate(is.na), chapman_results_mismatch)))

colnames(chapman_df_ym_nm) <- c("Nhat", "LCL", "UCL")
colnames(chapman_df_ym_ym) <- c("Nhat", "LCL", "UCL")

# Compute means
mean_abund_ym_nm <- mean(chapman_df_no_mismatch$Nhat)
mean_abund_ym_ym <- mean(chapman_df_mismatch$Nhat)

mean_density_ym_nm <- mean(chapman_df_no_mismatch$Nhat / 6)
mean_density_ym_ym <- mean(chapman_df_mismatch$Nhat / 6)

# Open plotting window
openGraph(h = 6, w = 10)
par(mfrow = c(2, 2))

## --- Abundance Estimates (No Mismatch) ---
hist(chapman_df_ym_nm$Nhat, breaks = 20,
     main = "Chapman Estimator (Movement,No Mismatch)",
     xlab = "Abundance Estimate", col = "lightgray", border = "white")
abline(v = 210, col = "red", lwd = 2)  # True value
abline(v = mean_abund_no_mismatch, col = "blue", lwd = 2, lty = 2)  # Mean estimate
legend("topright", legend = c("True Abundance", "Mean Estimate"),
       col = c("red", "blue"), lty = c(1, 2), lwd = 2)

## --- Abundance Estimates (With Mismatch) ---
hist(chapman_df_ym_ym$Nhat, breaks = 20,
     main = "Chapman Estimator (Movement,Mismatch)",
     xlab = "Abundance Estimate", col = "lightgray", border = "white")
abline(v = 210, col = "red", lwd = 2)
abline(v = mean_abund_mismatch, col = "blue", lwd = 2, lty = 2)
legend("topright", legend = c("True Abundance", "Mean Estimate"),
       col = c("red", "blue"), lty = c(1, 2), lwd = 2)

## --- Density Estimates (No Mismatch) ---
hist(chapman_df_ym_nm$Nhat / 6, breaks = 20,
     main = "Density Estimate (Movement,No Mismatch)",
     xlab = "Density Estimate", col = "lightgray", border = "white")
abline(v = 35, col = "red", lwd = 2)
abline(v = mean_density_no_mismatch, col = "blue", lwd = 2, lty = 2)
legend("topright", legend = c("True Density", "Mean Estimate"),
       col = c("red", "blue"), lty = c(1, 2), lwd = 2)

## --- Density Estimates (With Mismatch) ---
hist(chapman_df_ym_ym$Nhat / 6, breaks = 20,
     main = "Density Estimate (Movement,Mismatch)",
     xlab = "Density Estimate", col = "lightgray", border = "white")
abline(v = 35, col = "red", lwd = 2)
abline(v = mean_density_mismatch, col = "blue", lwd = 2, lty = 2)
legend("topright", legend = c("True Density", "Mean Estimate"),
       col = c("red", "blue"), lty = c(1, 2), lwd = 2)

# Summaries
summary(chapman_df_ym_nm$Nhat)
summary(chapman_df_ym_ym$Nhat)

# Density objects
chapman_density_ym_nm <- chapman_df_ym_nm$Nhat / 6
chapman_density_ym_ym <- chapman_df_ym_ym$Nhat / 6
