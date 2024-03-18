using Test, HDRImages

import HDRImages: product_xy, product_yx
res = HDRImages.RadianceHDRFiles.parse_resolution

@testset "iterators" begin
    @testset "product_yx (row-major)" begin
        # The standard orientation
        @testset "-Y +X" begin
            mat = [
                1 2 3
                4 5 6
            ]
            @test res("-Y 2 +X 3") == (size(mat), true, (false, false))
            out = [mat[i...] for i in product_yx((false, false), mat)]
            @test out == [1 4; 2 5; 3 6]
        end
        # The X ordering has been reversed.
        @testset "-Y -X" begin
            mat = [
                3 2 1
                6 5 4
            ]
            @test res("-Y 2 -X 3") == (size(mat), true, (false, true))
            out = [mat[i...] for i in product_yx((false, true), mat)]
            @test out == [1 4; 2 5; 3 6]
        end
        # The image has been flipped left to right and also top to bottom,
        # which is the same as rotating it by 180°.
        @testset "+Y -X" begin
            mat = [
                6 5 4
                3 2 1
            ]
            @test res("+Y 2 -X 3") == (size(mat), true, (true, true))
            out = [mat[i...] for i in product_yx((true, true), mat)]
            @test out == [1 4; 2 5; 3 6]
        end
        # The image has been flipped top to bottom from the standard.
        @testset "+Y +X" begin
            mat = [
                4 5 6
                1 2 3
            ]
            @test res("+Y 2 +X 3") == (size(mat), true, (true, false))
            out = [mat[i...] for i in product_yx((true, false), mat)]
            @test out == [1 4; 2 5; 3 6]
        end
    end
    # For minor Radiance resolution settings, the interpretation does not seem
    # to be unified across implementations.
    @testset "product_xy (column-major)" begin
        # The image has been rotated 90° clockwise.
        # (I.e., rotate 90° counter-clockwise to restore.)
        @testset "+X +Y" begin
            mat = [
                3 6
                2 5
                1 4
            ]
            @test res("+X 2 +Y 3") == (size(mat), false, (true, false))
            out = [mat[i...] for i in product_xy((true, false), mat)]
            @test out == [1 4; 2 5; 3 6]
        end
        # The image has been rotated 90° clockwise, then flipped top to bottom.
        @testset "-X +Y" begin
            mat = [
                6 3
                5 2
                4 1
            ]
            @test res("-X 2 +Y 3") == (size(mat), false, (true, true))
            out = [mat[i...] for i in product_xy((true, true), mat)]
            @test out == [1 4; 2 5; 3 6]
        end
        # The image has been rotated 90° counter-clockwise.
        @testset "-X -Y" begin
            mat = [
                4 1
                5 2
                6 3
            ]
            @test res("-X 2 -Y 3") == (size(mat), false, (false, true))
            out = [mat[i...] for i in product_xy((false, true), mat)]
            @test out == [1 4; 2 5; 3 6]
        end
        # The image has been rotate 90° counter-clockwise, then flipped top to bottom.
        @testset "+X -Y" begin
            mat = [
                1 4
                2 5
                3 6
            ]
            @test res("+X 2 -Y 3") == (size(mat), false, (false, false))
            out = [mat[i...] for i in product_xy((false, false), mat)]
            @test out == [1 4; 2 5; 3 6]
        end
    end
end
