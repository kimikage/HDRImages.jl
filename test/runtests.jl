using Test, HDRImages
using TiffImages
import Downloads
using Aqua

studio_hdr = joinpath(@__DIR__, "poly_haven_studio_1k.hdr")

if !isfile(studio_hdr)
    url = "https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/1k/poly_haven_studio_1k.hdr"
    Downloads.download(url, studio_hdr)
end


@testset "Aqua" begin
    Aqua.test_all(HDRImages)
end

@testset "utilities" begin
    include("utilities.jl")
end

@testset "radiance" begin
    include("radiance.jl")
end
