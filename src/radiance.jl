module RadianceHDRFiles

using ..ColorTypes
using ..HDRColorTypes
import ..product_yx
import ..product_xy

export read_radiance, read_radiance_header

struct RadianceHDRFormat{S} end
const RleRGBE32 = RadianceHDRFormat{Symbol("32-bit_rle_rgbe")}()
const RleXYZE32 = RadianceHDRFormat{Symbol("32-bit_rle_xyze")}()

const MIN_ELEN = 8 # minimum scanline length for encoding
const MAX_ELEN = Int(0x7fff)# maximum scanline length for encoding
const MIN_RUN = 4 # minimum run length

struct RadianceHDRHeader
    format::RadianceHDRFormat
    size::Tuple{Int,Int}
    rowmajor::Bool
    flipped::Tuple{Bool,Bool}
    exposure::Float64
    colorcorr::NTuple{3,Float64}
    software::String
    pixaspect::Float64
    view::String
    primaries::NTuple{4,xyY{Float64}}
    comments::Vector{String}
    variables::Dict{Symbol,String}
end

const RADIANCE_MAGIC = "#?RADIANCE"
const DEFAULT_PRIMARIES = "0.640 0.330 0.290 0.600 0.150 0.060 0.333 0.333"

function read_radiance(filepath::AbstractString)
    open(filepath, "r") do f
        return read_radiance(f)
    end
end

function read_radiance(io::IO)
    header = read_radiance_header(io)
    C = header.format === RleRGBE32 ? RGBE32{Float32} : XYZE32{Float32}
    image = read_scanlines(C, io, header)
    return image
end

function read_radiance_header(filepath::AbstractString)
    open(filepath, "r") do f
        read_radiance_header(f)
    end
end

function read_radiance_header(io)
    id = readline(io)
    id == RADIANCE_MAGIC || error("invalid identifier")

    comments = Vector{String}()
    vars = Dict{Symbol,String}()
    while !eof(io)
        line = readline(io)
        isempty(line) && break
        if startswith(line, '#')
            push!(comments, line)
            continue
        end
        m = match(r"^(\w+)=([\w\-]+)$", line)
        m !== nothing || error("invalid variable description")
        v = Symbol(m[1])
        if haskey(vars, v)
            vars[v] = vars[v] * "\n" * m[2]
        else
            vars[v] = m[2]
        end
    end
    haskey(vars, :FORMAT) || error("format not defined")
    formatstr = pop!(vars, :FORMAT)
    format = RleRGBE32
    if formatstr == "32-bit_rle_rgbe"
    elseif formatstr == "32-bit_rle_xyze"
        format = RleXYZE32
    else
        error("unknown format: $formatstr")
    end

    exposure = NaN64
    if haskey(vars, :EXPOSURE)
        vals = split(pop!(vars, :EXPOSURE))
        fvals = tryparse.(Float64, vals)
        any(isnothing, fvals) && error("invalid exposure")
        exposure = prod(fvals)
    end
    colorcorr = parse_colorcorr(haskey(vars, :COLORCORR) ? pop!(vars, :COLORCORR) : "")
    software = haskey(vars, :SOFTWARE) ? pop!(vars, :SOFTWARE) : ""
    pixaspect = 1.0
    if haskey(vars, :PIXASPECT)
        pixaspect = tryparse(Float64, pop!(vars, :PIXASPECT))
        pixaspect isa Float64 || error("invalid pixaspect")
    end

    view = haskey(vars, :VIEW) ? pop!(vars, :VIEW) : ""
    primaries = parse_primaries(get(vars, :PRIMARIES, DEFAULT_PRIMARIES))

    line = readline(io)
    size, rowmajor, flipped = parse_resolution(line)

    return RadianceHDRHeader(
        format,
        size,
        rowmajor,
        flipped,
        exposure,
        colorcorr,
        software,
        pixaspect,
        view,
        primaries,
        comments,
        vars,
    )
end

function parse_colorcorr(str::AbstractString)
    vecs = split(str, '\n', keepempty=false)
    colorcorr = (1.0, 1.0, 1.0)
    for vec in vecs
        fvals = tryparse.(Float64, split(vec))
        length(fvals) == 3 && !any(isnothing, fvals) || error("invalid colorcorr")
        colorcorr .*= fvals
    end
    return colorcorr
end

