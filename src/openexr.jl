module OpenEXRFiles

using ..HDRColorTypes

export read_openexr, read_openexr_header

function read_openexr_header(filepath::AbstractString)
    open(filepath, "r") do f
        return read_header(f)
    end
end

function read_openexr_header(io::IO)

end


function read_openexr(filepath::AbstractString)
    open(filepath, "r") do f
        return read_openexr(f)
    end
end

function read_openexr(io::IO)
end

end # module
