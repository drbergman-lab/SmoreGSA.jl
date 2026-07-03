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
- `runSensitivity(method, sm, uqResults, cm_params, cm_prior; times, conditions, outputFn, n_sm_samples, rng) -> SensitivityResult`
  - `method::GlobalSensitivity.GSAMethod` — `EFAST(n_samples=...)` or `Morris(num_trajectory=...)`; leads the argument list as the dispatch/extension point for future `GlobalSensitivity.GSAMethod` subtypes, matching SmoreBase's `quantifyUncertainty(method, problem, ...)` convention
  - `sm::AbstractSurrogateModel` — the fitted surrogate model (from SmoreBase)
  - `uqResults::Vector{ProfileLikelihoodResult}` — one UQ result per CM parameter set
  - `cm_params::AbstractMatrix` — CM parameter values at each CM param_set `[n_cm_param_sets × n_cm_params]`
  - `cm_prior::ParameterPrior` — CM parameter distributions/bounds for the GSA sweep; full distributions used via inverse-CDF transform
  - `times::AbstractVector` — time grid for SM evaluation (required keyword)
  - `conditions::ConditionSpec` — experimental conditions (default: `ConditionSpec()`)
  - `outputFn::Function` — maps SM prediction `[n_times × n_outputs]` → `Vector{Float64}`; default: last time point of each output variable
  - `n_sm_samples::Int` — LHS draws per CM parameter point to average over SM parameter uncertainty (default: 16)
  - `rng::AbstractRNG` — RNG for LHS sampling (default: `Random.default_rng()`)
- `runSensitivity(method, problem, uqResults, cm_params, cm_prior; times, conditions, kwargs...) -> SensitivityResult`
  - Convenience overload accepting an `SMFitProblem` in place of `sm`. Derives `sm` from `problem.sm`; `times` defaults to `_times(problem.data)` and `conditions` defaults to `_conditions(problem.data)`.
  - `times` must be supplied explicitly when `problem.data` has no time axis (`_times` returns `nothing`); throws `ArgumentError` otherwise.
  - `problem.prior` (SM parameter prior) and `problem.loss` are not used — SM bounds come from `uqResults`; `cm_prior` remains a separate caller-supplied argument.
  - **Breaking change:** argument order changes (`method` now leads); previously `runSensitivity(sm_or_problem, uqResults, cm_params, cm_prior, method; ...)`.
- **Algorithm:** For each CM parameter vector `θ` that the GSA algorithm requires:
  1. Apply inverse-CDF to unit-cube input `u`: `θ_CM[i] = quantile(cm_prior.distributions[i], u[i])`
  2. Find nearest known CM param_set in `cm_params` (Euclidean distance)
  3. Use that CM param_set's profile likelihood CI bounds as the SM parameter box; fall back to fit bounds when CI is `nothing`
  4. LHS-sample `n_sm_samples` points within the SM parameter box
  5. Evaluate SM at each LHS draw; return mean `outputFn` result
- `GlobalSensitivity.gsa` is called with `[[0, 1] for each CM param]` as bounds (ICDF is inside the callable).

