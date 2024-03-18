

function product_yx(flipped::Tuple{Bool,Bool}, m::AbstractMatrix)
    rt, rb = firstindex(m, 1), lastindex(m, 1)
    rl, rr = firstindex(m, 2), lastindex(m, 2)

    yr = flipped[1] ? (rb:-1:rt) : (rt:rb)
    xr = flipped[2] ? (rr:-1:rl) : (rl:rr)
    return Iterators.map(t -> (t[2], t[1]), Iterators.product(xr, yr))
end

function product_xy(flipped::Tuple{Bool,Bool}, m::AbstractMatrix)
    rt, rb = firstindex(m, 1), lastindex(m, 1)
    rl, rr = firstindex(m, 2), lastindex(m, 2)

    yr = flipped[1] ? (rb:-1:rt) : (rt:rb)
    xr = flipped[2] ? (rr:-1:rl) : (rl:rr)
    return Iterators.product(yr, xr)
end
