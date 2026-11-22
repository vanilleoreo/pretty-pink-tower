-- Cherry blossom decorations around the lobby: a few cherry blossom trees, pink blossom bushes
-- along the edges, and fallen petals on the floor. (The petals falling from the sky are made on
-- each player's screen by FallingPetals.client.luau.)
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

local FALLEN_PETAL_PATCHES = 34 -- little pink patches scattered over the lobby floor
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

local function tree(x: number, z: number, s: number)
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
	model.Parent = folder
end

local function bush(x: number, z: number)
	local floor = floorAt(x, z)
	if not floor then
		return
	end
	local model = Instance.new("Model")
	model.Name = "BlossomBush"
	blossomClump(model, floor + Vector3.new(0, 1.3, 0), rng:NextNumber(2.8, 3.6))
	petalPatch(model, floor, 5, 0.3)
	model.Parent = folder
end

local function inKeepClear(x: number, z: number): boolean
	for _, box in KEEP_CLEAR do
		if x >= box[1] and x <= box[2] and z >= box[3] and z <= box[4] then
			return true
		end
	end
	return false
end

for _, spot in TREES do
	tree(spot[1], spot[2], spot[3])
end
for _, spot in BUSHES do
	bush(spot[1], spot[2])
end

local patches = Instance.new("Folder")
patches.Name = "FallenPetals"
patches.Parent = folder
local placed, tries = 0, 0
while placed < FALLEN_PETAL_PATCHES and tries < FALLEN_PETAL_PATCHES * 10 do
	tries += 1
	local x, z = rng:NextNumber(LOBBY.minX, LOBBY.maxX), rng:NextNumber(LOBBY.minZ, LOBBY.maxZ)
	local floor = if inKeepClear(x, z) then nil else floorAt(x, z)
	if floor then
		petalPatch(patches, floor, rng:NextNumber(1.5, 4.5), rng:NextNumber(0.15, 0.4))
		placed += 1
	end
end

folder.Parent = workspace
