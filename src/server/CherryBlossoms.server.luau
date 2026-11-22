-- Cherry blossom decorations: a few cherry blossom trees, pink blossom bushes and fallen petals
-- in the lobby, and inside the Troll Tower a tree on the ground floor, blossom garlands along the
-- walls every 50 studs and blossom vines up the corners. (The petals falling from the sky are
-- made on each player's screen by FallingPetals.client.luau.)
--
-- Everything is built when the game starts, into a folder called "CherryBlossoms" in Workspace.
-- To move or add things, change the lists below. Spots without a floor under them are skipped.
local TREES = { -- { x, z, size }
	{ -130, 120, 1.0 }, -- left of the spawn, by the keyboard room
	{ -130, 157, 1.15 }, -- by the tower entrance, left
	{ -104, 126, 0.9 }, -- middle of the lobby
	{ -73, 162, 0.85 }, -- behind the item givers, by the tower entrance
}

local BUSHES = { -- { x, z }
	{ -140.5, 130 },
	{ -140.5, 140 },
	{ -140.5, 150 },
	{ -140.5, 165 },
	{ -118, 115 },
	{ -96, 115 },
	{ -86, 115 },
	{ -117.5, 146 }, -- next to the donation stand
	{ -68.5, 133 },
	{ -68.5, 154 },
}

local FALLEN_PETAL_PATCHES = 60 -- little pink patches scattered over the lobby floor
local LOBBY = { minX = -141, maxX = -69, minZ = 115, maxZ = 168 }
local KEEP_CLEAR = { -- { minX, maxX, minZ, maxZ }: no petal patches on the spawn, givers or stand
	{ -82, -66, 112, 128 },
	{ -98, -66, 139, 151 },
	{ -115, -101, 141, 151 },
}

local BLOSSOM_COLORS = {
	Color3.fromRGB(255, 183, 213),
	Color3.fromRGB(255, 160, 200),
	Color3.fromRGB(255, 205, 226),
	Color3.fromRGB(250, 140, 190),
}
local FLOWER_COLORS = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 236, 244) }
local BARK = Color3.fromRGB(115, 72, 60)
local PETAL_GROUND = Color3.fromRGB(255, 190, 215)

local rng = Random.new(2026) -- same seed every time, so the trees look the same in every server

local folder = Instance.new("Folder")
folder.Name = "CherryBlossoms"

-- Helpers ----------------------------------------------------------------------

local function newPart(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

-- A round wooden piece from a to b (trunk or branch)
local function wood(parent: Instance, a: Vector3, b: Vector3, thickness: number, solid: boolean)
	local direction = (b - a).Unit
	local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local side = (up - direction * up:Dot(direction)).Unit
	newPart(parent, {
		Name = if solid then "Trunk" else "Branch",
		Shape = Enum.PartType.Cylinder, -- a cylinder's length runs along its X axis
		Size = Vector3.new((b - a).Magnitude + thickness * 0.5, thickness, thickness),
		CFrame = CFrame.fromMatrix((a + b) / 2, direction, side),
		Color = BARK,
		Material = Enum.Material.Wood,
		CanCollide = solid,
		CanQuery = solid,
	})
end

local function ball(parent: Instance, center: Vector3, size: number, color: Color3, name: string)
	newPart(parent, {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(center),
		Color = color,
	})
end

-- A thin round pink patch lying on the floor
local function petalPatch(parent: Instance, floor: Vector3, size: number, transparency: number)
	newPart(parent, {
		Name = "FallenPetals",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, size, size),
		-- turn the cylinder so it lies flat; tiny height differences stop patches flickering into each other
		CFrame = CFrame.new(floor + Vector3.new(0, 0.03 + rng:NextNumber(0, 0.02), 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = PETAL_GROUND,
		Transparency = transparency,
		CastShadow = false,
	})
end

-- Find the floor at (x, z). Returns nil if there's no floor there (or something tall is in the way).
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude
floorParams.FilterDescendantsInstances = { folder }
floorParams.RespectCanCollide = true

local function floorAt(x: number, z: number): Vector3?
	local result = workspace:Raycast(Vector3.new(x, 30, z), Vector3.new(0, -60, 0), floorParams)
	if result and result.Position.Y > -3 and result.Position.Y < 1 then
		return result.Position
	end
	return nil
end

-- A cluster of blossom balls with little white flowers dotted on it
local function blossomClump(parent: Instance, center: Vector3, size: number)
	ball(parent, center, size, pick(BLOSSOM_COLORS), "Blossom")
	for _ = 1, 2 do
		local offset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 0.6), rng:NextNumber(-1, 1)) * size * 0.4
		ball(parent, center + offset, size * rng:NextNumber(0.6, 0.8), pick(BLOSSOM_COLORS), "Blossom")
	end
	for _ = 1, 3 do
		local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1), rng:NextNumber(-1, 1)).Unit
		ball(parent, center + direction * size * 0.48, size * 0.12, pick(FLOWER_COLORS), "Flower")
	end
