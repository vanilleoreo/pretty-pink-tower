-- Cherry blossom petals drifting down from the sky, all around you wherever you go.
--
-- Each petal floats down with the wind, lands on whatever is below it (so petals don't fall
-- through roofs into rooms), lies there for a moment, then starts again somewhere near you.
-- The petals are made on your own screen, so they cost the server nothing.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PETALS = 110 -- how many petals are around you at once
local RADIUS = 50 -- how far around you they fall (studs)
local START_ABOVE = { 8, 45 } -- how high above your camera a new petal starts (studs)
local FALL_SPEED = { 2.5, 5 } -- studs per second
local REST_TIME = { 1.5, 4 } -- seconds a petal lies on the ground before floating down again
local WIND = Vector3.new(1.2, 0, 0.6) -- a gentle breeze (studs per second)
local PETAL_SIZE = Vector3.new(0.6, 0.06, 0.45)
local COLORS = {
	Color3.fromRGB(255, 183, 213),
	Color3.fromRGB(255, 160, 200),
	Color3.fromRGB(255, 205, 226),
	Color3.fromRGB(255, 236, 244),
}

local player = Players.LocalPlayer
local rng = Random.new()

-- Parts inside the camera only exist on this screen
local folder = Instance.new("Folder")
folder.Name = "FallingPetals"
folder.Parent = workspace.CurrentCamera

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true -- land on floors and roofs, not on see-through decorations

local function updateFilter()
	rayParams.FilterDescendantsInstances = { folder, player.Character :: any }
end
updateFilter()
player.CharacterAdded:Connect(updateFilter)

type Petal = {
	part: BasePart,
	position: Vector3,
	turn: CFrame, -- which way it's tumbling
	spin: Vector3, -- how fast it tumbles
	speed: number,
	sway: number,
	swaySpeed: number,
	phase: number,
	landY: number, -- height of whatever it will land on
	restUntil: number?, -- set while it's lying on the ground
}

local petals: { Petal } = {}
local parts: { BasePart } = {}
local cframes: { CFrame } = {}

-- Start (or restart) a petal somewhere above and around the camera.
-- startAnywhere = put it anywhere between the sky and the ground (used when the game starts,
-- so the sky isn't empty while the first petals fall)
local function restart(petal: Petal, startAnywhere: boolean)
	local focus = workspace.CurrentCamera.CFrame.Position
	local angle, distance = rng:NextNumber(0, math.pi * 2), RADIUS * math.sqrt(rng:NextNumber())
	local start = Vector3.new(
		focus.X + math.cos(angle) * distance,
		focus.Y + rng:NextNumber(START_ABOVE[1], START_ABOVE[2]),
		focus.Z + math.sin(angle) * distance
	)
	petal.speed = rng:NextNumber(FALL_SPEED[1], FALL_SPEED[2])

	-- where will it land? follow the way it drifts (down + wind)
	local drift = Vector3.new(WIND.X, -petal.speed, WIND.Z).Unit
	local hit = workspace:Raycast(start, drift * 300, rayParams)
	petal.landY = if hit then hit.Position.Y + PETAL_SIZE.Y / 2 else -math.huge

	if startAnywhere and hit then
		start = start:Lerp(hit.Position, rng:NextNumber(0, 0.95))
	end
	petal.position = start
	petal.restUntil = nil
end

for i = 1, PETALS do
	local part = Instance.new("Part")
	part.Name = "Petal"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = PETAL_SIZE
	part.Material = Enum.Material.SmoothPlastic
	part.Color = COLORS[rng:NextInteger(1, #COLORS)]
	local mesh = Instance.new("SpecialMesh") -- rounded, like a petal, instead of a flat block
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = folder

	local petal: Petal = {
		part = part,
		position = Vector3.zero,
		turn = CFrame.Angles(rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3)),
		spin = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-2, 2), rng:NextNumber(-3, 3)),
		speed = 3,
		sway = rng:NextNumber(0.6, 1.6),
		swaySpeed = rng:NextNumber(1, 2.2),
		phase = rng:NextNumber(0, math.pi * 2),
		landY = -math.huge,
		restUntil = nil,
	}
	restart(petal, true)
	petals[i] = petal
	parts[i] = part
	cframes[i] = CFrame.new(petal.position)
end

local clock = 0
RunService.RenderStepped:Connect(function(deltaTime)
	clock += deltaTime
	local focus = workspace.CurrentCamera.CFrame.Position

	for i, petal in petals do
		if petal.restUntil then
			if clock >= petal.restUntil then
				restart(petal, false)
			end
		else
			local wobble = Vector3.new(
				math.sin(clock * petal.swaySpeed + petal.phase) * petal.sway,
				-petal.speed,
				math.cos(clock * petal.swaySpeed * 0.7 + petal.phase) * petal.sway
			)
			petal.position += (WIND + wobble) * deltaTime
			petal.turn *= CFrame.Angles(petal.spin.X * deltaTime, petal.spin.Y * deltaTime, petal.spin.Z * deltaTime)

			if petal.position.Y <= petal.landY then
				-- landed: lie flat for a moment
				petal.position = Vector3.new(petal.position.X, petal.landY, petal.position.Z)
				petal.turn = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				petal.restUntil = clock + rng:NextNumber(REST_TIME[1], REST_TIME[2])
			end
		end

		-- you walked, flew or teleported away from it: bring it back near you
		local offset = petal.position - focus
		if offset.X * offset.X + offset.Z * offset.Z > (RADIUS + 20) ^ 2 or math.abs(offset.Y) > 90 then
			restart(petal, true) -- anywhere in the air, so a teleport doesn't leave you with an empty sky
		end

		cframes[i] = CFrame.new(petal.position) * petal.turn
	end

	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end)
