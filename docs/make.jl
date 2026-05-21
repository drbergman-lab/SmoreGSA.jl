using SMoReGloS
using Documenter

DocMeta.setdocmeta!(SMoReGloS, :DocTestSetup, :(using SMoReGloS); recursive=true)

makedocs(;
    modules=[SMoReGloS],
    authors="Daniel Bergman <danielrbergman@gmail.com> and contributors",
    sitename="SMoReGloS.jl",
    format=Documenter.HTML(;
        canonical="https://drbergman-lab.github.io/SMoReGloS.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/drbergman-lab/SMoReGloS.jl",
    devbranch="main",
)
