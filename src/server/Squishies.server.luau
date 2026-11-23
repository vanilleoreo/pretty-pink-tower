-- Squishy jumps in the tower: on every level, some jumps are big soft squishies instead of plain
-- platforms: cats, bunnies, bears, strawberries, cupcakes and Needohs (the blob from the ASMR
-- area), each with a cute face. When anyone lands on one, it squashes down, bulges out and
-- wobbles back with a squish sound and a little puff. (Squishies.client.luau does the squish on
-- everyone's screen, so it looks smooth.)
--
-- The real platform stays exactly where it was, just invisible, so every jump is exactly as long
-- and as high as before. The squishy sitting on it is only for looks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TOWER_NAME = "💥 Troll Tower Obby Parkour Fun Hard Easy"

-- at = the top middle of the platform that becomes a squishy; kind = what it looks like;
-- height = how tall it is where there isn't much room under the platform (otherwise it's about
-- half as tall as it's wide). Needohs are used for the flattest spots.
local SQUISHIES = {
	{ at = Vector3.new(-122.45, 29.34, 233.26), kind = "Cat", color = Color3.fromRGB(255, 170, 205) }, -- 1
	{ at = Vector3.new(-100.45, 59.34, 175.26), kind = "Bunny", color = Color3.fromRGB(200, 170, 255) }, -- 2
	{ at = Vector3.new(-76.45, 51.34, 231.26), kind = "Needoh", color = Color3.fromRGB(215, 190, 255), height = 2.2 },
	{ at = Vector3.new(-76.45, 53.34, 175.26), kind = "Strawberry", height = 4.2 },
	{ at = Vector3.new(-107.45, 115.34, 185.26), kind = "Bear", color = Color3.fromRGB(165, 235, 200) }, -- 3
	{ at = Vector3.new(-77.45, 102.34, 225.26), kind = "Needoh", color = Color3.fromRGB(150, 220, 255), height = 3.2 },
	{ at = Vector3.new(-127.45, 115.34, 185.26), kind = "Cupcake", color = Color3.fromRGB(255, 185, 140), height = 4.4 },
	{ at = Vector3.new(-128.45, 159.5, 175.26), kind = "Bunny", color = Color3.fromRGB(255, 200, 160) }, -- 4
	{ at = Vector3.new(-76.45, 159.5, 175.95), kind = "Cat", color = Color3.fromRGB(150, 240, 220), height = 5.5 },
	{ at = Vector3.new(-128.45, 175.5, 232.26), kind = "Strawberry", height = 5.5 },
	{ at = Vector3.new(-133.45, 230.34, 190.26), kind = "Cupcake", color = Color3.fromRGB(165, 210, 255) }, -- 5
	{ at = Vector3.new(-76.45, 199.34, 233.26), kind = "Bear", color = Color3.fromRGB(180, 180, 255), height = 5.5 },
	{ at = Vector3.new(-131.45, 202.34, 175.26), kind = "Needoh", color = Color3.fromRGB(255, 245, 200), height = 3.2 },
	{ at = Vector3.new(-98.95, 264.34, 199.76), kind = "Cat", color = Color3.fromRGB(255, 236, 150) }, -- 6
	{ at = Vector3.new(-124.45, 286.34, 230.26), kind = "Strawberry", height = 5.5 },
	{ at = Vector3.new(-133.95, 343.29, 175.76), kind = "Bunny", color = Color3.fromRGB(255, 140, 170) }, -- 7
	{ at = Vector3.new(-101.95, 375.34, 234.26), kind = "Bear", color = Color3.fromRGB(230, 150, 255) }, -- 8
	{ at = Vector3.new(-133.95, 353.29, 191.26), kind = "Cupcake", color = Color3.fromRGB(200, 150, 255), height = 4.2 },
	{ at = Vector3.new(-133.95, 355.29, 206.26), kind = "Cat", color = Color3.fromRGB(190, 255, 170), height = 5.5 },
}

local SQUISH_SOUND = "rbxassetid://119626733196698" -- the same squish sound as the Needohs
local SINK = 0.35 -- how far your feet sink into the top of a squishy
local SQUISH_COOLDOWN = 0.35 -- seconds before the same squishy can squish again
local FACE_TOWARDS = Vector3.new(-105.45, 0, 204.26) -- faces look towards the middle of the tower

local COLORS = {
	eye = Color3.fromRGB(60, 30, 50),
	blush = Color3.fromRGB(255, 130, 170),
	mouth = Color3.fromRGB(120, 50, 70),
	innerEar = Color3.fromRGB(255, 175, 200),
	muzzle = Color3.fromRGB(255, 242, 232),
	nose = Color3.fromRGB(90, 40, 55),
	tail = Color3.fromRGB(255, 255, 255),
	strawberry = Color3.fromRGB(255, 100, 130),
	seed = Color3.fromRGB(255, 240, 175),
	leaf = Color3.fromRGB(110, 205, 120),
	frosting = Color3.fromRGB(255, 242, 248),
	cherry = Color3.fromRGB(235, 45, 85),
	sprinkles = {
		Color3.fromRGB(255, 105, 180),
		Color3.fromRGB(120, 200, 255),
		Color3.fromRGB(255, 220, 90),
		Color3.fromRGB(140, 230, 150),
		Color3.fromRGB(200, 150, 255),
	},
}

local tower = workspace:WaitForChild(TOWER_NAME, 30)
if not tower then
	return
end

local squishEvent = Instance.new("RemoteEvent") -- (the squishy) to everyone: "this one got squished"
squishEvent.Name = "Squish"
squishEvent.Parent = ReplicatedStorage

local function finish()
	tower:SetAttribute("SquishiesReady", true) -- the tower keyboards wait for this, so they skip squishies
end

local needoh = workspace:FindFirstChild("Needoh")
local rng = Random.new(5) -- the same seeds and sprinkles in every server

-- Shapes ---------------------------------------------------------------------------

local function setUp(part: BasePart, name: string, color: Color3, parent: Instance)
	part.Name = name
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false -- you stand on the invisible platform underneath
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

-- A rounded blob (an egg shape that can be stretched any way)
local function blob(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	setUp(part, name, color, parent)
	return part
end

-- The point on the outside of a blob (centre, half its size) in some direction from its middle,
-- and which way the surface faces there
local function onSurface(center: Vector3, half: Vector3, direction: Vector3): (Vector3, Vector3)
	local d = direction.Unit
	local t = 1 / math.sqrt((d.X / half.X) ^ 2 + (d.Y / half.Y) ^ 2 + (d.Z / half.Z) ^ 2)
	local point = center + d * t
	local outward = Vector3.new(
		(point.X - center.X) / half.X ^ 2,
		(point.Y - center.Y) / half.Y ^ 2,
		(point.Z - center.Z) / half.Z ^ 2
	).Unit
	return point, outward
end

type Surface = (direction: Vector3) -> (Vector3, Vector3)

-- Something small stuck on the surface, facing outwards
local function onBody(parent: Instance, surface: Surface, direction: Vector3, name: string, size: Vector3, color: Color3): Part
	local point, outward = surface(direction)
	return blob(parent, name, size, CFrame.lookAt(point, point + outward), color)
end

-- Eyes, blush and (unless it has a muzzle) a little mouth
local function face(parent: Instance, surface: Surface, front: Vector3, side: Vector3, s: number, withMouth: boolean)
	local up = Vector3.yAxis
	for _, k in { -1, 1 } do
		onBody(parent, surface, front + side * (0.3 * k) + up * 0.18, "Eye", Vector3.new(0.5, 0.7, 0.3) * s, COLORS.eye)
		local blush =
			onBody(parent, surface, front + side * (0.55 * k) - up * 0.05, "Blush", Vector3.new(0.8, 0.45, 0.15) * s, COLORS.blush)
		blush.Transparency = 0.25
	end
	if withMouth then
		onBody(parent, surface, front + up * 0.02, "Mouth", Vector3.new(0.35, 0.2, 0.12) * s, COLORS.mouth)
	end
end

-- A pointy cat ear: two wedges back to back, standing on `base`
local function pointyEar(parent: Instance, base: Vector3, front: Vector3, s: number, color: Color3, name: string)
	local height, halfWidth, thickness = 1.5 * s, 0.85 * s, 0.5 * s
	local turn = CFrame.fromMatrix(Vector3.zero, front, Vector3.yAxis) -- thin side faces the front
	local middle = CFrame.new(base + Vector3.new(0, height / 2 - 0.15 * s, 0)) * turn
	for _, k in { 1, -1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Size = Vector3.new(thickness, height, halfWidth)
		wedge.CFrame = middle
			* CFrame.new(0, 0, -k * halfWidth / 2)
			* (if k == -1 then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
		setUp(wedge, name, color, parent)
	end
end

-- Body shapes ------------------------------------------------------------------------------

type Body = {
	model: Model,
	center: Vector3, -- middle of the main body
	half: Vector3, -- half the main body's size
	front: Vector3, -- which way the face looks
	side: Vector3,
	s: number, -- how big the little details are
	color: Color3,
}

local function catDetails(b: Body, surface: Surface)
	for _, k in { -1, 1 } do
		local base = surface(b.front * 0.2 + b.side * (0.42 * k) + Vector3.yAxis)
		pointyEar(b.model, base, b.front, b.s, b.color, "Ear")
		pointyEar(b.model, base + b.front * (0.27 * b.s) + Vector3.new(0, 0.1 * b.s, 0), b.front, b.s * 0.6, COLORS.innerEar, "InnerEar")
	end
	face(b.model, surface, b.front, b.side, b.s, true)
end

local function bunnyDetails(b: Body, surface: Surface)
	for _, k in { -1, 1 } do
		local base = surface(-b.front * 0.15 + b.side * (0.3 * k) + Vector3.yAxis)
		local ear = CFrame.lookAt(base + Vector3.new(0, 1.4 * b.s, 0), base + Vector3.new(0, 1.4 * b.s, 0) + b.front)
			* CFrame.Angles(0, 0, math.rad(12) * k) -- tilted outwards a little
		blob(b.model, "Ear", Vector3.new(0.8, 3.2, 0.55) * b.s, ear, b.color)
		blob(b.model, "InnerEar", Vector3.new(0.45, 2.3, 0.2) * b.s, ear * CFrame.new(0, -0.1 * b.s, -0.22 * b.s), COLORS.innerEar)
	end
	onBody(b.model, surface, -b.front + Vector3.yAxis * 0.1, "Tail", Vector3.new(1.2, 1.2, 1.2) * b.s, COLORS.tail)
	face(b.model, surface, b.front, b.side, b.s, true)
end

local function bearDetails(b: Body, surface: Surface)
	for _, k in { -1, 1 } do
		local base = surface(b.front * 0.1 + b.side * (0.45 * k) + Vector3.yAxis)
		local ear = CFrame.lookAt(base + Vector3.new(0, 0.35 * b.s, 0), base + Vector3.new(0, 0.35 * b.s, 0) + b.front)
		blob(b.model, "Ear", Vector3.new(1.25, 1.25, 0.6) * b.s, ear, b.color)
		blob(b.model, "InnerEar", Vector3.new(0.65, 0.65, 0.2) * b.s, ear * CFrame.new(0, 0, -0.25 * b.s), COLORS.innerEar)
	end
	local muzzle = onBody(b.model, surface, b.front - Vector3.yAxis * 0.12, "Muzzle", Vector3.new(1.7, 1.1, 0.7) * b.s, COLORS.muzzle)
	blob(b.model, "Nose", Vector3.new(0.5, 0.32, 0.28) * b.s, muzzle.CFrame * CFrame.new(0, 0.18 * b.s, -0.32 * b.s), COLORS.nose)
	face(b.model, surface, b.front, b.side, b.s, false)
end

local function strawberryDetails(b: Body, surface: Surface)
	-- seeds all over, except on the face
	local placed = 0
	while placed < 14 do
		local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 0.75), rng:NextNumber(-1, 1))
		if direction.Magnitude < 0.1 then
			continue
		end
		local flat = Vector3.new(direction.X, 0, direction.Z)
		local nearFace = flat.Magnitude > 0.01 and flat.Unit:Dot(b.front) > 0.6 and direction.Y < 0.45
		if not nearFace then
			onBody(b.model, surface, direction, "Seed", Vector3.new(0.22, 0.32, 0.14) * b.s, COLORS.seed)
			placed += 1
		end
	end
	-- a ring of leaves and a stem on top
	local top = b.center + Vector3.new(0, b.half.Y, 0)
	for k = 0, 4 do
		local angle = k * math.pi * 2 / 5
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local spot = top + out * (0.8 * b.s) + Vector3.new(0, 0.05, 0)
		blob(b.model, "Leaf", Vector3.new(0.75, 0.3, 1.6) * b.s, CFrame.lookAt(spot, spot + out) * CFrame.Angles(math.rad(-12), 0, 0), COLORS.leaf)
	end
	blob(b.model, "Stem", Vector3.new(0.3, 0.8, 0.3) * b.s, CFrame.new(top + Vector3.new(0, 0.35 * b.s, 0)), COLORS.leaf)
	face(b.model, surface, b.front, b.side, b.s, true)
end

-- Build one squishy on a platform ---------------------------------------------------------

local function makeSquishy(platform: BasePart, info): Model
	-- footprint of the platform in the world (platforms here are only ever turned flat)
	local size, cf = platform.Size, platform.CFrame
	local footX = math.abs(cf.RightVector.X) * size.X + math.abs(cf.LookVector.X) * size.Z
	local footZ = math.abs(cf.RightVector.Z) * size.X + math.abs(cf.LookVector.Z) * size.Z
	local height = info.height or math.clamp(math.min(footX, footZ) * 0.55, 3.5, 6)
	local top = platform.Position.Y + size.Y / 2 + SINK
	local center = Vector3.new(platform.Position.X, top - height / 2, platform.Position.Z)
	local color = info.color or Color3.fromRGB(255, 170, 205)

	local toMiddle = Vector3.new(FACE_TOWARDS.X - center.X, 0, FACE_TOWARDS.Z - center.Z)
	local front = if toMiddle.Magnitude > 1 then toMiddle.Unit else Vector3.new(0, 0, -1)
	local side = front:Cross(Vector3.yAxis).Unit

	local model = Instance.new("Model")
	model.Name = info.kind
	model:SetAttribute("Pivot", Vector3.new(center.X, top, center.Z)) -- the squish happens around here

	local body: BasePart
	local half: Vector3
	if info.kind == "Needoh" and needoh and needoh:IsA("MeshPart") then
		local squishy = needoh:Clone()
		for _, child in squishy:GetChildren() do
			child:Destroy() -- leave the Needoh's own squish script behind
		end
		squishy.Size = Vector3.new(footX * 1.08, height, footZ * 1.08)
		squishy.CFrame = CFrame.new(center)
		setUp(squishy, "Body", color, model)
		body, half = squishy, squishy.Size / 2
	elseif info.kind == "Cupcake" then
		-- a frosting top on a round wrapper
		local diameter = math.min(footX, footZ) * 0.92
		local frostingHeight, wrapperHeight = height * 0.62, height * 0.5
		half = Vector3.new(diameter * 0.55, frostingHeight / 2, diameter * 0.55)
		local frostingCenter = Vector3.new(center.X, top - frostingHeight / 2, center.Z)
		body = blob(model, "Body", half * 2, CFrame.new(frostingCenter), COLORS.frosting)
		local wrapper = Instance.new("Part")
		wrapper.Shape = Enum.PartType.Cylinder -- a cylinder's length runs along its X side, so stand it up
		wrapper.Size = Vector3.new(wrapperHeight, diameter, diameter)
		local wrapperCenter = frostingCenter - Vector3.new(0, wrapperHeight / 2, 0)
		wrapper.CFrame = CFrame.new(wrapperCenter) * CFrame.Angles(0, 0, math.pi / 2)
		setUp(wrapper, "Wrapper", color, model)
		local s = math.min(footX, footZ) / 10
		local cherryTop = frostingCenter + Vector3.new(0, half.Y, 0)
		blob(model, "Cherry", Vector3.new(0.95, 0.95, 0.95) * s, CFrame.new(cherryTop + Vector3.new(0, 0.35 * s, 0)), COLORS.cherry)
		blob(model, "Stem", Vector3.new(0.12, 0.7, 0.12) * s, CFrame.new(cherryTop + Vector3.new(0, 0.95 * s, 0)) * CFrame.Angles(0, 0, 0.3), COLORS.leaf)
		local frostingSurface: Surface = function(direction)
			return onSurface(frostingCenter, half, direction)
		end
		for _ = 1, 14 do
			local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.25, 1), rng:NextNumber(-1, 1))
			local point, outward = frostingSurface(direction)
			local sprinkle = Instance.new("Part")
			sprinkle.Size = Vector3.new(0.14, 0.14, 0.45) * s
			sprinkle.CFrame = CFrame.lookAt(point, point + outward) * CFrame.Angles(math.pi / 2, rng:NextNumber(0, math.pi * 2), 0)
			setUp(sprinkle, "Sprinkle", COLORS.sprinkles[rng:NextInteger(1, #COLORS.sprinkles)], model)
		end
		-- the face goes on the wrapper
		local wrapperSurface: Surface = function(direction)
			local flat = Vector3.new(direction.X, 0, direction.Z).Unit
			local point = wrapperCenter + flat * (diameter / 2) + Vector3.new(0, direction.Y * wrapperHeight * 0.6, 0)
			return point, flat
		end
		face(model, wrapperSurface, front, side, s, true)
	else
		-- Cat, Bunny, Bear and Strawberry all have a round body
		half = Vector3.new(footX * 1.04, height, footZ * 1.04) / 2
		local bodyColor = if info.kind == "Strawberry" then COLORS.strawberry else color
		body = blob(model, "Body", half * 2, CFrame.new(center), bodyColor)
		local b: Body = {
			model = model,
			center = center,
			half = half,
			front = front,
			side = side,
			s = math.min(footX, footZ) / 10,
			color = bodyColor,
		}
		local surface: Surface = function(direction)
			return onSurface(center, half, direction)
		end
		if info.kind == "Cat" then
			catDetails(b, surface)
		elseif info.kind == "Bunny" then
			bunnyDetails(b, surface)
		elseif info.kind == "Bear" then
			bearDetails(b, surface)
		elseif info.kind == "Strawberry" then
			strawberryDetails(b, surface)
		end
	end
	model.PrimaryPart = body

	-- the sound and puff, played by Squishies.client.luau
	local effects = Instance.new("Attachment")
	effects.Name = "SquishEffects"
	effects.Parent = body
	effects.WorldPosition = Vector3.new(center.X, top - 0.2, center.Z)

	local sound = Instance.new("Sound")
	sound.Name = "SquishSound"
	sound.SoundId = SQUISH_SOUND
	sound.Volume = 0.8
	sound.RollOffMaxDistance = 60
	sound.Parent = effects

	local puff = Instance.new("ParticleEmitter")
	puff.Name = "SquishPuff"
	puff.Enabled = false
	puff.Rate = 0
	puff.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	puff.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	puff.Lifetime = NumberRange.new(0.3, 0.6)
	puff.Speed = NumberRange.new(4, 9)
	puff.SpreadAngle = Vector2.new(70, 70)
	puff.EmissionDirection = Enum.NormalId.Top
	puff.Drag = 4
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	puff.LightEmission = 0.4
	puff.Parent = effects

	return model
end

-- Find each platform by where its top middle is -----------------------------------------------

local platforms: { [number]: BasePart } = {}
for _, part in tower:GetDescendants() do
	if part:IsA("BasePart") and part.Name == "Part" then
		local top = part.Position.Y + part.Size.Y / 2
		for index, info in SQUISHIES do
			if
				math.abs(part.Position.X - info.at.X) < 0.3
				and math.abs(part.Position.Z - info.at.Z) < 0.3
				and math.abs(top - info.at.Y) < 0.3
			then
				platforms[index] = part
			end
		end
	end
end

local folder = Instance.new("Folder")
folder.Name = "Squishies"

local made, kinds = 0, {}
for index, info in SQUISHIES do
	local platform = platforms[index]
	if not platform then
		warn(`[Squishies] Couldn't find the platform for squishy {index}: skipped`)
		continue
	end
	local squishy = makeSquishy(platform, info)
	squishy.Parent = folder

	-- hide the plain platform (it still holds you up) and give it a new name, so the tower
	-- keyboards don't cover it in keys
	platform.Transparency = 1
	for _, child in platform:GetChildren() do
		if child:IsA("Decal") or child:IsA("Texture") then
			child.Transparency = 1
		end
	end
	platform.Name = "Squishy Platform"

	-- landing on it squishes it
	local top = platform.Position.Y + platform.Size.Y / 2
	local lastSquish = 0
	platform.Touched:Connect(function(hit)
		local character = hit.Parent
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or not character:FindFirstChildOfClass("Humanoid") then
			return
		end
		if root.Position.Y < top then
			return -- bumped it from the side or below, not landed on it
		end
		local now = os.clock()
		if now - lastSquish < SQUISH_COOLDOWN then
			return
		end
		lastSquish = now
		squishEvent:FireAllClients(squishy)
	end)
	made += 1
	kinds[info.kind] = (kinds[info.kind] or 0) + 1
end

folder.Parent = tower
finish()
local list = {}
for kind, count in kinds do
	table.insert(list, `{count} {kind}`)
end
table.sort(list)
print(`[Squishies] Made {made} squishy jumps in the tower: {table.concat(list, ", ")}`)
