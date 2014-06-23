import Base: isempty, start, next, done, length, getindex, minimum, maximum, search, show

export Treap, TreapNode

type TreapNode{K}
	priority::Float64
	size::Int
	key::K
	left::TreapNode{K}
	right::TreapNode{K}

	TreapNode(key::K, priority::Float64, left::TreapNode{K}, right::TreapNode{K}) =
		new(priority, left.size + right.size + 1, key, left, right)

	TreapNode(key::K, priority::Float64) =
		new(priority, 1, key, TreapNode{K}(), TreapNode{K}())

	TreapNode() = new(Inf, 0)
end

isempty(t::TreapNode) = t.size == 0
show(io::IO, t::TreapNode) = show(io, "key:$(t.key) size:$(t.size) priority:$(t.priority)")
start(t::TreapNode) = 1
next(t::TreapNode, state) = (t[state], state + 1)
done(t::TreapNode, state) = state > length(t)
length(t::TreapNode) = t.size
key(t::TreapNode) = t.key
left(t::TreapNode) = t.left
right(t::TreapNode) = t.right

function getindex{K}(t::TreapNode{K}, index::Int)
	1 <= index <= t.size || throw(KeyError(index))
	while t.left.size != index - 1
		if index <= t.left.size
			t = t.left
		else
			index = index - t.left.size - 1
			t = t.right
		end
	end
	t.key
end

function minimum{K}(t::TreapNode{K})
	isempty(t) && error("An empty treap has no minimum.")
	while !isempty(t.left) t = t.left end
	t.key
end

function maximum{K}(t::TreapNode{K})
	isempty(t) && error("An empty treap has no maximum.")
	while !isempty(t.right) t = t.right end
	t.key
end

function add!{K}(t::TreapNode{K}, key::K)
	isempty(t) && return TreapNode{K}(key, rand())
	t.size += 1
	if key < t.key
		t.left = add!(t.left, key)
		t.left.priority < t.priority ? rotate_right!(t) : t
	else
		@assert t.key < key "A treap may not contain duplicate keys: $key, $(t.key)"
		t.right = add!(t.right, key)
		t.right.priority < t.priority ? rotate_left!(t) : t
	end
end

function merge!{K}(left::TreapNode{K}, right::TreapNode{K})
	isempty(left) && return right
	isempty(right) && return left

	if left.priority < right.priority
		result = left
		result.size += right.size
		result.right = merge!(left.right, right)
	else
		result = right
		result.size += left.size
		result.left = merge!(left, result.left)
	end
	result
end

function remove!{K}(t::TreapNode{K}, key::K)
	isempty(t) && throw(KeyError(key))

	t.size -= 1
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

function rotate_right!{K}(root::TreapNode{K})
	@assert !isempty(root)
	newroot = root.left
	
	# Rotate
	root.left = newroot.right
	newroot.right = root

	# Update sizes
	root.size -= newroot.left.size + 1
	newroot.size += root.right.size + 1
	newroot
end

function rotate_left!{K}(root::TreapNode{K})
	@assert !isempty(root)
	newroot = root.right

	# Rotate
	root.right = newroot.left
	newroot.left = root

	# Update sizes
	root.size -= newroot.right.size + 1
	newroot.size += root.left.size + 1
	newroot
end

type Treap{K}
	root::TreapNode{K}
	Treap() = new(TreapNode{K}())
end
add!{K}(t::Treap{K}, key::K) = t.root = add!(t.root, key)
remove!{K}(t::Treap{K}, key::K) = t.root = remove!(t.root, key)
length(t::Treap) = length(t.root)
getindex(t::Treap, n::Int) = getindex(t.root, n)
start(t::Treap) = start(t.root)
next(t::Treap, state) = next(t.root, state)
done(t::Treap, state) = done(t.root, state)
minimum(t::Treap) = minimum(t.root)
maximum(t::Treap) = maximum(t.root)
key(t::Treap) = key(t.root)
left(t::Treap) = left(t.root)
right(t::Treap) = right(t.root)
root(t::Treap) = t.root

function test_treap()
	n = 10000
	a = shuffle([i for i in 1:n])
	t = Treap{Int}()

	for i in 1:n
		add!(t, a[i])
	end
	sort!(a)

	@assert !isempty(t)
	@assert length(t) == length(a) "$(length(t)) != $(length(a))"
	@assert maximum(t) == maximum(a)
	@assert minimum(t) == minimum(a)

	# Check that all elements have been added to
	# the treap and are in sorted order.
	for (i, v) in enumerate(a)
		@assert t[i] == v
	end

	for v in a
		remove!(t, v)
	end

	@assert length(t) == 0
	@assert isempty(t)

	println("Treap: Test succeeded.")

end

function benchmark_treap(n)
	gc_disable()

	t = Treap{Int}()
	a = shuffle([i for i in 1:n])

	println("Timing $n insert operations.")
	@time for i in 1:n
		t = add!(t, a[i])
	end

	@assert length(t) == n

	println("Timing $n random access operations.")
	@time for i in 1:n
		t[rand(1:n)]
	end
	
	println("Timing $n remove operations.")
	@time for i in 1:n
		remove!(t, a[i])
	end

	@assert isempty(t)

	gc_enable()
end

# test_treap()
# benchmark_treap(100000)

