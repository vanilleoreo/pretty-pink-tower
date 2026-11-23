-- The squish effect for the squishy jumps in the tower (made by Squishies.server.luau).
-- When someone lands on a squishy, the whole thing (body, ears, leaves, cherry...) squashes down
-- and bulges out, then wobbles back like jelly, with a squish (or crunch) sound and a little
-- sparkly puff.
-- It happens on your own screen so it's smooth.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SQUASH = 0.7 -- how flat it gets (0.7 = 70% of its height)
local BULGE = 1.12 -- how much wider it gets while squashed
local TOP_DROP = 0.4 -- how far its top sinks under your feet
local SQUASH_TIME = 0.09 -- seconds to squash down
local WOBBLE_TIME = 0.8 -- seconds to wobble back

local squishEvent = ReplicatedStorage:WaitForChild("Squish") :: RemoteEvent

local rest = setmetatable({}, { __mode = "k" }) -- each part's normal size and position
local tweens = setmetatable({}, { __mode = "k" }) -- the squish that's playing on each part

-- How much a side of a part stretches: sides pointing up get squashed, sideways ones bulge
local function stretch(axis: Vector3): number
	return axis.X * axis.X * BULGE + axis.Y * axis.Y * SQUASH + axis.Z * axis.Z * BULGE
end

local function squishPart(part: BasePart, pivot: Vector3)
	local normal = rest[part]
	if not normal then
		normal = { size = part.Size, cframe = part.CFrame }
		rest[part] = normal
	end
	local size, cframe = normal.size, normal.cframe

	-- everything moves towards the top middle, squashed down and pushed outwards
	local offset = cframe.Position - pivot
	local squashedPosition = pivot + Vector3.new(offset.X * BULGE, offset.Y * SQUASH - TOP_DROP, offset.Z * BULGE)
	local squashedSize = size
		* Vector3.new(stretch(cframe.RightVector), stretch(cframe.UpVector), stretch(cframe.LookVector))
	local squashedCFrame = CFrame.new(squashedPosition) * cframe.Rotation

	local playing = tweens[part]
	if playing then
		playing:Cancel()
	end
	local squash = TweenService:Create(
		part,
		TweenInfo.new(SQUASH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = squashedSize, CFrame = squashedCFrame }
	)
	tweens[part] = squash
	squash.Completed:Connect(function(state)
		if state ~= Enum.PlaybackState.Completed then
			return
		end
		local wobble = TweenService:Create(
			part,
			TweenInfo.new(WOBBLE_TIME, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{ Size = size, CFrame = cframe }
		)
		tweens[part] = wobble
		wobble:Play()
	end)
	squash:Play()
end

squishEvent.OnClientEvent:Connect(function(squishy)
	-- (it can be missing if it's far away and hasn't loaded on this screen)
	if typeof(squishy) ~= "Instance" or not squishy:IsDescendantOf(workspace) then
		return
	end

	local parts = {}
	if squishy:IsA("BasePart") then
		table.insert(parts, squishy)
	end
	for _, descendant in squishy:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	if #parts == 0 then
		return
	end

	local pivot = squishy:GetAttribute("Pivot")
	if typeof(pivot) ~= "Vector3" then
		local first = parts[1]
		pivot = first.Position + Vector3.new(0, first.Size.Y / 2, 0)
	end
	for _, part in parts do
		squishPart(part, pivot)
	end

	local effects = squishy:FindFirstChild("SquishEffects", true)
	local sound = effects and effects:FindFirstChild("SquishSound")
	if sound and sound:IsA("Sound") then
		-- a slightly different pitch each time (crunchy squishies are set higher)
		local low = sound:GetAttribute("PitchMin") or 0.8
		local high = sound:GetAttribute("PitchMax") or 1.1
		sound.PlaybackSpeed = low + math.random() * (high - low)
		sound:Play()
	end
	local puff = effects and effects:FindFirstChild("SquishPuff")
	if puff and puff:IsA("ParticleEmitter") then
		puff:Emit(14)
	end
end)