end

-- The decorations ---------------------------------------------------------------

local function tree(x: number, z: number, s: number, parent: Instance)
	local floor = floorAt(x, z)
	if not floor then
		warn(`[CherryBlossoms] No floor for the tree at {x}, {z}: skipped`)
		return
	end

	local model = Instance.new("Model")
	model.Name = "CherryBlossomTree"

	-- trunk in two bends, so it isn't perfectly straight
	local bend = floor + Vector3.new(0.5, 4, 0.2) * s
	local top = floor + Vector3.new(-0.3, 8, 0.4) * s
	wood(model, floor - Vector3.new(0, 0.5, 0), bend, 1.8 * s, true)
	wood(model, bend, top, 1.5 * s, true)

	-- branches spreading out, each ending in a clump of blossoms
	local turn = rng:NextNumber(0, math.pi * 2)
	for k = 1, 4 do
		local angle = turn + k * math.pi / 2 + rng:NextNumber(-0.35, 0.35)
		local reach, rise = rng:NextNumber(4, 5.5) * s, rng:NextNumber(2.5, 4) * s
		local tip = top + Vector3.new(math.cos(angle) * reach, rise, math.sin(angle) * reach)
		wood(model, top, tip, 0.8 * s, false)
		blossomClump(model, tip + Vector3.new(0, 1 * s, 0), rng:NextNumber(6, 7) * s)
	end
	wood(model, top, top + Vector3.new(0, 5, 0) * s, 0.9 * s, false)
	blossomClump(model, top + Vector3.new(0, 6.5, 0) * s, 7.5 * s)

	-- a carpet of fallen petals under it
	petalPatch(model, floor, 16 * s, 0.25)

	model.PrimaryPart = model:FindFirstChild("Trunk") :: BasePart
	model.Parent = parent
end

local function bush(x: number, z: number, parent: Instance)
	local floor = floorAt(x, z)
	if not floor then
		return
	end
	local model = Instance.new("Model")
	model.Name = "BlossomBush"
	blossomClump(model, floor + Vector3.new(0, 1.3, 0), rng:NextNumber(2.8, 3.6))
	petalPatch(model, floor, 5, 0.3)
	model.Parent = parent
end

for _, spot in TREES do
	tree(spot[1], spot[2], spot[3], folder)
end
for _, spot in BUSHES do
	bush(spot[1], spot[2], folder)
end

-- Scatter fallen petal patches over an area of floor
local function scatterPetals(parent: Instance, area, count: number, keepClear: { { number } }): number
	local placed, tries = 0, 0
	while placed < count and tries < count * 10 do
		tries += 1
		local x, z = rng:NextNumber(area.minX, area.maxX), rng:NextNumber(area.minZ, area.maxZ)
		local blocked = false
		for _, box in keepClear do
			if x >= box[1] and x <= box[2] and z >= box[3] and z <= box[4] then
				blocked = true
			end
		end
		local floor = if blocked then nil else floorAt(x, z)
		if floor then
			petalPatch(parent, floor, rng:NextNumber(1.5, 4.5), rng:NextNumber(0.15, 0.4))
			placed += 1
		end
	end
	return placed
