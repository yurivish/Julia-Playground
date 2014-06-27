# A minimalist's implementation of the ideas described in
# A Minimalist's Implementation of an Approximate Nearest Neighbor Algorithm in Fixed Dimensions.
# Paper: https://cs.uwaterloo.ca/~tmchan/sss.ps
# Additional references:
#  - http://en.wikipedia.org/wiki/Z-order_curve#Efficiently_building_quadtrees

lessmsb(x, y) = x < y && x < (x $ y)
function shuffdim(p, q)
	# Return the dimension with the largest most significant bit, which
	# decides which of p and q comes first in shuffle order.
	# Break ties in favor of the lower-index dimension (x, then y, then z)
	# since that's the order in which the bits are conceptually interleaved.
	k = 1
	kxor = p[k] $ q[k]
	for i in 2:min(size(p, 1), size(q, 1)) # Workaround for wonky bbox point stuff.
		ixor = p[i] $ q[i]
		if lessmsb(kxor, ixor)
			k, kxor = i, ixor
		end
	end
	k
end
shuffless(p, q) = (k = shuffdim(p, q); p[k] < q[k])
shuffmore(p, q) = (k = shuffdim(p, q); p[k] > q[k])
  shuffeq(p, q) = (k = shuffdim(p, q); p[k] == q[k])

sq(v) = v * v

function dist_sq_to_box(q, min, max)
	# Return the distance from q to the power-of-two-sized quadtree box containing min and max.
	k = shuffdim(min, max)

	# Handle the case when the bounding box is a single point separately.
	# Failing to do so will trigger a DomainError when calculating
	# i below, since the xor of two equal elements is zero.
	min[k] == max[k] && return dist_sq(q, min)::Uint

	# i is the 1-based index of the maximum differing bit
	# across min and max. It is also to the power of 2 of the
	# size of the quadtree box containing both min and max.
	i = 1 + exponent(float(min[k] $ max[k]))

	# We can compute the squared distance from q to the bounding box
	# by accumulating separately in each dimension
	d_sq::Uint = 0
	for j in 1:size(min, 1)
		# The left and right coordinates of the bounding box in this dimension
		lo = (min[j] >> i) << i # equivalent to floor(min[j] / 2^i) * 2^i
		hi = lo + (1 << i)      # equivalent to lo + 2^i

		# If q is outside the bounds, add to d_sq the amount by which it is so.
		if q[j] < lo
			d_sq += sq(q[j] - lo)
		elseif q[j] > hi
			d_sq += sq(q[j] - hi)
		end
	end
	d_sq
end

# Note: These can't stay Uint8s forever.
immutable BBoxPoint # {4}
	x::Uint8
	y::Uint8
	z::Uint8
	w::Uint8
end
Base.getindex(p::BBoxPoint, n::Int) = n == 1 ? p.x : n == 2 ? p.y : n == 3 ? p.z : n == 4 ? p.w : throw("BBoxPoint indexing error.")
Base.size(p::BBoxPoint) = (4,)
Base.size(p::BBoxPoint, n) = n == 1 ? 4 : throw("Invalid dimension.")

# Note: Due to the PointN types, this now assumes all coordinates are of the same type.
clampadd3{Q}(p::Q, r::Int) = BBoxPoint(min(p[1] + r, typemax(p[1])), min(p[2] + r, typemax(p[2])), min(p[3] + r, typemax(p[3])), 0)
clampsub3{Q}(p::Q, r::Int) = BBoxPoint(max(p[1] - r, typemin(p[1])), max(p[2] - r, typemin(p[2])), max(p[3] - r, typemin(p[3])), 0)
clampadd4{Q}(p::Q, r::Int) = BBoxPoint(min(p[1] + r, typemax(p[1])), min(p[2] + r, typemax(p[2])), min(p[3] + r, typemax(p[3])), min(p[4] + r, typemax(p[4])))
clampsub4{Q}(p::Q, r::Int) = BBoxPoint(max(p[1] - r, typemin(p[1])), max(p[2] - r, typemin(p[2])), max(p[3] - r, typemin(p[3])), max(p[4] - r, typemin(p[4])))

representative(p) = p

preprocess!(P) = sort!(P, lt=shuffless)

immutable Result{P, Q}
	r_sq::Uint
	point::P
	bbox_min::BBoxPoint # The bounding box enclosing the hypersphere with radius r
	bbox_max::BBoxPoint # centered on the query point (with side length 2r).
	function Result(r_sq::Uint, point::P, q::Q)
		r = iceil(sqrt(r_sq))
		new(r_sq, point, clampsub3(q, r), clampadd3(q, r))
	end
end

# P = point; Q = query
function nearest{P, Q}(t::TreapNode{P}, q::Q, R::Result{P, Q}, ε=0.0)
	isempty(t) && return R
	point = representative(key(t))
	r_sq = dist_sq(point, q)
	r_sq < R.r_sq && (R = Result{P, Q}(r_sq, key(t), q))

	if length(t) == 1 || dist_sq_to_box(q, representative(minimum(t)), representative(maximum(t))) * sq(1 + ε) > R.r_sq
		return R
	end

	if shuffless(q, point)
		R = nearest(left(t), q, R, ε)
		shuffmore(R.bbox_max, point) && (R = nearest(right(t), q, R, ε))
	else
		R = nearest(right(t), q, R, ε)
		shuffless(R.bbox_min, point) && (R = nearest(left(t), q, R, ε))
	end

	R
end

function nearest{P, Q}(t::Treap{P}, q::Q, ε=0.0)
	R = nearest(root(t), q, Result{P, Q}(uint(9999999), key(t), q), ε)
	@assert R.r_sq < uint(9999999)
	R.point
end

# BUG: This assumes you've already imported rgb.jl for no good reason.
# Define less-than and distances for pixels for testing purposes.
<(p::Pixel, q::Pixel) = shuffless(p, q)
dist_sq(p::Pixel, q::Pixel) = sq(p.r - q.r) + sq(p.g - q.g) + sq(p.b - q.b)

function test_sss(n=1000, ε=0.0)

	function linear_nearest(P, q)
		best = q
		best_dist::Float64 = Inf
		for p in P
			d = dist_sq(p, q)
			if d < best_dist
				best = p
				best_dist = d
			end
		end
		best
	end

	P = Treap{Pixel}()
	pixels = unique([Pixel(rand(Uint8), rand(Uint8), rand(Uint8)) for i in 1:1500])
	for p in pixels
		add!(P, p)
	end

	qs = [Pixel(rand(Uint8), rand(Uint8), rand(Uint8)) for i in 1:n]
	lps = [linear_nearest(P, q) for q in qs]
	min_distances = [sqrt(dist_sq(qs[i], lps[i])) for i in 1:n]

	num_matches = 0
	@time for i in 1:n
		q = qs[i]
		tp = nearest(P, q, ε)
		tree_distance = sqrt(dist_sq(q, tp))
		min_distance = min_distances[i]
		if min_distance != tree_distance
			lp = lps[i]
			println("Mismatch for $q: $tp, $lp. ($(int(min_distance)) vs. $(int(tree_distance))); $(int(100 * min_distance / tree_distance))%")
		else
			num_matches += 1
		end
	end
	println("SSS: $num_matches / $n matches.")
end

# test_sss()