**Types:**
- `EFAST(; n_samples, num_harmonics=4) <: GlobalSensitivity.GSAMethod` — package-defined wrapper around `GlobalSensitivity.eFAST`; `n_samples` is required (no default; `GlobalSensitivity.gsa` needs it for eFAST but it isn't a field of `GlobalSensitivity.eFAST` itself)
- `Morris` — `GlobalSensitivity.Morris`, re-exported as-is (not wrapped); accepts `num_trajectory`, `p_steps`, `total_num_trajectory`, etc. per `GlobalSensitivity.jl`
- `SensitivityResult{R}`:
  - `method::GlobalSensitivity.GSAMethod` — the GSA method used
  - `cm_parameter_names::Vector{String}` — from `cm_prior.names`
  - `output_labels::Vector{String}`
  - `gsa_result::R` — raw `GlobalSensitivity.jl` result; indices are not stored as separate fields — access via `sensitivity_S1(result)` / `sensitivity_ST(result)`, both `[n_outputs × n_cm_params]` (`sensitivity_ST` is `nothing` for Morris)

**Acceptance criteria:**
- `runSensitivity(EFAST(n_samples=100), sm, uqResults, cm_params, cm_prior; times=t)` returns `SensitivityResult` with `size(sensitivity_S1(result)) == (n_outputs, n_cm_params)` and `sensitivity_ST(result) !== nothing`.
- `runSensitivity(Morris(num_trajectory=10), sm, uqResults, cm_params, cm_prior; times=t)` returns `SensitivityResult` with `sensitivity_ST(result) === nothing`.
- `runSensitivity(EFAST(n_samples=100), problem, uqResults, cm_params, cm_prior)` (no explicit `times`) returns the same result as the `sm`-first form when `problem.data` carries the same time grid.
- Calling the `problem`-first form when `problem.data` has no time axis throws `ArgumentError`.
- When a profile CI bound is `nothing`, the implementation falls back to the fit bounds without error.
- Custom `outputFn` returning a length-2 vector produces `size(sensitivity_S1(result)) == (2, n_cm_params)`.

**Future (not in v1):**
- Richer CM parameter interpolation (linear, RBF) instead of nearest-neighbor.
- Multi-condition averaging (v1 uses first condition only).
- Adaptive `n_sm_samples` based on CI width.

---

### Feature: Plotting (RecipesBase extension)

**One-line description:** Sensitivity bar chart via the Plots/RecipesBase backend; Makie users build their own from `SensitivityResult`.

**Priority:** Should-have

**Behavioral specification:**

`RecipesBase` is a weak dependency. The Plots extension (`SmoreGSAPlotsExt`) activates when `RecipesBase` is loaded.

There is **no Makie extension** — mirrors the SmoreBase decision (see SmoreBase `progress.md`, "Drop Makie extension"). A baked `Makie.plot(r) -> Figure` could not be customized (legend, layout) without reaching into `fig.content` and added no capability over building the chart directly. `SensitivityResult` exposes `sensitivity_S1`/`sensitivity_ST`, `cm_parameter_names`, and `output_labels`; `docs/src/plotting.md` shows the Makie recipe.

| Type | Usage | What it shows |
|------|-------|---------------|
| `SensitivityResult` | `plot(sens_result)` | Grouped, stacked bar chart: one cluster per `groupby` category (`:output` default, or `:parameter`), one dodged bar per remaining category within each cluster; each bar is S1 (bottom, solid) with ST−S1 (top, `fillalpha=0.45`) stacked on it when ST is available |

**Custom attributes:**
- `groupby::Symbol = :output` — `:output` clusters by output variable (bars within a cluster = CM parameters); `:parameter` clusters by CM parameter (bars within a cluster = outputs)
- `show_ST::Bool = true` — whether to stack the ST−S1 segment on top of S1 when ST is available

**Implementation note:** Plots.jl's `bar_position` attribute is not actually wired up for the GR backend in the installed version (present in the attribute table, absent from any drawing code) — grouping and stacking are done manually: bar x-positions are offset per subgroup within each cluster (dodge), and the ST segment is drawn as a second `:bar` series with `fillrange := s1_vals` (the bar recipe's "bottom" attribute, default 0), producing the stacked look without relying on `bar_position`.

**Testing:**
- `RecipesBase.apply_recipe(Dict{Symbol,Any}(), sens_result)` returns non-empty results; series counts and labels checked for both `groupby` modes
- Verified visually via GR-rendered PNGs (grouping and stacking both confirmed by inspection, not just series counts)

**Acceptance criteria:**
- `plot(sens_result)` produces a grouped bar chart clustered by output (default), with CM-parameter bars dodged (not overlapping/overlaid) within each cluster.
- `plot(sens_result; groupby = :parameter)` clusters by CM parameter instead, with output bars dodged within each cluster.
- Loading SmoreGSA without any plotting backend does not error.
- `docs/src/plotting.md` documents the Plots recipe and states there is no Makie extension (`SensitivityResult` exposes public accessors for users who build their own).

---

### Feature: Lift Sensitivity to CM Parameter Space (Future)

> Not yet implemented. Specification will be added when work begins.

- Given SM sensitivity indices, propagate back through the SM parameter → CM parameter mapping to obtain CM-space sensitivity.

---

## Ruled Out / Deferred

- **`LHSSensitivity` as a formal GSA method type**: LHS-based prediction sampling is a utility (`sampleSMPredictions` in SmoreBase) for uncertainty propagation, not GSA.
- **`GlobalSensitivity.jl` inside `SmoreBase`**: SM sensitivity lives here (SmoreGSA). SmoreBase only provides `sampleSMPredictions` (MC, not GSA).