end

local patches = Instance.new("Folder")
patches.Name = "FallenPetals"
patches.Parent = folder
local placed = scatterPetals(patches, LOBBY, FALLEN_PETAL_PATCHES, KEEP_CLEAR)

folder.Parent = workspace

local trees, bushes = 0, 0
for _, child in folder:GetChildren() do
	if child.Name == "CherryBlossomTree" then
		trees += 1
	elseif child.Name == "BlossomBush" then
		bushes += 1
	end
end
print(`[CherryBlossoms] Made {trees} cherry blossom trees, {bushes} bushes and {placed} fallen petal patches`)

-- Inside the Troll Tower -------------------------------------------------------------

local TOWER_NAME = "💥 Troll Tower Obby Parkour Fun Hard Easy"
local INNER = { west = -139.45, east = -71.45, south = 170.26, north = 238.26 } -- inside faces of its walls
local SEAMS = { 49, 99, 149, 199, 249, 299, 349, 397 } -- garland heights: where the wall colour changes, and the top
local GARLAND_SPACING = 3 -- studs between blossoms in a garland
local VINE_SPACING = 4.5 -- studs between blossoms going up a corner
local TOWER_TREE = { -108, 200, 1.25 } -- middle of the ground floor
local TOWER_BUSHES = { { -134, 222 }, { -90, 223 }, { -134, 190 }, { -90, 188 } }
local TOWER_PETAL_PATCHES = 24
local TOWER_FLOOR = { minX = -135, maxX = -85, minZ = 174, maxZ = 225 }

local tower = workspace:WaitForChild(TOWER_NAME, 30)
if not tower then
	warn("[CherryBlossoms] Couldn't find the Troll Tower, so no blossoms inside it")
	return
end

local inside = Instance.new("Folder")
inside.Name = "Tower"

local probe = RaycastParams.new()
probe.FilterType = Enum.RaycastFilterType.Exclude
probe.FilterDescendantsInstances = { folder }

local nearby = OverlapParams.new()
nearby.FilterType = Enum.RaycastFilterType.Exclude
nearby.FilterDescendantsInstances = { folder }

-- How far a part reaches from its centre in a direction
local function reach(part: BasePart, axis: Vector3): number
	local cf, size = part.CFrame, part.Size
	return 0.5
		* (
			math.abs(cf.RightVector:Dot(axis)) * size.X
			+ math.abs(cf.UpVector:Dot(axis)) * size.Y
			+ math.abs(cf.LookVector:Dot(axis)) * size.Z
		)
end

-- The wall surface behind a spot on the wall line, or nil if there's no wall there (a doorway)
-- or something is in front of the wall
local function wallBehind(onWall: Vector3, normal: Vector3): RaycastResult?
	local result = workspace:Raycast(onWall + normal * 3, -normal * 4, probe)
	if result and result.Distance >= 2.5 then
		return result
	end
	return nil
end

type Plane = { normal: Vector3, at: number }

-- True if there's nothing but wall within `radius` of the spot, so a blossom there won't get in
-- the way of the obby or hide a trap
local function isClear(position: Vector3, radius: number, walls: { Plane }): boolean
	for _, part in workspace:GetPartBoundsInRadius(position, radius, nearby) do
		local isWall = false
		for _, wall in walls do
			if part.Position:Dot(wall.normal) + reach(part, wall.normal) <= wall.at + 0.3 then
				isWall = true -- it doesn't stick out of this wall into the tower
				break
			end
		end
		if not isWall then
			return false
		end
	end
	return true
end

