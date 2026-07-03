module SmoreGSAPlotsExt

using SmoreGSA
using SmoreBase
using RecipesBase

# ── SensitivityResult recipe ──────────────────────────────────────────────────

"""
    plot(result::SensitivityResult)

Grouped bar chart of global sensitivity indices: one cluster of bars per
`groupby` category, one bar per remaining category within each cluster. When
total-order indices are available (`EFAST`) and `show_ST` is `true` (default),
each bar is split into a bottom S1 segment and a top ST−S1 segment (so the
full bar height is ST), distinguished by fill opacity.

# Plot attributes
- `groupby::Symbol = :output` — `:output` clusters bars by output variable
  (one bar per CM parameter within each cluster), `:parameter` clusters by CM
  parameter (one bar per output within each cluster)
- `show_ST::Bool = true` — whether to stack the ST−S1 segment on top of S1
  when ST is available

# Example
```julia
using Plots
plot(sens_result)                      # grouped by output (default)
plot(sens_result; groupby = :parameter)
plot(sens_result; show_ST = false)     # S1 only, no stacking
```
"""
@recipe function f(r::SensitivityResult)
    S1 = sensitivity_S1(r)
    ST = sensitivity_ST(r)
    has_ST = ST !== nothing

    groupby = pop!(plotattributes, :groupby, :output)
    show_ST = pop!(plotattributes, :show_ST, true) && has_ST

    groupby in (:output, :parameter) || throw(ArgumentError(
        "groupby must be :output or :parameter, got :$groupby"
    ))

    n_out, n_cm = size(S1)
    param_names = r.cm_parameter_names
    output_lbls = r.output_labels

    # Reorient both matrices to [n_clusters × n_sub] so a single pair of
    # accessors below works for either grouping — S1/ST are natively
    # [n_out × n_cm], which is already [cluster × sub] for groupby == :output
    # and needs transposing for groupby == :parameter.
    if groupby == :output
        n_clusters, n_sub      = n_out, n_cm
        cluster_lbls, sub_lbls = output_lbls, param_names
        M1 = S1
        MT = has_ST ? ST : nothing
    else
        n_clusters, n_sub      = n_cm, n_out
        cluster_lbls, sub_lbls = param_names, output_lbls
        M1 = permutedims(S1)
        MT = has_ST ? permutedims(ST) : nothing
    end
    val_S1(sub, clus) = M1[clus, sub]
    val_ST(sub, clus) = MT[clus, sub]

    seriestype := :bar
    xticks     := (1:n_clusters, cluster_lbls)
    xlabel     := groupby == :output ? "Output" : "CM Parameter"
    ylabel     := "Sensitivity index"
    legend     := :outertopright

    bar_width_total = 0.8
    w = bar_width_total / n_sub

    for sub in 1:n_sub
        offset  = (sub - (n_sub + 1) / 2) * w
        xs      = (1:n_clusters) .+ offset
        s1_vals = [val_S1(sub, c) for c in 1:n_clusters]
        name    = n_sub > 1 ? sub_lbls[sub] : "S1"

        @series begin
            bar_width   := w
            label       := name
            seriescolor := sub
            (xs, s1_vals)
        end

        if show_ST
            st_vals = [val_ST(sub, c) for c in 1:n_clusters]
            @series begin
                bar_width   := w
                fillrange   := s1_vals
                seriescolor := sub
                fillalpha   := 0.45
                label       := ""
                (xs, st_vals)
            end
        end
    end
end

end # module
