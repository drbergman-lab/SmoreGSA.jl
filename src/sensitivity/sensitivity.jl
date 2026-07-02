"""
    runSensitivity(sm, uqResults, cm_sample, cm_prior, method; kwargs...) -> SensitivityResult

Global sensitivity analysis of CM output with respect to CM parameters, using the SM as a
fast proxy for the CM.

For each CM parameter point the GSA algorithm requires, the SM is evaluated as follows:
1. SM parameter CI bounds are interpolated at that CM parameter point from the profile
   likelihood results using `interpolator` (default: `LinearCIInterp()` on the CM grid).
2. `n_sm_samples` LHS draws are taken within the interpolated box and the SM is evaluated.
3. The average `outputFn` result gives one CM output estimate for that point.

This construction mirrors MATLAB SmoreParS `sampleFromSMProfiles.m`.

# Arguments
- `sm`        — the surrogate model (already fitted)
- `uqResults` — profile likelihood UQ results, one `ProfileLikelihoodResult` per CM param_set
- `cm_sample` — CM parameter points as an `AbstractCMSample` (e.g. `GridCMSample`)
- `cm_prior`  — `ParameterPrior` for CM parameters; distributions used via inverse-CDF
- `method`    — `EFAST(n_samples=...)` or `GlobalSensitivity.Morris(...)`

# Keyword Arguments
- `times`        — time grid for SM evaluation (required)
- `conditions`   — experimental conditions (default: `ConditionSpec()`)
- `outputFn`     — maps SM prediction `[n_times × n_outputs]` to `Vector{Float64}`;
  default: last time point of each output variable
- `n_sm_samples` — LHS draws per CM parameter point (default: 16)
- `interpolator` — CI bound interpolation method (default: `LinearCIInterp()`)
- `rng`          — random number generator (default: `Random.default_rng()`)

# Returns
`SensitivityResult` wrapping the raw `GlobalSensitivity.jl` result. Use `sensitivity_S1`
and `sensitivity_ST` for standardized index access.

# Example
```julia
cm_sample = GridCMSample(cm_params)   # cm_params is [n_cm_param_sets × n_cm_params]
result = runSensitivity(
    sm, uq_results, cm_sample, cm_prior, EFAST(n_samples=2000);
    times = t,
)
S1 = sensitivity_S1(result)   # [n_outputs × n_cm_params]
ST = sensitivity_ST(result)   # [n_outputs × n_cm_params]
```
"""
function runSensitivity(
    sm        :: AbstractSurrogateModel,
    uqResults :: Vector{<:ProfileLikelihoodResult},
    cm_params :: AbstractMatrix,
    args...;
    kwargs...,
)
    return runSensitivity(sm, uqResults, CMSample(cm_params), args...; kwargs...)
end

function runSensitivity(
    problem   :: SMFitProblem,
    uqResults :: Vector{<:ProfileLikelihoodResult},
    cm_params :: AbstractMatrix,
    args...;
    kwargs...,
)
    return runSensitivity(problem, uqResults, CMSample(cm_params), args...; kwargs...)
end

"""
    runSensitivity(problem, uqResults, cm_sample, cm_prior, method; kwargs...) -> SensitivityResult

Convenience overload that extracts `sm`, `times`, and `conditions` from `problem`, so the
same object used for `fitSurrogate` and `quantifyUncertainty` can be passed directly to `runSensitivity`.

`times` defaults to `_times(problem.data)`; pass it explicitly to use a different time grid
or when the data has no time axis (`_times` returns `nothing` for endpoint-only data, which
causes an `ArgumentError`). `problem.prior` (SM parameter prior) and `problem.loss` are not
used — SM bounds come from `uqResults`; `cm_prior` remains a separate argument.

# Arguments
- `problem`   — `SMFitProblem` bundling the surrogate model and training data
- `uqResults` — profile likelihood UQ results, one `ProfileLikelihoodResult` per CM param_set
- `cm_sample` — CM parameter points as an `AbstractCMSample` (e.g. `GridCMSample`)
- `cm_prior`  — `ParameterPrior` for CM parameters; distributions used via inverse-CDF
- `method`    — `EFAST(n_samples=...)` or `GlobalSensitivity.Morris(...)`

# Keyword Arguments
Same as the primary `runSensitivity` method. `times` defaults to `_times(problem.data)`;
`conditions` defaults to `_conditions(problem.data)`.

# Example
```julia
problem = SMFitProblem(sm, data, sm_prior)
result = runSensitivity(
    problem, uq_results, cm_sample, cm_prior, EFAST(n_samples=2000),
)
S1 = sensitivity_S1(result)   # [n_outputs × n_cm_params]
ST = sensitivity_ST(result)   # [n_outputs × n_cm_params]
```
"""
function runSensitivity(
    problem      :: SMFitProblem,
    uqResults    :: Vector{<:ProfileLikelihoodResult},
    cm_sample    :: AbstractCMSample,
    cm_prior     :: ParameterPrior,
    method       :: GlobalSensitivity.GSAMethod;
    times        :: Union{Nothing,AbstractVector} = SmoreBase._times(problem.data),
    conditions   :: ConditionSpec = SmoreBase._conditions(problem.data),
    kwargs...,
)
    times === nothing && throw(ArgumentError(
        "problem.data has no time axis; pass `times` as a keyword argument"
    ))
    return runSensitivity(problem.sm, uqResults, cm_sample, cm_prior, method;
                          times, conditions, kwargs...)
end

function runSensitivity(
    sm           :: AbstractSurrogateModel,
    uqResults    :: Vector{<:ProfileLikelihoodResult},
    cm_sample    :: AbstractCMSample,
    cm_prior     :: ParameterPrior,
    method       :: GlobalSensitivity.GSAMethod;
    times        :: AbstractVector,
    conditions   :: ConditionSpec       = ConditionSpec(),
    outputFn     :: Function            = _defaultOutputFn,
    n_sm_samples :: Int                 = 16,
    interpolator :: AbstractCIInterpolator = LinearCIInterp(),
    rng          :: AbstractRNG         = Random.default_rng(),
)
    n_cm       = length(cm_prior.distributions)
    f          = _buildCMCallable(sm, uqResults, cm_sample, cm_prior, conditions, times, outputFn, n_sm_samples, rng, interpolator)
    gsa_result = _runSensitivity(method, f, n_cm)
    n_out      = _n_outputs(gsa_result)
    return SensitivityResult(method, cm_prior.names, ["output_$i" for i in 1:n_out], gsa_result)
end
