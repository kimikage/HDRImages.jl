using Test, HDRImages
using HDRColorTypes
using ColorTypes
using TiffImages

studio_hdr = joinpath(@__DIR__, "poly_haven_studio_1k.hdr")

@testset "read_header" begin
    h = RadianceHDRFiles.read_radiance_header(studio_hdr)

    @test h.format === RadianceHDRFiles.RleRGBE32
    @test h.size === (512, 1024)
    @test h.rowmajor === true
    @test h.flipped === (false, false)
    @test isnan(h.exposure)
    @test length(h.primaries) == 4
    @test h.primaries[1] === xyY{Float64}(0.640, 0.330, 1.0)
    @test h.primaries[2] === xyY{Float64}(0.290, 0.600, 1.0)
    @test h.primaries[3] === xyY{Float64}(0.150, 0.060, 1.0)
    @test h.primaries[4] === xyY{Float64}(0.333, 0.333, 1.0)
    @test isempty(h.variables)
end

@testset "read_radiance" begin
    hdri = read_radiance(studio_hdr)

    # TiffImages does not seem to handle RGBE images correctly.
    hdrif = Matrix{RGB{Float32}}(hdri)
    TiffImages.save(joinpath(@__DIR__, "out", "poly_haven_studio_1k.tiff"), hdrif)
end
