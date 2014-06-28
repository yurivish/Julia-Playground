module Pixels

using Images
using ArgParse

include("ui.jl")
include("bag.jl")
include("treap.jl")
include("sss.jl")

s = ArgParseSettings()
@add_arg_table s begin
    "--file", "-f"
        help = "filename for image to use as input"
        arg_type = String
        default = "images/Bachalpseeflowers.jpg"
end
parsed_args = parse_args(ARGS, s)
const target_file = parsed_args["file"]

immutable NeighborStats
    n::Int
    avg::Rgb{Uint8}
    sumvar::Uint
    sqrt_sumvar::Uint8
    NeighborStats(n, avg, sumvar) = new(n, avg, sumvar, uint8(sqrt(sumvar)))
    NeighborStats() = new(0, Rgb{Uint8}(), 0, 0)
end

type Vertex
    x::Int
    y::Int
    color::GLPixel
    filled::Bool
    nominated::Bool
    bagindex::Int
    stats::NeighborStats
    neighbors::Vector{Vertex}
    t::Float64 # Used to preserve key uniqueness and break ties in <(Vertex, Vertex)
    function Vertex(x, y)
        neighbors = Vertex[]
        sizehint(neighbors, 8)
        new(x, y, GLPixel(), false, false, 0, NeighborStats(), neighbors, rand(Float64))
    end
end

Base.start(p::Rgb) = 1
Base.next{T}(p::Rgb{T}, state::Int) =
    state == 1 ? (p.r, 2) :
    state == 2 ? (p.g, 3) :
    state == 3 ? (p.b, 4) : throw("Iteration state error.")
Base.done(p::Rgb, state::Int) = state == 4

type Canvas
    grid::Array{Vertex}
    frontier
    function Canvas(width, height, frontier)
        grid = [Vertex(x, y) for y in 1:height, x in 1:width]
 
        for x in 1:width, y in 1:height
            for nx in max(x - 1, 1):min(x + 1, width), ny in max(y - 1, 1):min(y + 1, height)
                !(nx == x && ny == y) && push!(grid[y, x].neighbors, grid[ny, nx])
            end
        end
        new(grid, frontier)
    end
end
frontier(canvas) = canvas.frontier
Base.getindex(c::Canvas, a, b) = c.grid[a, b]
neighbors(vertex::Vertex) = vertex.neighbors
isnominated(vertex::Vertex) = vertex.bagindex != 0 || vertex.nominated # TODO: Fix.

function nominate!(vertex, frontier::Bag{Vertex})
    @assert !isnominated(vertex)

    # Bag add
    push!(frontier, vertex)
    vertex.bagindex = length(frontier)
end

function withdraw!(vertex, frontier::Bag{Vertex})
    @assert isnominated(vertex)

    # Bag remove
    index = vertex.bagindex
    deleteat!(frontier, index)
    length(frontier) >= index && (frontier[index].bagindex = index)
    vertex.bagindex = 0
end

function nominate!(vertex, frontier::Treap)
    @assert !vertex.nominated
    add!(frontier, vertex)
    vertex.nominated = true
end

function withdraw!(vertex, frontier::Treap)
    @assert vertex.nominated
    remove!(frontier, vertex)
    vertex.nominated = false
end

hasemptyneighbors(vertex) = vertex.stats.n < length(neighbors(vertex))
emptyneighbors(vertex) = filter((v) -> !v.filled, neighbors(vertex))
function randemptyneighbor(vertex)
    prob = 1.0
    local neighbor
    for v in neighbors(vertex)
        if !v.filled
            if rand() < prob
                neighbor = v
            end
            prob /= 2
        end
    end
    neighbor
end

function fill!(pixels, frontier, vertex, color, outer::Bool)
    # TODO: Don't pass pixels in.
    pixels[vertex.y, vertex.x] = color

    vertex.color = color
    vertex.filled = true
    if outer
        # Outer frontier
        for v in neighbors(vertex)
            # Withdraw in order to re-insert neighbors already on the frontier,
            # as their stats have changed in a way that may influence their
            # storage in the frontier
            isnominated(v) && withdraw!(v, frontier)
            stats!(v)
            !isnominated(v) && !v.filled && nominate!(v, frontier)
        end
        isnominated(vertex) && withdraw!(vertex, frontier)
    else
        # Inner frontier
        for v in neighbors(vertex)
            # NOTE: Does something like the re-insertion above need to happen here as well?
            stats!(v)
            isnominated(v) && !hasemptyneighbors(v) && withdraw!(v, frontier)
        end
        hasemptyneighbors(vertex) && nominate!(vertex, frontier)
    end
