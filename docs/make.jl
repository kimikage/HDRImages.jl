using Documenter, HDRImages
using HDRColorTypes
using ColorTypes
using FixedPointNumbers
using Colors

makedocs(
    clean=false,
    warnonly=true, # FIXME
    checkdocs=:exports,
    modules=[HDRImages],
    format=Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true",
                           assets = []),
    sitename="HDRImages",
    pages=[
        "Introduction" => "index.md",
        "API Reference" => "api.md",
    ]
)

deploydocs(
    repo="github.com/kimikage/HDRImages.jl.git",
    devbranch = "main",
    push_preview = true
)
