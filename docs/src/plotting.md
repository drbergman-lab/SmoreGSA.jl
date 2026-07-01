# Plotting

SmoreGSA ships a **Plots.jl recipe** for `SensitivityResult`. Load any Plots backend
to activate `SmoreGSAPlotsExt`, then call `plot`:

```julia
using Plots, SmoreGSA
plot(sens_result)                 # grouped bar chart: S1 (and ST when available)
plot(sens_result; show_ST = false)
```
