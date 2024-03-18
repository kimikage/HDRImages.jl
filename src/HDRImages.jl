module HDRImages

using HDRColorTypes
using HDRColorTypes.ColorTypes

export AbstractRGBE, RGBE32, XYZE32

export OpenEXRFiles, RadianceHDRFiles
#export read_openexr
export read_radiance, read_radiance_header

include("utilities.jl")

include("openexr.jl")
include("radiance.jl")

using .OpenEXRFiles
using .RadianceHDRFiles

end # module
