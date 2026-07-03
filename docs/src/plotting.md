# Plotting

SmoreGSA ships a **Plots.jl recipe** for `SensitivityResult`. Load any Plots backend
to activate `SmoreGSAPlotsExt`, then call `plot`:

```julia
using Plots, SmoreGSA
plot(sens_result)                       # clustered by output (default); one bar per CM parameter
plot(sens_result; groupby = :parameter) # clustered by CM parameter; one bar per output
plot(sens_result; show_ST = false)      # S1 only, no stacking
```

Each bar shows S1 at the bottom (solid) with ST (lighter fill) behind it when ST is
available.
