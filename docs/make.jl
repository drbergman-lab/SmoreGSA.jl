using SmoreGSA
using Documenter

DocMeta.setdocmeta!(SmoreGSA, :DocTestSetup, :(using SmoreGSA); recursive=true)

makedocs(;
    modules=[SmoreGSA],
    authors="Daniel Bergman <danielrbergman@gmail.com> and contributors",
    sitename="SmoreGSA.jl",
    format=Documenter.HTML(;
        canonical="https://drbergman-lab.github.io/SmoreGSA.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Plotting" => "plotting.md",
    ],
)

deploydocs(;
    repo="github.com/drbergman-lab/SmoreGSA.jl",
    devbranch="main",
)
