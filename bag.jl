type Bag{T}
	v::Vector{T}
	size::Int
	Bag(maxsize::Int) = new(Array(T, maxsize), 0)
end

Base.length(b::Bag) = b.size
Base.isempty(b::Bag) = b.size == 0
Base.start(b::Bag) = 1
Base.next(b::Bag, state) = b[state], state + 1
Base.done(b::Bag, state) = state > length(b)

function Base.getindex(b::Bag, i::Int)
	@assert 1 <= i <= b.size
	b.v[i]
end

function Base.push!{T}(b::Bag{T}, item::T)
	@assert b.size < size(b.v, 1)
	b.size += 1
	b.v[b.size] = item
	b
end

function Base.deleteat!(b::Bag, i::Int)
	@assert 1 <= i <= b.size
	item = b.v[i]
	b.v[i] = b.v[b.size]
	b.size -= 1
	b
end