function parse_primaries(str::AbstractString)
    fvals = tryparse.(Float64, split(str))
    length(fvals) == 8 && !any(isnothing, fvals) || error("invalid primaries")
    rp = xyY{Float64}(fvals[1], fvals[2], 1.0)
    gp = xyY{Float64}(fvals[3], fvals[4], 1.0)
    bp = xyY{Float64}(fvals[5], fvals[6], 1.0)
    wp = xyY{Float64}(fvals[7], fvals[8], 1.0)
    return (rp, gp, bp, wp)
end

function parse_resolution(str::AbstractString)
    m = match(r"^([\-+])([XY]) (\d+) ([\-+])([XY]) (\d+)$", str)
    m !== nothing || error("invalid resolution")
    rowmajor = true
    if m[2] == "Y" && m[5] == "X"
    elseif m[2] == "X" && m[5] == "Y"
        rowmajor = false
    else
        error("invalid resolution")
    end
    flippedy = m[rowmajor ? 1 : 4] == "+"
    flippedx = m[rowmajor ? 4 : 1] == "-"
    xr = tryparse(Int, m[rowmajor ? 6 : 3])
    xr isa Int || error("invalid x resolution")
    yr = tryparse(Int, m[rowmajor ? 3 : 6])
    yr isa Int || error("invalid y resolution")
    return (yr, xr), rowmajor, (flippedy, flippedx)
end

function read_scanlines(::Type{C}, io::IO, header::RadianceHDRHeader) where {C<:CCCE32}
    h, w = header.size
    flipped = header.flipped
    image = Matrix{C}(undef, h, w)
    itr = header.rowmajor ? product_yx(flipped, image) : product_xy(flipped, image)
    n = header.rowmajor ? w : h
    st = iterate(itr)
    while st !== nothing
        st = read_colors!(io, image, itr, st, n)
    end
    return image
end

function update_color(::Type{N}, image::AbstractMatrix{C}, itr, st, val::UInt8) where {N,C}
    # Since `RGBE32`` and `XYZE32`` are immutable structs, their fields cannot be changed.
    i, s = st
    @inbounds prev = image[i...]
    c1 = N === Val{0x1} ? val : prev.c1
    c2 = N === Val{0x2} ? val : prev.c2
    c3 = N === Val{0x3} ? val : prev.c3
    e = N === Val{0x4} ? val : prev.e
    @inbounds image[i...] = ccce32(C, c1, c2, c3, e)
    return iterate(itr, s)
end

function read_colors!(io::IO, image::AbstractMatrix{C}, itr, st, len::Int) where {C<:CCCE32}

    u8() = read(io, UInt8)

    if len < MIN_ELEN || len > MAX_ELEN || peek(io) !== 0x02
        return read_oldcolors!(io, image, itr, st, len)
    end
    c1, c2, c3, e = u8(), u8(), u8(), u8()
    eof(io) && error("unexpected termination")
    if c2 !== 0x02 || (c3 & 0x80) !== 0x00
        col = ccce32(C, c1, c2, c3, e)
        image[st[1]...] = col
        return read_oldcolors!(io, image, itr, iterate(itr, st[2]), len - 1, col)
    end
    len2 = UInt16(c3) << 0x8 | e
    if len2 != len
        error("length mismatch. $(repr(len2)) != $(repr(len % UInt16))")
    end

    function decode(::Type{N}, s, j) where {N}
        while j > 0
            code = u8()
            if code > 0x80 # run
                code &= 0x7f
                val = u8()
                for _ in 0x1:code
                    s = update_color(N, image, itr, s, val)
                end
            else
                for _ in 0x1:code
                    s = update_color(N, image, itr, s, u8())
                end
            end
            j -= code
        end
        if j != 0
            error("invalid scanline data")
        end
        return s
    end

    lastst = st
    for comp in (Val{0x1}, Val{0x2}, Val{0x3}, Val{0x4})
        lastst = decode(comp, st, len)
    end
    return lastst
end

function read_oldcolors!(io::IO, image::AbstractMatrix{C}, itr, st, len::Int, prev=C()) where {C<:CCCE32}

    u8() = read(io, UInt8)

    s = st
    rshift = 0x0
    j = len
    while j > 0
        c1, c2, c3, e = u8(), u8(), u8(), u8()
        !eof(io) || error("unexpected termination")
        if c1 === 0x01 && c2 === 0x01 && c3 === 0x01
            i = min(Int(e) << rshift, j)
            for _ in 1:i
                image[s[1]...] = prev
                s = iterate(itr, s[2])
            end
            len -= i
            rshift += 0x8
        else
            prev = ccce32(C, c1, c2, c3, e)
            image[s[1]...] = prev
            s = iterate(itr, s[2])
            j -= 1
        end
    end
    return s
end

end # module