-- A garland of blossoms along one wall at height y
local garlandBlossoms = 0
local function garland(y: number, from: Vector3, to: Vector3, normal: Vector3)
	local along, length = (to - from).Unit, (to - from).Magnitude
	local i = 0
	for t = 2, length - 2, GARLAND_SPACING do
		local wall = wallBehind(from + along * t + Vector3.new(0, y, 0), normal)
		if wall then
			local center = wall.Position + normal * 0.6 + Vector3.new(0, rng:NextNumber(-0.3, 0.3), 0)
			if isClear(center + normal * 0.4, 2, { { normal = normal, at = wall.Position:Dot(normal) } }) then
				i += 1
				garlandBlossoms += 1
				ball(inside, center, if i % 2 == 0 then 2.2 else 1.6, pick(BLOSSOM_COLORS), "Blossom")
				if i % 3 == 0 then
					ball(inside, center + normal * 0.9 + Vector3.new(0, 0.35, 0), 0.55, pick(FLOWER_COLORS), "Flower")
				end
				if i % 4 == 0 then -- a little bunch hanging down
					ball(inside, center + normal * 0.2 + Vector3.new(0, -1.4, 0), 1.1, pick(BLOSSOM_COLORS), "Blossom")
				end
			end
		end
	end
end

local walls = {
	{ from = Vector3.new(INNER.west, 0, INNER.south), to = Vector3.new(INNER.west, 0, INNER.north), normal = Vector3.xAxis },
	{ from = Vector3.new(INNER.east, 0, INNER.south), to = Vector3.new(INNER.east, 0, INNER.north), normal = -Vector3.xAxis },
	{ from = Vector3.new(INNER.west, 0, INNER.south), to = Vector3.new(INNER.east, 0, INNER.south), normal = Vector3.zAxis },
	{ from = Vector3.new(INNER.west, 0, INNER.north), to = Vector3.new(INNER.east, 0, INNER.north), normal = -Vector3.zAxis },
}
for _, y in SEAMS do
	for _, wall in walls do
		garland(y, wall.from, wall.to, wall.normal)
	end
end

-- Blossom vines climbing the four inside corners
local vineBlossoms = 0
local corners = {
	{ x = INNER.west, z = INNER.south, nx = Vector3.xAxis, nz = Vector3.zAxis },
	{ x = INNER.east, z = INNER.south, nx = -Vector3.xAxis, nz = Vector3.zAxis },
	{ x = INNER.west, z = INNER.north, nx = Vector3.xAxis, nz = -Vector3.zAxis },
	{ x = INNER.east, z = INNER.north, nx = -Vector3.xAxis, nz = -Vector3.zAxis },
}
for _, corner in corners do
	local out = corner.nx + corner.nz -- diagonally into the tower
	local i = 0
	for y = 3, 395, VINE_SPACING do
		local spot = Vector3.new(corner.x, y, corner.z) + out * 1.1
		-- both walls have to be there (not a doorway)
		local wallX = wallBehind(Vector3.new(corner.x, y, spot.Z), corner.nx)
		local wallZ = wallBehind(Vector3.new(spot.X, y, corner.z), corner.nz)
		if wallX and wallZ then
			local planes = {
				{ normal = corner.nx, at = wallX.Position:Dot(corner.nx) },
				{ normal = corner.nz, at = wallZ.Position:Dot(corner.nz) },
			}
			if isClear(spot, 1.8, planes) then
				i += 1
				vineBlossoms += 1
				ball(inside, spot + Vector3.new(0, rng:NextNumber(-0.4, 0.4), 0), if i % 2 == 0 then 1.9 else 1.4, pick(BLOSSOM_COLORS), "Blossom")
				if i % 2 == 1 then
					ball(inside, spot + out * 0.7 + Vector3.new(0, 0.5, 0), 0.5, pick(FLOWER_COLORS), "Flower")
				end
			end
		end
	end
end

-- A cherry tree, bushes and fallen petals on the ground floor
tree(TOWER_TREE[1], TOWER_TREE[2], TOWER_TREE[3], inside)
for _, spot in TOWER_BUSHES do
	bush(spot[1], spot[2], inside)
end
local towerPatches = scatterPetals(inside, TOWER_FLOOR, TOWER_PETAL_PATCHES, {})

inside.Parent = folder
print(
	`[CherryBlossoms] Inside the tower: {garlandBlossoms} garland blossoms, {vineBlossoms} vine blossoms, `
		.. `a tree, bushes and {towerPatches} fallen petal patches`
)
