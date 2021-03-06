initialize.priors <- function (abatch, sets, alpha = 1e-6, beta = 1e-6, d = NULL) {

  # set priors for d and tau2
  # prior for d omitted in the current package version

  priors <- vector(length = length(sets), mode = "list")

  for (set in sets) {	
    nprobes <- nrow(pm(abatch, set))
    alphas <- rep.int(alpha, nprobes)
    betas <- rep.int(beta, nprobes)
    priors[[set]] <- list(alpha = alphas, beta = betas, d = d) 
  }

  new("rpa.priors", priors)
}

