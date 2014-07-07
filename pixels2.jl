module Pixels2

include("ui.jl")
include("bag.jl")

immutable Point3{T}
    x::T
    y::T
    z::T
end
distsq(p::Point3, q::Point3) = (p.x - q.x)^2 + (p.y - q.y)^2 + (p.z - q.z)^2

immutable Point4{T}
    x::T
    y::T
    z::T
    w::T
end
distsq(p::Point4, q::Point4) = (p.x - q.x)^2 + (p.y - q.y)^2 + (p.z - q.z)^2 + (p.w - q.w)^2

immutable Loc
    x::Int16
    y::Int16
    data::Point3{Uint8}
    bagindex::Int
    Loc(x, y) = new(x, y, Point3{Uint8}(0, 0, 0), 0)
    Loc(x, y, data) = new(x, y, data, 0)
end
Base.size(loc::Loc) = size(loc.data)
Base.getindex(loc::Loc, n) = loc.data[n]
Base.getindex(arr::Array, loc::Loc) = arr[loc.x, loc.y]

type Neighbors end
bit1(n) = bool(n & 0b1)
bit2(n) = bool(n & 0b10)
bit3(n) = bool(n & 0b100)
cornercoord(n) = -2n + 1
edgecoords(state) = bit2(state) == bit3(state) ? (int(bit2(state)), int(~bit3(state))) : (-bit2(state), -bit3(state))
Base.start(iter::Neighbors) = 0
Base.next(iter::Neighbors, state) = (
        (isodd(state) ? (cornercoord(bit3(state)), cornercoord(bit2(state))) : edgecoords(state)),
        state + 1
)
Base.done(iter::Neighbors, state) = state == 8

neighbors(loc, arr) = map(
    c -> arr[
        clamp(loc.x + c[1], 1, sizeof(arr, 1)),
        clamp(loc.y + c[2], 1, sizeof(arr, 2))
    ], Neighbors()
)

neighbors(loc) = map(c -> (loc.x + c[1], loc.y + c[2]), Neighbors())

isnominated(loc::Loc) = loc.bagindex != 0

function nominate!(loc, frontier::Bag{Loc})
    @assert !isnominated(loc)

    # Bag add
    push!(frontier, loc)
    loc.bagindex = length(frontier)
end

function withdraw!(loc, frontier::Bag{Loc})
    @assert isnominated(loc)

    # Bag remove
    index = loc.bagindex
    deleteat!(frontier, index)
    length(frontier) >= index && (frontier[index].bagindex = index)
    loc.bagindex = 0
end

function nearest(frontier, point)
    best = frontier[1]
    best_dist::Float64 = Inf
    for loc in frontier
        dist = distsq(point, loc.data)
        if dist < best_dist
            best, best_dist = loc, dist
        end
    end
    best
end

function place!(canvas, color, frontier)
    candidate = nearest(frontier, Point3(color.r, color.g, color.b))

    # Place the color
    emptyneighbors = filter((c) -> !canvas.filled[c[1], c[2]], neighbors(candidate))
    locx, locy = emptyneighbors[rand(1:end)]
    loc = Loc(locx, locy)
    canvas.pixels[loc] = color

    # Update the frontier
    for (x, y) in neighbors(loc)
        canvas.emptyneighbors[x, y] -= 1
        # NOTE: Have to be able to efficiently locate an element of the frontier based on its (x, y)
        # Use the coordinates to compute the data, then index into the frontier based on the data.
        canvas.nominated[x, y] && canvas.emptyneighbors[x, y] == 0 && withdraw!(Loc(x, y, canvas.pixels[x, y]), frontier)
    end

    if canvas.emptyneighbors[loc] == 0
        nominate!(loc, frontier)
        canvas.nominated[loc] = true
    end
end

immutable Canvas
    pixels::Array{GLPixel}
    nominated
    filled
    emptyneighbors::Array{Uint8}
    Canvas(pixels) = new(pixels, falses(size(pixels)), falses(size(pixels)), fill(uint8(8), size(pixels)))
end

function go(pixels)
    canvas = Canvas(pixels)
    frontier = Bag{Loc}(length(pixels))
    add!(frontier, Loc(30, 30))
    for i in 1:length(pixels)
        color = rand(GLPixel)
        place!(canvas, color, frontier)
        produce(pixels)
    end
    pixels
end
# println("going.")
go(zeros(GLPixel, 100, 100))

# display(100, 100, go; title="Pixels")
end