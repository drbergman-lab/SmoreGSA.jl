# SmoreGSA

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://drbergman-lab.github.io/SmoreGSA.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://drbergman-lab.github.io/SmoreGSA.jl/dev/)
[![Build Status](https://github.com/drbergman-lab/SmoreGSA.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/drbergman-lab/SmoreGSA.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/drbergman-lab/SmoreGSA.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/drbergman-lab/SmoreGSA.jl)

Global sensitivity analysis (GSA) for the [Smore](https://github.com/drbergman-lab/Smore.jl) surrogate modeling ecosystem. SmoreGSA uses a fitted surrogate model (SM) as a fast proxy for a slow, expensive complex model (CM) to perform GSA of CM outputs with respect to CM parameters.

Implements the SMoRe GloS framework described in [**An efficient and flexible framework for inferring global sensitivity of agent-based model parameters**](https://doi.org/10.1371/journal.pcbi.1013427).

## Quick Start

```julia
using SmoreBase, SmoreGSA
using Distributions

# After fitting SM and running UQ (see SmoreBase):
#   problem    = SMFitProblem(sm, data, sm_prior)
#   fit        = fitSurrogate(problem, P0)
#   uq_results = [SmoreBase._uq(problem, fit, ProfileLikelihood(); param_set_index=i)
#                 for i in 1:n_cohorts]

cm_prior = ParameterPrior(
    lower = [0.0, 0.0],
    upper = [2.0, 5.0],
    names = ["r", "K"],
)

# Pass the SMFitProblem directly; times and conditions are derived from problem.data
result = runSensitivity(problem, uq_results, cm_params, cm_prior, EFAST(n_samples=100))

# Plot sensitivity indices (Plots backend)
using Plots
plot(result)       # grouped bar chart: S1 and ST per CM parameter
```

---

## Implementation Status

> For Claude Code sessions: this section is the authoritative record of what has been built. Update it as features are completed. See [PRD.md](PRD.md) for behavioral specifications and [progress.md](progress.md) for decision rationale.

### Completed

- [x] `runSensitivity` — EFAST and Morris sensitivity of CM outputs to CM parameters, using SM as fast CM proxy (via `GlobalSensitivity.jl`); accepts `SMFitProblem` directly (derives `sm`, `times`, `conditions` from it)
- [x] `EFAST`, `Morris` — GSA method types
- [x] `SensitivityResult` — result type with `S1`, `ST` (Morris: `ST === nothing`), `cm_parameter_names`, `output_labels`
- [x] Nearest-neighbor interpolation of CI bounds from known cohorts
- [x] ICDF transform inside the callable; unit bounds passed to `GlobalSensitivity.gsa`
- [x] Plots extension (`SmoreGSAPlotsExt`) — `plot(sens_result)` grouped bar chart; activated by loading `RecipesBase`

### Remaining

- [ ] Lift SM sensitivity to CM parameter space
- [ ] Richer CM parameter interpolation (linear, RBF) instead of nearest-neighbor
- [ ] Multi-condition averaging (`runSensitivity` v1 uses first condition only)
