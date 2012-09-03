-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local yield = coroutine.yield

-- Unique member keys --
local _array = {}
local _iter = {}
local _props = {}
local _thresholds = {}

-- Threshold options --
local Thresholds = table_ex.MakeSet{ "left", "right", "top", "bottom" }

-- Draw rectangle --
local X, Y, W, H

-- thresholds: Scale thresholds
-- total: Total size in coorindate
-- kb, ke: Begin, end lookup keys
-- Returns: Begin, middle, end size
local function GetSizes (thresholds, total, kb, ke)
	local bsize = thresholds[kb] or 0
	local esize = thresholds[ke] or 0
	local extra = total - (bsize + esize)
	local scale = 1

	if extra <= 0 then
		extra = 0
		scale = total / (bsize + esize)
	end

	return bsize * scale, extra, esize * scale
end

-- Iterator modes --
local Modes = {}

function Modes:grid (x1, y1, w, h)
	local thresholds = self[_thresholds]

	local lw, mw, rw = GetSizes(thresholds, w, "left", "right")
	local th, mh, bh = GetSizes(thresholds, h, "top", "bottom")

	local x2, y2 = x1 + lw, y1 + th
	local x3, y3 = x2 + mw, y2 + mh

	-- Supply the corners.
	yield(1, x1, y1, lw, th)
	yield(3, x3, y1, rw, th)
	yield(7, x1, y3, lw, bh)
	yield(9, x3, y3, rw, bh)

	-- Supply the top and bottom sides.
	if mw > 0 then
		yield(2, x2, y1, mw, th)
		yield(8, x2, y3, mw, bh)
	end

	-- Supply the left and right sides.
	if mh > 0 then
		yield(4, x1, y2, lw, mh)
		yield(6, x3, y2, rw, mh)
	end

	-- Supply the middle.
	if mw > 0 and mh > 0 then
		yield(5, x2, y2, mw, mh)
	end
end

function Modes:hline (x, y, w, h)
	local lw, mw, rw = GetSizes(self[_thresholds], w, "left", "right")

	-- Supply the sides.
	yield(1, x, y, lw, h)
	yield(3, x + lw + mw, y, rw, h)

	-- Supply the middle.
	if mw > 0 then
		yield(2, x + lw, y, mw, h)
	end
end

function Modes:vline (x, y, w, h)
	local th, mh, bh = GetSizes(self[_thresholds], h, "top", "bottom")

	-- Supply the sides.
	yield(1, x, y, w, th)
	yield(3, x, y + mh + th, w, bh)

	-- Supply the middle.
	if mh > 0 then
		yield(2, x, y + th, w, mh)
	end
end

-- Picture iterator --
local Iter = coroutine_ex.Create(function(P)
	P[_iter](P, X, Y, W, H)
end)

-- MultiPicture class definition --
class.Define("MultiPicture", function(MultiPicture)
	-- Draws the picture
	-- x, y: Draw coordinates
	-- w, h: Draw dimensions
	-- props: Optional property set
	--------------------------------
	function MultiPicture:Draw (x, y, w, h, props)
		props = props or self[_props]

		X, Y, W, H = x, y, w, h

		-- Draw each component picture.
		local array = self[_array]

		for i, px, py, pw, ph in Iter, self do
			if array[i] then
				array[i]:Draw(px, py, pw, ph, props)
			end
		end
	end

	-- name: Property to get
	-- Returns: Property value
	---------------------------
	function MultiPicture:GetProperty (name)
		assert(name ~= nil, "name == nil")

		return self[_props][name]
	end

	-- name: Threshold name
	-- Returns: Threshold value
	----------------------------
	function MultiPicture:GetThreshold (name)
		assert(Thresholds[name or 0], "Invalid threshold")

		return self[_thresholds][name] or 0
	end

	-- mode: Draw mode to assign
	-----------------------------
	function MultiPicture:SetMode (mode)
		self[_iter] = assert(Modes[mode or 0], "Invalid mode")
		self[_array] = {}
	end

	-- slot: Picture slot
	-- picture: Picture to assign
	---------------------------
	function MultiPicture:SetPicture (slot, picture)
		self[_array][slot] = picture
	end

	-- name: Property to assign
	-- value: Property value
	----------------------------
	function MultiPicture:SetProperty (name, value)
		assert(name ~= nil, "name == nil")

		self[_props][name] = value
	end

	-- name: Threshold name
	-- value: Threshold value to assign
	------------------------------------
	function MultiPicture:SetThreshold (name, value)
		assert(Thresholds[name or 0], "Invalid threshold")

		self[_thresholds][name] = value
	end
end,

-- Constructor
-- mode: Default mode
-- props: Optional external property set
-----------------------------------------
function(P, mode, props)
	P[_props] = props or {}
	P[_thresholds] = {}

	P:SetMode(mode or "grid")
end)