end

# TODO: To calculate average without overflow: (R - L)/2 + L
function stats!(vertex)
    n = zero(vertex.stats.n)
    avg = var = Rgb{Float64}() #zero(vertex.stats.avg)

    for v in neighbors(vertex)
        if v.filled
            n += 1
            avg += v.color
            # Promote types before squaring, since Rgb{Uint8} * Rgb{Uint8} => Rgb{Uint8}
            var += oftype(var, v.color) * v.color
        end
    end

    if n == 0
        vertex.stats = NeighborStats()
    else
        avg = avg / n
        var = var / n - avg * avg
        vertex.stats = NeighborStats(n, Rgb{Uint8}(uint8(avg.r), uint8(avg.g), uint8(avg.b)), uint(sum(var)))
    end
end

r() = rand() - 0.5
mutate(color::GLPixel, scale) = GLPixel(
    clamp(color.r + int(scale * r()), typemin(color.r), typemax(color.r)),
    clamp(color.g + int(scale * r()), typemin(color.g), typemax(color.g)),
    clamp(color.b + int(scale * r()), typemin(color.b), typemax(color.b))
)

function nearest(frontier::Bag{Vertex}, color)
    best = frontier[1]
    best_dist::Float64 = Inf
    for v in frontier
        d = sqdiff(v.stats.avg, color) + v.stats.sumvar
        if d < best_dist
            best = v
            best_dist = d
        end
    end
    best
end

function loadimage(imgpath::String)
    im = convert(Array, imread(imgpath))
    w, h = size_spatial(im)
    colors = Pixel[]
    for i in 1:w, j in 1:h
        push!(colors, Pixel(im[i, j, 1], im[i, j, 2], im[i, j, 3]))
    end
    colors
end

SPEED = 1000

function evolve(pixels)
    (height, width) = size(pixels)
    canvas = Canvas(width, height, Bag{Vertex}(height * width))

    fill!(pixels, frontier(canvas), canvas[div(height, 2), div(width, 2)], GLPixel(255, 255, 255), true)
    for i in 1:length(canvas.grid) - 1
        vertex = frontier(canvas)[rand(1:length(frontier(canvas)))]
        color = filter(n -> n.filled, neighbors(vertex))[1].color
        fill!(pixels, frontier(canvas), vertex, mutate(color, 15), true)
        i % SPEED == 0 && produce(pixels)
    end
    pixels
end

function gencolors(imgpath::String)
    colors = shuffle!(loadimage(imgpath))
    sort!(colors, alg=QuickSort, lt=(p::Pixel, q::Pixel) -> hue(p) < hue(q))
    colors
end

function gencolors(n::Int)
    colors = [rand(GLPixel) for i in 1:n]
    # sort!(colors, alg=QuickSort, lt=(p::Pixel, q::Pixel) -> hue(p) < hue(q))
    sort!(colors, rev=true, alg=QuickSort, lt=(p::Pixel, q::Pixel) -> p.r < q.r && p.g < q.g && p.b < q.b)
    # sort!(colors, rev=true, alg=QuickSort, by=(p::Pixel) -> p.b + p.g^2)
    colors
end

function placeavg(pixels)
    (height, width) = size(pixels)
    canvas = Canvas(width, height, Treap{Vertex}())
    # colors = gencolors(length(pixels))
    colors = gencolors(target_file)
    # colors = gencolors(1000)
    i = 1
    fill!(pixels, frontier(canvas), canvas[div(height, 2), div(width, 2)], colors[i += 1], true)
    while i < length(pixels)
        color = colors[mod1(i, length(colors))]
        vertex = nearest(frontier(canvas), color)
        fill!(pixels, frontier(canvas), vertex, color, true)
        i % SPEED == 0 && produce(pixels)
        i += 1
    end
    pixels
end


