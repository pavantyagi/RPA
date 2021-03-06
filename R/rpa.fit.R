#' @title RPA fit
#' @description Fit the RPA model.
#' @param dat Original data: probes x samples.
#' @param epsilon Convergence tolerance. The iteration is deemed converged when the change in all parameters is < epsilon.
#' @param alpha alpha prior for inverse Gamma distribution of probe-specific variances. Noninformative prior is obtained with alpha, beta -> 0. Not used with tau2.method 'var'. Scalar alpha and beta are specify equal inverse Gamma prior for all probes to regularize the solution. The defaults depend on the method.
#' @param beta beta prior for inverse Gamma distribution of probe-specific variances. Noninformative prior is obtained with alpha, beta -> 0. Not used with tau2.method 'var'. Scalar alpha and beta are specify equal inverse Gamma prior for all probes to regularize the solution. The defaults depend on the method.
#' @param tau2.method Optimization method for tau2 (probe-specific variances);
#'
#'	"robust": (default) update tau2 by posterior mean,
#'		regularized by informative priors that are identical
#'		for all probes (user-specified by
#'		setting scalar values for alpha, beta). This
#'		regularizes the solution, and avoids overfitting where
#'		a single probe obtains infinite reliability. This is a
#'	    potential problem in the other tau2 update
#'	    methods with non-informative variance priors. The
#'		default values alpha = 2; beta = 1 are
#'	    used if alpha and beta are not specified.
#'
#'      "mode": update tau2 with posterior mean
#'
#'	"mean": update tau2 with posterior mean
#'	
#'	"var": update tau2 with variance around d. Applies the fact
#'      that tau2 cost function converges to variance with
#'        large sample sizes. 
#'
#' @param d.method Method used to optimize d. Options:
#'
#'  "fast": (default) weighted mean over the probes, weighted
#'  by probe variances The solution converges to this with
#' large sample size.
#'
#'  "basic": optimization scheme to find a mode used in Lahti
#'  et al. TCBB/IEEE; relatively slow; preferred with small
#' sample size.
#' @param summarize.with.affinities Use affinity estimates in probe summarization step. Default: FALSE.
#' @details Fits the RPA model, including estimation of probe-specific affinity parameters. First learns a point estimate for the RPA model in terms of differential expression values w.r.t. reference sample. After this, probe affinities are estimated by comparing original data and differential expression shape, and setting prior assumptions concerning probe affinities.
#'
#' @return mu: Fitted signal in original data: mu.real + d; mu.real: Shifting parameter of the reference sample; tau2: Probe-specific stochastic noise; affinity: Probe-specific affinities; data: Probeset data matrix; alpha, beta: prior parameters
#'
#' @seealso rpa, estimate.affinities
#' @export
#'
#' @references See citation("RPA") 
#' @author Leo Lahti \email{leo.lahti@@iki.fi}
#' @examples # res <- rpa.fit(dat, epsilon, alpha, beta, tau2.method, d.method, affinity.method)
#' @keywords utilities
rpa.fit <- function (dat, epsilon = 1e-2, alpha = NULL, beta = NULL, tau2.method = "robust", d.method = "fast", summarize.with.affinities = FALSE) {

  # dat = q[[set]]; epsilon = 1e-2; tau2.method = "robust"; d.method = "fast"; alpha = probe.parameters$alpha; beta = probe.parameters$beta[[set]]

  # dat: original data (probes x samples)	       	       		       

  # Fits RPA on fold-change data calculated against the reference sample.
  # After estimating the RPA fold-changes; fits the mean in the
  # original data domain since this is typically desired.

  cind <- sample(ncol(dat), 1)

  if ( sum(is.na(dat)) > 0 ) {
    warning(paste("Data has ", mean(is.na(dat)), " fraction of missing values: imputing"))
    dat <- t(apply(dat, 1, function (x) { y <- x; y[is.na(y)] <- rnorm(sum(is.na(y)), mean(y, na.rm = T), sd(y, na.rm = T)); y}))
  }

  # Extract reference sample  
  # Get samples x probes matrix of probe-wise fold-changes
  if ( is.null(colnames(dat)) ) { colnames(dat) <- 1:ncol(dat) }

  # Accommodate single-probe probesets
  if (nrow(dat) == 1) {  
    return(list(mu = as.vector(dat), 
		mu.real = as.vector(dat)[[cind]], 
           	tau2 = 0, 
           	affinity = 0, 
           	data = dat,
	   	alpha = ncol(dat)/2,
           	beta = 0))
  }

  # Fit RPA
  q <- t(matrix(dat[, -cind] - dat[, cind], nrow = nrow(dat)))
  estimated <- RPA.iteration(q, epsilon, alpha, beta, tau2.method, d.method)

  # Estimate overall signal
  # weighted mean over the probes, weighted by probe variances 
  # The solution converges to this with large sample size.

  # Preliminary signal shape estimate without affinities:
  # mu = mu.abs + d
  mu <- d.update.fast(dat, estimated$tau2)

  # Mean difference between total signal and estimated signal shape 
  mu.abs <- mean(mu[-cind] - estimated$d) 

  # Corresponding affinity estimates (ML)
  affinity <- estimate.affinities(dat, mu)

  # Fixed summary, corresponding to the affinities
  if (!summarize.with.affinities) {
    mu <- rep.int(0, length(mu))
    mu[-cind] <- estimated$d
    mu.final <- mu.abs + mu
  } else {
    # Summary using the estimated affinities.
    # This did not seem to improve model performance - skipped by default.
    mu.final <- d.update.fast(dat - affinity, estimated$tau2)
  }

  # Return parameters
  # mu: fitted probeset-level signal 
  # affinity: probe-specific affinities
  # tau2: probe-specific variance
  # model: x_p = mu + affinity_p + noise_p; 
  # noise ~ N(0, tau2_p)

  list(mu = mu.final, # Final expression estimate
      mu.real = mu.abs, 
         tau2 = estimated$tau2, 
     affinity = affinity, 
         data = dat,
	alpha = estimated$alpha,
         beta = estimated$beta) 
}
