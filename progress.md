# progress.md — SmoreGSA.jl Session Journal

> **Purpose:** Session-level decisions, rejected approaches, and open questions.
> Unlike [PRD.md](PRD.md) (specification) and [README.md](README.md) (completion status), this file captures the *reasoning* behind decisions — things that would otherwise exist only in ended chat history.

---

## Session: Initialization — Architecture decisions relevant to SmoreGSA (2026-05-19)

### Key Decisions

**`GlobalSensitivity.jl` for sensitivity analysis**
Rather than native EFAST/Morris implementations, SmoreGSA wraps `GlobalSensitivity.jl`. The SM is callable (unlike the CM which is external), so the GSA library's interface fits naturally. This avoids reimplementing FFT-based EFAST index computation. SmoreGSA provides the wrapper that calls `_evaluate(sm, ...)` at the required sample points.

**`sampleSMPredictions` is not a sensitivity method**
LHS-based Monte Carlo sampling within the profile-likelihood CI region is uncertainty propagation (in SmoreBase), not global sensitivity analysis. It does not live in SmoreGSA.

---

## Session: SmoreGSA — `runSensitivity` (2026-05-20)

### Goal
Implement `runSensitivity`: GSA of CM output with respect to CM parameters, using the SM as a fast proxy for the CM.

### Key Design Decisions

**Sensitivity is of CM output to CM parameters (not SM parameters)**
Initial plan considered varying SM parameters directly. Clarified with user: the SM acts as a fast CM proxy. For any CM parameter vector requested by the GSA algorithm, the SM is evaluated by (1) interpolating SM parameter CI bounds from the nearest known cohort, (2) LHS-sampling within the resulting box, (3) averaging SM outputs over LHS draws. This mirrors MATLAB `sampleFromSMProfiles.m`.

**ICDF transform inside the callable; unit bounds to GlobalSensitivity.jl**
`ParameterPrior` stores full `Distributions.jl` distributions for CM parameters. The callable `f(u)` accepts `u ∈ [0,1]^n_cm` and applies `θ_CM[i] = quantile(cm_prior.distributions[i], u[i])` (inverse CDF). `GlobalSensitivity.gsa` is given `[[0.0, 1.0] for _ in 1:n_cm]` as bounds. This correctly handles non-uniform CM priors for both EFAST and Morris.

**Nearest-neighbor interpolation of CI bounds (v1)**
For arbitrary CM parameter vectors, the CI bounds are taken from the closest known cohort (Euclidean distance in CM parameter space). No interpolation library needed; the inner loop is O(n_cohorts) and n_cohorts is typically small. Richer interpolation (linear, RBF) deferred.

**`_runSensitivity` takes `n_cm::Int`, not bounds**
Since bounds are always `[0,1]^n_cm` (ICDF is inside the callable), the internal dispatch functions construct unit bounds from `n_cm` directly.

**Morris `total_num_trajectory` default**
When `nothing`, we pass `10 × num_trajectory` to `GlobalSensitivity.Morris`. This matches GlobalSensitivity.jl's effective default and makes the behavior explicit.

**`ST = nothing` for Morris**
Morris does not compute total-order indices; `SensitivityResult.ST` is `Union{Nothing, Matrix{T}}`.

### Status
All 6 source files implemented, module and Project.toml updated. All 5 test sets pass (20 assertions).

---

## Session: Plotting (RecipesBase + Makie extensions) (2026-05-21)

### Goal
Add `plot(sens_result)` via RecipesBase extension and `Makie.plot(sens_result)` via Makie extension.

### Key Design Decisions

**Sensitivity bar chart: CM parameters on x-axis**
With `S1 :: [n_outputs × n_cm_params]` (native GlobalSensitivity.jl layout), the most common presentation puts CM parameter names on the x-axis and groups bars by output. ST bars are shown alongside S1 bars (same x positions) when `show_ST=true` (default) and `ST` is not `nothing`.

**RecipesBase as a weak dep (extension)**
`SmoreGSAPlotsExt` activates when `RecipesBase` is loaded. Keeps SmoreGSA lean for Makie-only users.

**Makie `barplot!` with dodge for sensitivity chart**
Multiple `barplot!` calls at the same x positions, each specifying a `dodge` group index. S1 and ST bars for the same output are interleaved: S1 at odd dodge positions, ST at even. ST bars use `alpha=0.45` for reduced opacity.

**Single Makie extension (`SmoreGSAMakieExt`)**
One extension using `Makie` as the weak dep — all Makie backends (CairoMakie, GLMakie, WGLMakie) load `Makie`, so the extension fires for any backend.

### Status
All files written. Existing tests pass. No Makie tests added (large dependency, not suitable for CI).

---

## Session: `runSensitivity(problem::SMFitProblem, ...)` overload (2026-05-22)

