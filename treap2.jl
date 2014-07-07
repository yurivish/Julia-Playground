module Treaps

import Base: show, isempty, add!, minimum, maximum

export Treap, show, isempty, add!, delete!, minimum, maximum, left, right, key

type Treap{K}
	priority::Float64
	key::K
	left::Treap{K}
	right::Treap{K}
	Treap(key, priority, left, right) = new(priority, key, left, right)
	Treap(key) = new(rand(), key, Treap{K}(), Treap{K}())
	Treap() = new(Inf)
end
show(io::IO, t::Treap) = show(io, "key: $(t.key), priority: $(t.priority)")
isempty(t::Treap) = t.priority == Inf

key(t::Treap) = t.key
left(t::Treap) = t.left
right(t::Treap) = t.right

function add!{K}(t::Treap{K}, key::K)
	if isempty(t)
		t.key = key
		t.priority = rand()
		t.left = Treap{K}()
		t.right = Treap{K}()
		return t
	end

	if key < t.key
		t.left = add!(t.left, key)
		t.left.priority < t.priority ? rotate_right!(t) : t
	else
		@assert t.key < key "A treap may not contain duplicate keys: $key, $(t.key)"
		t.right = add!(t.right, key)
		t.right.priority < t.priority ? rotate_left!(t) : t
	end
end

function merge!{K}(left::Treap{K}, right::Treap{K})
	isempty(t.left)  && return right
	isempty(t.right) && return left
	if left.priority < right.priority
		result = left
		result.right = merge!(left.right, right)
	else
		result = right
		result.left = merge!(left, result.left)
	end
	result
end

function remove!{K}(t::Treap{K}, key::K)
	isempty(t) && throw(KeyError(key))
	if key == t.key
		merge!(t.left, t.right)
	elseif key < t.key
		t.left = remove!(t.left, key)
		t.left.priority < t.priority ? rotate_right!(t) : t
	else
		t.right = remove!(t.right, key)
		t.right.priority < t.priority ? rotate_left!(t) : t
	end
end

function minimum(t::Treap)
	isempty(t) && error("An empty treap has no minimum.")
	while !isempty(t.left) t = t.left end
	t.key
end

function maximum(t::Treap)
	isempty(t) && error("An empty treap has no maximum.")
	while !isempty(t.right) t = t.right end
	t.key
end
function rotate_right!(root::Treap)
	@assert !isempty(root)
	newroot = root.left
	root.left = newroot.right
	newroot.right = root
	newroot
end

function rotate_left!(root::Treap)
	@assert !isempty(root)
	newroot = root.right
	root.right = newroot.left
	newroot.left = root
	newroot
end

end # module

using Treaps
using SSS

immutable Vec2{T}
	x::T
	y::T
end
Base.getindex(v::Vec2, n::Int) = n == 1 ? v.x : n == 2 ? v.y : throw("Vec2 indexing error.")
Base.length(v::Vec2) = 2
Base.rand{T}(::Type{Vec2{T}}) = Vec2(rand(T), rand(T))
<(a::Vec2, b::Vec2) = shuffless(a, b)

function benchmark_treap(numelements, numqueries)
	for i in 1:10
		arr = unique([rand(Vec2{Uint8}) for i in 1:numelements])
		t = Treap{Vec2{Uint8}}()
		for v in arr
			t = add!(t, v)
		end

		queries = [rand(Vec2{Uint8}) for i in 1:numqueries]

		@time for q in queries
			result = nearest(t, q)
			# result_sqdist = SSS.sqdist(q, result)

			# correct_result = nearest(arr, q)
			# correct_sqdist = SSS.sqdist(q, correct_result)

			# if result_sqdist != correct_sqdist
			# 	result_dist = sqrt(result_sqdist)
			# 	correct_dist = sqrt(correct_sqdist)
			# 	println("Mismatch when searching for ", q, ":")
			# 	println("\t Result: ", result, "\t", result_dist)
			# 	println("\tCorrect: ", correct_result, "\t", correct_dist)
			# 	println("\t% error: ", 100 * (1 - correct_dist / result_dist), "%")
			# 	println()
			# end
		end
	end
end

benchmark_treap(100000, 100000)