immutable Rgb{T}
    r::T
    g::T
    b::T
    Rgb() = new(zero(T), zero(T), zero(T))
    Rgb(r, g, b) = new(r, g, b)
end
Base.zero{T}(::Rgb{T}) = Rgb{T}()
Base.zero{T}(::Type{Rgb{T}}) = Rgb{T}()
Base.convert{T}(::Type{Rgb{T}}, p::Rgb) = Rgb{T}(convert(T, p.r), convert(T, p.g), convert(T, p.b))
Base.show{T <: Integer}(io::IO, p::Rgb{T}) = show(io, "Rgb{$T}($(p.r + 0), $(p.g + 0), $(p.b + 0))")

Base.sum(p::Rgb) = p.r + p.g + p.b

Base.start(p::Rgb) = 1
Base.next{T}(p::Rgb{T}, state::Int) =
    state == 1 ? (p.r, 2) :
    state == 2 ? (p.g, 3) :
    state == 3 ? (p.b, 4) : throw("Iteration state error.")
Base.done(p::Rgb, state::Int) = state == 4
Base.getindex{T}(p::Rgb{T}, n::Int) = n == 1 ? p.r : n == 2 ? p.g : n == 3 ? p.b : throw("Color indexing error.")
Base.size(p::Rgb) = (3,)
Base.size(p::Rgb, n) = n == 1 ? 3 : throw("Invalid dimension.")


Base.rand{T}(::Type{Rgb{T}}) = Rgb{T}(rand(T), rand(T), rand(T))

function sqdiff(x::Rgb, y::Rgb)
    (x.r - y.r) * (x.r - y.r) +
    (x.g - y.g) * (x.g - y.g) +
    (x.b - y.b) * (x.b - y.b)
end

typealias Pixel Rgb{Uint8}
typealias GLPixel Rgb{Uint8} # BUG: Should be Rgb{GLubyte}, but this causes odd dependency chains

-{X, Y}(x::Rgb{X}, y::Rgb{Y}) = Rgb{promote_type(X, Y)}(x.r - y.r, x.g - y.g, x.b - y.b)
+{X, Y}(x::Rgb{X}, y::Rgb{Y}) = Rgb{promote_type(X, Y)}(x.r + y.r, x.g + y.g, x.b + y.b)
/{X, Y}(x::Rgb{X}, y::Rgb{Y}) = Rgb{promote_type(X, Y)}(x.r / y.r, x.g / y.g, x.b / y.b)
*{X, Y}(x::Rgb{X}, y::Rgb{Y}) = Rgb{promote_type(X, Y)}(x.r * y.r, x.g * y.g, x.b * y.b)

# TODO: Could these be sped up by specializing on the type of number?
-{T}(x::Rgb{T}, y::Number) = Rgb{T}(x.r - y, x.g - y, x.b - y)
+{T}(x::Rgb{T}, y::Number) = Rgb{T}(x.r + y, x.g + y, x.b + y)
/{T}(x::Rgb{T}, y::Number) = Rgb{T}(x.r / y, x.g / y, x.b / y)
*{T}(x::Rgb{T}, y::Number) = Rgb{T}(x.r * y, x.g * y, x.b * y)

-{T}(x::Number, y::Rgb{T}) = Rgb{T}(x - y.r, x - y.g, x - y.b)
+{T}(x::Number, y::Rgb{T}) = Rgb{T}(x + y.r, x + y.g, x + y.b)
/{T}(x::Number, y::Rgb{T}) = Rgb{T}(x / y.r, x / y.g, x / y.b)
*{T}(x::Number, y::Rgb{T}) = Rgb{T}(x * y.r, x * y.g, x * y.b)

function hue(c::Pixel)
    c_min = min(c.r, c.g, c.b)
    c_max = max(c.r, c.g, c.b)
    l = (c_max - c_min) / 2

    if c_max == c_min
        return 0.0
    end

    if l < 0.5; s = (c_max - c_min) / (c_max + c_min)
    else;       s = (c_max - c_min) / (2.0 - c_max - c_min)
    end

    if c_max == c.r
        h = (c.g - c.b) / (c_max - c_min)
    elseif c_max == c.g
        h = 2.0 + (c.b - c.r) / (c_max - c_min)
    else
        h = 4.0 + (c.r - c.g) / (c_max - c_min)
    end

    h *= 60
    if h < 0
        h += 360
    elseif h > 360
        h -= 360
    end

    return h
end