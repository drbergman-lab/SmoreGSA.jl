module SmoreGSA

using Distributions
using GlobalSensitivity
using Random
using SmoreBase

include("sensitivity/methods.jl")
include("sensitivity/results.jl")
include("sensitivity/sampling.jl")
include("sensitivity/efast.jl")
include("sensitivity/morris.jl")
include("sensitivity/sensitivity.jl")


export runSensitivity
export EFAST
export SensitivityResult, sensitivity_S1, sensitivity_ST
export GridCMSample, ScatteredCMSample

# Re-export Morris so users don't need `using GlobalSensitivity` just to name a method.
using GlobalSensitivity: Morris
export Morris

end
