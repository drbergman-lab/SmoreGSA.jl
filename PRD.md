# Product Requirements Document — SmoreGSA.jl

> **Purpose:** This document defines the complete feature set of SmoreGSA in behavioral terms. It is the authoritative answer to "what should this system do?" Read this at the start of any feature session to establish alignment between intent and implementation plan.

---

## Product Overview

**Vision:** SmoreGSA uses a fitted surrogate model (SM) as a fast proxy for a slow complex model (CM) to perform global sensitivity analysis (GSA) of CM outputs with respect to CM parameters. It wraps `GlobalSensitivity.jl` and provides the interpolation and sampling machinery needed to evaluate the SM at arbitrary CM parameter points.

**Target Users:** Computational modelers who have a fitted SM (from SmoreBase) and want to understand which CM parameters most strongly drive CM output variability.

**Relationship to MATLAB SMoReParS:** SmoreGSA ports and generalizes the `sampleFromSMProfiles.m` sensitivity component.

---

### Feature: Sensitivity Analysis of CM Outputs

**One-line description:** GSA of CM outputs with respect to CM parameters, using the SM as a fast CM proxy.

**Priority:** Must-have

**Behavioral specification:**
- `runSensitivity(sm, uqResults, cm_params, cm_prior, method; times, conditions, outputFn, n_sm_samples, rng) -> SensitivityResult`
  - `sm::AbstractSurrogateModel` — the fitted surrogate model (from SmoreBase)
  - `uqResults::Vector{ProfileLikelihoodResult}` — one UQ result per CM parameter set (cohort)
  - `cm_params::AbstractMatrix` — CM parameter values at each cohort `[n_cohorts × n_cm_params]`
  - `cm_prior::ParameterPrior` — CM parameter distributions/bounds for the GSA sweep; full distributions used via inverse-CDF transform
  - `method::AbstractGSAMethod` — `EFAST(n_samples)` or `Morris(num_trajectory, ...)`
  - `times::AbstractVector` — time grid for SM evaluation (required keyword)
  - `conditions::ConditionSpec` — experimental conditions (default: `ConditionSpec()`)
  - `outputFn::Function` — maps SM prediction `[n_times × n_outputs]` → `Vector{Float64}`; default: last time point of each output variable
  - `n_sm_samples::Int` — LHS draws per CM parameter point to average over SM parameter uncertainty (default: 16)
  - `rng::AbstractRNG` — RNG for LHS sampling (default: `Random.default_rng()`)
- `runSensitivity(problem, uqResults, cm_params, cm_prior, method; times, conditions, kwargs...) -> SensitivityResult`
  - Convenience overload accepting an `SMFitProblem` in place of `sm`. Derives `sm` from `problem.sm`; `times` defaults to `_times(problem.data)` and `conditions` defaults to `_conditions(problem.data)`.
  - `times` must be supplied explicitly when `problem.data` has no time axis (`_times` returns `nothing`); throws `ArgumentError` otherwise.
  - `problem.prior` (SM parameter prior) and `problem.loss` are not used — SM bounds come from `uqResults`; `cm_prior` remains a separate caller-supplied argument.
- **Algorithm:** For each CM parameter vector `θ` that the GSA algorithm requires:
  1. Apply inverse-CDF to unit-cube input `u`: `θ_CM[i] = quantile(cm_prior.distributions[i], u[i])`
  2. Find nearest known cohort in `cm_params` (Euclidean distance)
  3. Use that cohort's profile likelihood CI bounds as the SM parameter box; fall back to fit bounds when CI is `nothing`
  4. LHS-sample `n_sm_samples` points within the SM parameter box
  5. Evaluate SM at each LHS draw; return mean `outputFn` result
- `GlobalSensitivity.gsa` is called with `[[0, 1] for each CM param]` as bounds (ICDF is inside the callable).

**Types:**
- `abstract type AbstractGSAMethod end`
- `EFAST(; n_samples=1000) <: AbstractGSAMethod` — wraps `GlobalSensitivity.eFAST`; computes S1 and ST
- `Morris(; num_trajectory=10, p_steps=nothing, total_num_trajectory=nothing) <: AbstractGSAMethod` — computes µ* elementary effects; no ST
- `SensitivityResult{T<:Real}`:
  - `method::AbstractGSAMethod`
  - `cm_parameter_names::Vector{String}` — from `cm_prior.names`
  - `output_labels::Vector{String}`
  - `S1::Matrix{T}` — first-order indices `[n_cm_params × n_outputs]`
  - `ST::Union{Nothing, Matrix{T}}` — total-order indices; `nothing` for Morris
  - `gsa_result::Any` — raw `GlobalSensitivity.jl` result

**Acceptance criteria:**
- `runSensitivity(sm, uqResults, cm_params, cm_prior, EFAST(); times=t)` returns `SensitivityResult` with `size(S1) == (n_cm_params, n_outputs)` and `ST !== nothing`.
- `runSensitivity(sm, uqResults, cm_params, cm_prior, Morris(); times=t)` returns `SensitivityResult` with `ST === nothing`.
- `runSensitivity(problem, uqResults, cm_params, cm_prior, EFAST())` (no explicit `times`) returns the same result as the `sm`-first form when `problem.data` carries the same time grid.
- Calling the `problem`-first form when `problem.data` has no time axis throws `ArgumentError`.
- When a profile CI bound is `nothing`, the implementation falls back to the fit bounds without error.
- Custom `outputFn` returning a length-2 vector produces `size(S1) == (n_cm_params, 2)`.

**Future (not in v1):**
- Richer CM parameter interpolation (linear, RBF) instead of nearest-neighbor.
- Multi-condition averaging (v1 uses first condition only).
- Adaptive `n_sm_samples` based on CI width.

---

### Feature: Plotting (RecipesBase extension + Makie extension)

**One-line description:** Backend-agnostic sensitivity bar chart and Makie equivalent.

**Priority:** Should-have

**Behavioral specification:**

`RecipesBase` and `Makie` are weak dependencies. The Plots extension (`SmoreGSAPlotsExt`) activates when `RecipesBase` is loaded; the Makie extension (`SmoreGSAMakieExt`) activates when any Makie backend is loaded.

| Type | Usage | What it shows |
|------|-------|---------------|
| `SensitivityResult` | `plot(sens_result)` | Grouped bar chart: x = CM parameter names, bars = S1 (and ST if available and `show_ST=true`) per output |

**Custom attributes:**
- `show_ST::Bool = true` — whether to add ST bars alongside S1

**Makie:** `Makie.plot(sens_result)` returns a `Makie.Figure`. ST bars use `alpha=0.45`.

**Testing:**
- `RecipesBase.apply_recipe(Dict{Symbol,Any}(), sens_result)` returns non-empty results

**Acceptance criteria:**
- `plot(sens_result)` produces a grouped bar chart with CM parameter names on x-axis.
- `Makie.plot(sens_result)` returns a `Makie.Figure`.
- Loading SmoreGSA without any plotting backend does not error.

---

### Feature: Lift Sensitivity to CM Parameter Space (Future)

> Not yet implemented. Specification will be added when work begins.

- Given SM sensitivity indices, propagate back through the SM parameter → CM parameter mapping to obtain CM-space sensitivity.

---

## Ruled Out / Deferred

- **`LHSSensitivity` as a formal GSA method type**: LHS-based prediction sampling is a utility (`sampleSMPredictions` in SmoreBase) for uncertainty propagation, not GSA.
- **`GlobalSensitivity.jl` inside `SmoreBase`**: SM sensitivity lives here (SmoreGSA). SmoreBase only provides `sampleSMPredictions` (MC, not GSA).
