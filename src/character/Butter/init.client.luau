local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CONFIG = {
	DentDepth = 2,
	DentRadius = 15,
	DentPressSpeed = 9,
	DentReleaseSpeed = 1.2,
	DentFalloff = 2,
	SinkSpeed = 10,
	RiseSpeed = 2,
	StepGap = 0.65,
	StepSpeedMin = 4,
	ButterWalkSpeed = 10,
	Volume = 1,
	CullDistance = 120,
}

local player = Players.LocalPlayer
local soundTemplate = script:WaitForChild("ButterSound")
local butterObjects = {}
local character, humanoid, rootPart
local savedWalkSpeed
local rng = Random.new()

local function playButterSound(surface, pitch)
	local sound = soundTemplate:Clone()
	sound.Name = "ButterASMR"
	sound.Volume = CONFIG.Volume
	sound.PlaybackSpeed = pitch or rng:NextNumber(0.94, 1.06)
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 55
	sound.Parent = surface
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(6, function()
		if sound.Parent then sound:Destroy() end
	end)
end


local function resetButter(data)
	for bone, rest in pairs(data.Rest) do
		if bone.Parent then bone.Position = rest end
	end
	data.Offsets = {}
	data.Sink = 0
	if data.Collision and data.Collision.Parent then
		data.Collision.CFrame = data.BaseCollisionCF
	end
	data.Inside = false
	data.WasInside = false
end

local function registerButter(model)
	if butterObjects[model] or not model:IsA("Model") then return end
	if model:GetAttribute("ASMRType") ~= "Butter" then return end

	local surface = model:FindFirstChild("Surface", true)
	if not (surface and surface:IsA("MeshPart")) then return end

	local bones, rest, worldXZ = {}, {}, {}
	for _, item in ipairs(surface:GetDescendants()) do
		if item:IsA("Bone") and item.Name ~= "Root" then
			table.insert(bones, item)
			rest[item] = item.Position
			worldXZ[item] = Vector2.new(item.WorldPosition.X, item.WorldPosition.Z)
		end
	end
	if #bones == 0 then
		warn("[Butter] " .. model:GetFullName() .. " has no deform bones")
		return
	end

	local height = 5 + CONFIG.DentDepth
	local collision = Instance.new("Part")
	collision.Name = "ButterCollision"
	collision.Anchored = true
	collision.Transparency = 1
	collision.CanCollide = true
	collision.CanQuery = false
	collision.CanTouch = false
	collision.CastShadow = false
	collision.Size = Vector3.new(surface.Size.X * 0.98, 0.15, surface.Size.Z * 0.98)
	local baseCollisionCF = surface.CFrame * CFrame.new(0, surface.Size.Y / 2 - collision.Size.Y / 2, 0)
	collision.CFrame = baseCollisionCF

	surface.CanCollide = false
	butterObjects[model] = {
		Model = model,
		Surface = surface,
		Bones = bones,
		Rest = rest,
		WorldXZ = worldXZ,
		Offsets = {},
		Collision = collision,
		BaseCollisionCF = baseCollisionCF,
		TriggerCF = surface.CFrame * CFrame.new(0, surface.Size.Y / 2 + height / 2 - CONFIG.DentDepth - 0.5, 0),
		TriggerSize = Vector3.new(surface.Size.X * 0.98, height, surface.Size.Z * 0.98),
		Sink = 0,
		Inside = false,
		WasInside = false,
		LastStep = 0,
	}
	collision.Parent = model
end

for _, item in ipairs(Workspace:GetDescendants()) do registerButter(item) end
Workspace.DescendantAdded:Connect(function(item)
	registerButter(item)
	local ancestor = item.Parent
	while ancestor and ancestor ~= Workspace do
		if ancestor:IsA("Model") and ancestor:GetAttribute("ASMRType") == "Butter" then
			registerButter(ancestor)
			break
		end
		ancestor = ancestor.Parent
	end
end)
Workspace.DescendantRemoving:Connect(function(item)
	local data = butterObjects[item]
	if data then
		resetButter(data)
		butterObjects[item] = nil
	end
end)

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.MaxParts = 8

local function bindCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")
	savedWalkSpeed = nil
end

if player.Character then task.spawn(bindCharacter, player.Character) end
player.CharacterAdded:Connect(bindCharacter)

RunService.Heartbeat:Connect(function(dt)
	if not (character and humanoid and rootPart and humanoid.Health > 0) then return end
	overlap.FilterDescendantsInstances = { character }

	local playerXZ = Vector2.new(rootPart.Position.X, rootPart.Position.Z)
	local now = os.clock()
	local standingOnButter = false

	for model, data in pairs(butterObjects) do
		if not model.Parent or not data.Surface.Parent then
			if data.Collision then data.Collision:Destroy() end
			butterObjects[model] = nil
			continue
		end

		local delta = data.Surface.Position - rootPart.Position
		if delta:Dot(delta) > CONFIG.CullDistance * CONFIG.CullDistance then
			if data.Inside or data.Sink ~= 0 then resetButter(data) end
			continue
		end

		data.WasInside = data.Inside
		data.Inside = #Workspace:GetPartBoundsInBox(data.TriggerCF, data.TriggerSize, overlap) > 0
		standingOnButter = standingOnButter or data.Inside

		local weightedSink, weightTotal = 0, 0
		for _, bone in ipairs(data.Bones) do
			if bone.Parent then
				local target = 0
				local distance = (data.WorldXZ[bone] - playerXZ).Magnitude
				if data.Inside and distance < CONFIG.DentRadius then
					local strength = 1 - distance / CONFIG.DentRadius
					target = -CONFIG.DentDepth * strength ^ CONFIG.DentFalloff
				end

				local current = data.Offsets[bone] or 0
				local rate = target < current and CONFIG.DentPressSpeed or CONFIG.DentReleaseSpeed
				current += (target - current) * math.min(1, rate * dt)
				if math.abs(current) < 0.002 and target == 0 then current = 0 end
				data.Offsets[bone] = current
				bone.Position = data.Rest[bone] + Vector3.new(0, current, 0)

				if data.Inside then
					local weight = 1 / math.max(distance, 0.05)
					weightedSink += current * weight
					weightTotal += weight
				end
			end
		end

		local targetSink = data.Inside and (weightTotal > 0 and weightedSink / weightTotal or 0) or 0
		local sinkRate = targetSink < data.Sink and CONFIG.SinkSpeed or CONFIG.RiseSpeed
		data.Sink += (targetSink - data.Sink) * math.min(1, sinkRate * dt)
		if math.abs(data.Sink) < 0.01 and not data.Inside then data.Sink = 0 end
		data.Collision.CFrame = data.BaseCollisionCF * CFrame.new(0, data.Sink, 0)

		if data.Inside and not data.WasInside then
			playButterSound(data.Surface, 0.9)
		elseif data.WasInside and not data.Inside then
			playButterSound(data.Surface, 1.05)
		end

		if data.Inside then
			local horizontalSpeed = Vector2.new(rootPart.AssemblyLinearVelocity.X, rootPart.AssemblyLinearVelocity.Z).Magnitude
			if horizontalSpeed > CONFIG.StepSpeedMin and now - data.LastStep >= CONFIG.StepGap then
				data.LastStep = now
				playButterSound(data.Surface)
			end
		end
	end

	-- Butter no longer slows you down. The dent, sink and ASMR squish sounds above
	-- still play; only the WalkSpeed change was removed (standingOnButter is left
	-- computed so this is a one-line job to re-enable later if you ever want it).
end)