### Goal
Add a convenience overload so callers can pass an `SMFitProblem` directly to `runSensitivity`, deriving `sm`, `times`, and `conditions` from it — consistent with how `fitSurrogate`, `_uq`, and `sampleSMPredictions` already accept `SMFitProblem`.

### Motivation
SmoreBase was refactored to introduce `SMFitProblem` as a bundle of `(sm, data, prior, loss)`. The standard Smore workflow now passes a single problem object through fitting and UQ; `runSensitivity` was the only remaining call site that still required threading `sm`, `times`, and `conditions` separately.

### Key Design Decisions

**Overload, not redefine**
The `sm`-first signature is kept as the implementation. The `problem`-first overload is a thin wrapper that delegates to it. This preserves the escape hatch for callers who have a surrogate model and UQ results but not the original `SMFitProblem` (e.g., loaded from disk).

**`problem.prior` and `problem.loss` are unused**
`problem.prior` is the SM parameter prior; SM bounds already live inside each `uqResult.fit_result.prior`. `cm_prior` (CM parameter prior) remains a separate caller-supplied positional argument. `problem.loss` is irrelevant post-fitting.

**`times` defaults to `_times(problem.data)`, fails loudly for endpoint data**
`SmoreBase._times(data)` returns `nothing` for endpoint-only `CMData`. Rather than silently forwarding `nothing` (which would error obscurely inside the inner method), the overload checks immediately and throws a descriptive `ArgumentError`. Callers with endpoint data must supply `times` explicitly.

**Two new methods, not one**
Added a `problem`-first matrix shorthand (mirroring the existing `sm`-first matrix shorthand) and the core `problem + AbstractCMSample` overload. The matrix shorthand delegates to the CMSample overload, which delegates to the `sm`-first core.

### Status
Implementation in `src/sensitivity/sensitivity.jl`. Two new test sets added to `test/runtests.jl` (happy path + endpoint error). PRD and README updated.

---

## Session: Drop Makie extension (2026-06-24)

### Goal
Mirror the SmoreBase decision to **remove the Makie extension** rather than make it composable.

### Decision
`SmoreGSAMakieExt` shipped a single `Makie.plot(r::SensitivityResult) -> Figure` that built the
`Figure`, `Axis`, and hardcoded `Legend(fig[1, 2], ax)` — uncustomizable without reaching into
`fig.content`, and adding no capability over building the bar chart directly. Per SmoreBase's
"Drop Makie extension" rationale (the only value was a convenience one-liner encoding where the
data lives; Makie's rendering/layout are available regardless; the Plots recipe already encodes
the same domain knowledge), the extension is removed and replaced with documentation.

### Implementation
- Deleted `ext/SmoreGSAMakieExt.jl`.
- `Project.toml`: removed `Makie` from `[weakdeps]`, `[extensions]`, `[compat]`.
- `docs/src/plotting.md` (new): documents the Plots recipe and states there is no Makie
  extension (`SensitivityResult` exposes `sensitivity_S1`/`sensitivity_ST`/`cm_parameter_names`/
  `output_labels` for users who roll their own). Registered in `docs/make.jl`. The hand-rolled
  Makie bar-chart recipe was cut from here as clutter; it now lives in the SmoreExamples
  notebook cells (`logistic_growth_pipeline.jl`), verified by a headless Pluto run.
- Updated `README.md`, `PRD.md`, and `CLAUDE.md` to drop Makie-extension claims.

### Decided / do-not-revisit
- **Do not reintroduce a Makie extension.** Extend the build-your-own docs instead.

### Status
Implemented on `feature/drop-makie-ext`. Tests (never loaded Makie) pending run.

---

## Session: `_runSensitivity` method-first reorder (2026-07-02)

### Goal
Small consistency fix flagged during a cross-repo SmoreBase review session: `_runSensitivity(f,
n_cm, method)` puts the dispatch key (`method::EFAST`/`::Morris`) last. SmoreBase just applied
the same fix to `quantifyUncertainty` (`method` now leads, as the extension point for future
`AbstractUQMethod` subtypes) — same rationale here for future `AbstractGSAMethod` subtypes.

### Decision
Reorder to `_runSensitivity(method, f, n_cm)` in `efast.jl` and `morris.jl`, and update the one
call site in `sensitivity.jl`. Purely internal (`_runSensitivity` is not exported); the public
`runSensitivity(sm, uqResults, cm_sample, cm_prior, method; ...)` signature is unchanged — no
user-facing or PRD behavioral change.

### Status
Implemented on `feature/runsensitivity-method-first`. Existing test suite (EFAST + Morris via
`runSensitivity`) passes unchanged.

---

## Session: `cohort` → `cm_param_set` prose cleanup (2026-07-02)