function placemin(pixels)
    (height, width) = size(pixels)
    canvas = Canvas(width, height, Treap{Vertex}())
    # colors = gencolors(length(pixels))
    # colors = gencolors("Bachalpseeflowers.jpg")
    colors = gencolors(target_file)
    i = 1

    fill!(pixels, frontier(canvas), canvas[div(height, 2), div(width, 2)], colors[i += 1], false)
    # fill!(pixels, frontier(canvas), canvas[200, 200], colors[i += 1], false)
    # fill!(pixels, frontier(canvas), canvas[1, 1], colors[i += 1], false)

    while i < length(pixels)
        color = colors[mod1(i, length(colors))]
        candidate = nearest(frontier(canvas), color)
        vertex = randemptyneighbor(candidate)
        fill!(pixels, frontier(canvas), vertex, color, false)
        i % SPEED == 0 && produce(pixels)
        i += 1
    end
    pixels
end

# :min / :avg / :evo
fntype = :min

fn = fntype == :min ? placemin :
     fntype == :avg ? placeavg :
     fntype == :evo ? evolve : throw("fntype must be :min, :avg, or :evo.")

if fntype == :min || fntype == :evo
    # Minimum selection
    Base.size(p::Vertex, n) = n == 1 ? 3 : error("Vertices are one-dimensional.")
    Base.getindex(p::Vertex, n) = p.color[n]
    <(p::Vertex, q::Vertex) = p.color == q.color ? p.t < q.t : shuffless(p.color, q.color)
    <(p::Vertex, q::Rgb) = shuffless(p.color, q)
    <(p::Rgb, q::Vertex) = shuffless(p, q.color)
    dist_sq{T}(p::Rgb{T}, q::Rgb{T}) = sqdiff(p, q)
    dist_sq{T}(p::Vertex, q::Rgb{T}) = sqdiff(p.color, q)
    dist_sq{T}(p::Rgb{T}, q::Vertex) = sqdiff(p, q.color)
else
    # Average selection
    Base.size(p::Vertex, n) = n == 1 ? 4 : error("n must be 1.")
    Base.getindex(p::Vertex, n) = n < 4 ? uint8(p.stats.avg[n]) : n == 4 ? uint8(p.stats.sqrt_sumvar) : error("Index out of bounds: $n")
    # If the colors are equal, compare t values; we need this because the treap enforces uniqueness.
    <(p::Vertex, q::Vertex) = shuffless(p, q) ? true : shuffmore(p, q) ? false : p.t < q.t
    <(p::Vertex, q::Rgb) = shuffless(p, q)
    <(p::Rgb, q::Vertex) = shuffless(p, q)
    dist_sq{T}(p::Rgb{T}, q::Rgb{T}) = sqdiff(p, q)
    dist_sq{T}(p::Vertex, q::Rgb{T}) = sqdiff(p.stats.avg, q) + p.stats.sumvar
    dist_sq{T}(p::Rgb{T}, q::Vertex) = sqdiff(p, q.stats.avg) + q.stats.sumvar

    # Avg color: Hacked version with p[4] == 0
    Base.start(p::Rgb) = 1
    Base.next{T}(p::Rgb{T}, state::Int) =
        state == 1 ? (p.r, 2) :
        state == 2 ? (p.g, 3) :
        state == 3 ? (p.b, 4) :
        state == 4 ? (zero(T), 5) : throw("Iteration state error.")
    Base.done(p::Rgb, state::Int) = state == 5
    Base.getindex{T}(p::Rgb{T}, n::Int) = n == 1 ? p.r : n == 2 ? p.g : n == 3 ? p.b : n == 4 ? zero(T) : throw("Color indexing error.")
    Base.size(p::Rgb) = (4,)
    Base.size(p::Rgb, n) = n == 1 ? 4 : throw("Invalid dimension.")
end

# placemin(zeros(GLPixel, 1440, 900))
# # @time placemin(zeros(GLPixel, 200, 200))
# @time placemin(zeros(GLPixel, 100, 100))
# # @time placemin(zeros(GLPixel, 125, 125))
# @time placemin(zeros(GLPixel, 150, 150))
# # @time placemin(zeros(GLPixel, 175, 175))
# @time placemin(zeros(GLPixel, 200, 200))
# @time placemin(zeros(GLPixel, 500, 500))

# display(2560, 1440 - 22, fn; title="Pixels")
# display(1440, 900 - 22, fn; title="Pixels")
display(1000, 750, fn; title="Pixels")
# display(800, 538, fn; title="Pixels")

end
