-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local max = math.max
local min = math.min

-- Cached routines --
local BoxesIntersect_
local SortPairs_
local SwapIf_

-- Export numericops namespace.
module "numericops"

--- Status.
-- @param x1 Box #1 x-coordinate.
-- @param y1 Box #1 y-coordinate.
-- @param w1 Box #1 width.
-- @param h1 Box #1 height.
-- @param x2 Box #2 x-coordinate.
-- @param y2 Box #2 y-coordinate.
-- @param w2 Box #2 width.
-- @param h2 Box #2 height.
-- @return If true, the boxes intersect.
function BoxesIntersect (x1, y1, w1, h1, x2, y2, w2, h2)
	return not (x1 > x2 + w2 or x2 > x1 + w1 or y1 > y2 + h2 or y2 > y1 + h1)
end

-- Status.
-- @param bx Contained box x-coordinate.
-- @param by Contained box y-coordinate.
-- @param bw Contained box width.
-- @param bh Contained box height.
-- @param x Containing box x-coordinate.
-- @param y Containing box y-coordinate.
-- @param w Containing box width.
-- @param h Containing box height.
-- @return If true, the first box is contained by the second.
function BoxInBox (bx, by, bw, bh, x, y, w, h)
	return not (bx < x or bx + bw > x + w or by < y or by + bh > y + h)
end

--- Variant of <b>BoxesIntersect</b> with intersection information.
-- @param x1 Box #1 x-coordinate.
-- @param y1 Box #1 y-coordinate.
-- @param w1 Box #1 width.
-- @param h1 Box #1 height.
-- @param x2 Box #2 x-coordinate.
-- @param y2 Box #2 y-coordinate.
-- @param w2 Box #2 width.
-- @param h2 Box #2 height.
-- @return If true, boxes intersect.
-- @return If the boxes intersect, the intersection x, y, w, h.
-- @see BoxesIntersect
function BoxIntersection (x1, y1, w1, h1, x2, y2, w2, h2)
	if not BoxesIntersect_(x1, y1, w1, h1, x2, y2, w2, h2) then
		return false
	end

	local sx, sy = max(x1, x2), max(y1, y2)

	return true, sx, sy, min(x1 + w1, x2 + w2) - sx, min(y1 + h1, y2 + h2) - sy
end

--- Clamps a number between two bounds.<br><br>
-- The bounds are swapped if out of order.
-- @param number Number to clamp.
-- @param minb Minimum bound.
-- @param maxb Maximum bound.
-- @return Clamped number.
function ClampIn (number, minb, maxb)
	minb, maxb = SwapIf_(minb > maxb, minb, maxb)

	return min(max(number, minb), maxb)
end

--- Status.
-- @param px Point x-coordinate.
-- @param py Point y-coordinate.
-- @param x Box x-coordinate.
-- @param y Box y-coordinate.
-- @param w Box width.
-- @param h Box height.
-- @return If true, the point is contained by the box.
function PointInBox (px, py, x, y, w, h)
	return px >= x and px < x + w and py >= y and py < y + h
end

-- start: Starting index of range
-- count: Count of items in range
-- size: Length of overlapping range
-- Returns: Overlap amount between [start, start + count) and [1, size]
------------------------------------------------------------------------
function RangeOverlap (start, count, size)
	if start > size then
		return 0
	elseif start + count <= size + 1 then
		return count
	end

	return size - start + 1
end

-- Converts coordinate pairs into a rectangle
-- x1, y1: First pair of coordinates
-- x2, y2: Second pair of coordinates
-- Returns: Rectangle coordinates and dimensions
-------------------------------------------------
function Rect (x1, y1, x2, y2)
	x1, y1, x2, y2 = SortPairs_(x1, y1, x2, y2)

	return x1, y1, x2 - x1, y2 - y1
end

-- index: Index to rotate
-- size: Array size
-- to_left: If true, rotate left
-- Returns: Rotated array index
--------------------------------
function RotateIndex (index, size, to_left)
	if to_left then
		return index > 1 and index - 1 or size
	else
		return index < size and index + 1 or 1
	end
end

-- x1, y1: First pair of coordinates
-- x2, y2: Second pair of coordinates
-- Returns: The sorted coordinate pairs 
----------------------------------------
function SortPairs (x1, y1, x2, y2)
	x1, x2 = SwapIf_(x1 > x2, x1, x2)
	y1, y2 = SwapIf_(y1 > y2, y1, y2)

	return x1, y1, x2, y2
end

-- swap: If true, do a swap
-- a, b: Values to swap
-- Returns: Ordered (possibly swapped) pair
--------------------------------------------
function SwapIf (swap, a, b)
	if swap then
		return b, a
	end

	return a, b
end

-- x: Distance along the trapezoid (aligned to the x-axis)
-- grow_until: Distance at which flat part begins
-- flat_until: Distance at which flat part ends
-- drop_until: Distance at which x-axis is met again
-- Returns: Height at x, in [0, 1], if within the range
-----------------------------------------------------------
function Trapezoid (x, grow_until, flat_until, drop_until)
	if x < 0 or x > drop_until then
		return
	elseif x <= grow_until then
		return x / grow_until
	elseif x <= flat_until then
		return 1
	else
		return 1 - (x - flat_until) / (drop_until - flat_until)
	end
end

--- Exclusive-ors two conditions
-- @param b1 Condition #1.
-- @param b2 Condition #2.
-- @return If true, one (and only one) of the conditions is true.
function XOR (b1, b2)
	return not not ((b1 or b2) and not (b1 and b2))
end

-- Cache some routines.
BoxesIntersect_ = BoxesIntersect
SortPairs_ = SortPairs
SwapIf_ = SwapIf