### Goal
SmoreBase renamed `param_set` → `cm_param_set` throughout its own API (see its progress.md);
SmoreGSA doesn't call any of the renamed functions directly (it takes `uqResults` and
`cm_sample` as opaque inputs), so no code changes were needed here. But its own docs/comments
said "cohort" for the same concept — updated to match for ecosystem-wide consistency.

### Decision
Replaced "cohort"/"cohort point" prose with "CM param_set" in `sensitivity.jl`, `sampling.jl`,
PRD.md, README.md, and one test comment. `n_cohorts` local variable in `sampling.jl` renamed to
`n_cm_param_sets`.

### Status
Implemented on `feature/runsensitivity-method-first` (same branch as the reorder above). Full
test suite green (29 tests).

---

## Session: `runSensitivity` public API — method-first reorder (2026-07-02)

### Goal
The "`_runSensitivity` method-first reorder" session above deliberately left the public
`runSensitivity(sm, uqResults, cm_sample, cm_prior, method; ...)` signature unchanged, reasoning
it was purely an internal-helper consistency fix. Revisited: that was inconsistent on its own
terms — the stated rationale for `method`-first (it's the dispatch/extension point for future
method subtypes) applies at least as much to the public entry point as to the internal helper,
and it now diverges from SmoreBase's public `quantifyUncertainty(method, problem, fitResult,
...)`, which *does* lead with `method`.

### Decision
Reorder all four `runSensitivity` methods in `sensitivity.jl` to `runSensitivity(method,
sm_or_problem, uqResults, cm_params_or_sample, cm_prior; kwargs...)`. The two
`AbstractMatrix`-forwarding convenience overloads keep their `args...` tail, which now absorbs
only `cm_prior` (previously `cm_prior, method` together) — mechanically unaffected since it's
positional forwarding, not explicit destructuring.

### Breaking change (deliberate — pre-1.0)
Every caller must move `method` from last to first. Updated: `sensitivity.jl` (implementation +
both docstrings), `README.md`, `PRD.md`, and all 10 call sites in `test/runtests.jl`.

### Cross-repo follow-ups (tracked, not part of this branch)
- **SmoreExamples**: `examples/logistic_growth_pipeline.jl` has 3 `runSensitivity` call sites
  (EFAST, Morris, custom `outputFn`) using the old argument order.

### Status
Implemented on `feature/runsensitivity-public-method-first`. Full test suite green.

---

## Session: Grouped + stacked bar chart for `plot(::SensitivityResult)` (2026-07-02)

### Goal
`plot(result)` was drawing one `@series` per output for S1 and one for ST, with no
`bar_position` set, so Plots overlaid/stacked bars across *all* outputs at the same x
(CM parameter) instead of grouping them — flagged while writing `cm_posterior_pipeline.jl`
in SmoreExamples. Requested redesign: cluster by output or by CM parameter (output default),
with bars dodged within each cluster and, per bar, S1 stacked with ST−S1 on top.

### Decision
Added `groupby::Symbol = :output` plot attribute (`:output` or `:parameter`) selecting the
cluster axis; the other axis becomes the dodge groups within each cluster. Bar x-positions are
computed manually (`cluster_index + offset(subgroup)`), since achieving grouping this way
sidesteps a real Plots.jl limitation found while implementing this: `bar_position` is declared
in the attribute table (default `:overlay`, docs literally say "may only be partially
implemented") but is never read anywhere in the GR-backend drawing code — setting
`bar_position := :stack` did nothing and just triggered "attribute not supported" warnings.
Stacking is instead done via the `:bar` recipe's actual bottom-of-bar mechanism: `fillrange`
(default `0`) sets where the bar starts, so the ST segment is a second series with
`y = ST` and `fillrange := S1` — drawing a rectangle from S1 up to ST, i.e. the S1-labeled
segment plus a lighter ST−S1 segment on top, without needing `bar_position` at all.

Also renamed the plot attribute from the originally-planned `group` to `groupby`: `group` is a
reserved Plots/RecipesPipeline keyword (its own automatic series-splitting mechanism) and
collided with `SensitivityResult`'s dispatch before the recipe body ever ran.

Verified visually, not just structurally: rendered actual GR PNGs for both `groupby` modes,
`show_ST=false`, and a no-ST (Morris) result, and inspected them — `apply_recipe` series-count
assertions alone would not have caught either the `bar_position` no-op or the `group` keyword
collision, both of which produced *valid* `RecipeData` that only looked wrong once rendered.

### Breaking change (deliberate — pre-1.0)
Series count per `plot(result)` call changed: previously 2 series per output (S1, ST);
now 1 subgroup's worth of series per bar-cluster-spanning series (2 if ST available, 1 if not),
regardless of cluster count. Updated `test/runtests.jl`'s `apply_recipe` assertions accordingly
and added coverage for both `groupby` modes.

### Status
Implemented on `feature/grouped-stacked-sensitivity-bars`. Full test suite green.
