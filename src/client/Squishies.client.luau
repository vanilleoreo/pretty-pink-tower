-- The squish effect for the squishy jumps in the tower (made by Squishies.server.luau).
-- When someone lands on a squishy, it squashes down and bulges out, then wobbles back like jelly,
-- with a squish sound and a little sparkly puff. It happens on your own screen so it's smooth.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SQUASH = 0.7 -- how flat it gets (0.7 = 70% of its height)
local BULGE = 1.12 -- how much wider it gets while squashed
local TOP_DROP = 0.4 -- how far its top sinks under your feet
local SQUASH_TIME = 0.09 -- seconds to squash down
local WOBBLE_TIME = 0.8 -- seconds to wobble back

local squishEvent = ReplicatedStorage:WaitForChild("Squish") :: RemoteEvent

local normal = setmetatable({}, { __mode = "k" }) -- each squishy's normal size and position
local tweens = setmetatable({}, { __mode = "k" }) -- the squish that's playing on each squishy

squishEvent.OnClientEvent:Connect(function(squishy)
	-- (it can be missing if it's far away and hasn't loaded on this screen)
	if typeof(squishy) ~= "Instance" or not squishy:IsA("BasePart") or not squishy:IsDescendantOf(workspace) then
		return
	end

	local rest = normal[squishy]
	if not rest then
		rest = { size = squishy.Size, cframe = squishy.CFrame }
		normal[squishy] = rest
	end

	local size, cframe = rest.size, rest.cframe
	local top = cframe.Position.Y + size.Y / 2
	local squashedSize = Vector3.new(size.X * BULGE, size.Y * SQUASH, size.Z * BULGE)
	local squashedCFrame = cframe + Vector3.new(0, top - TOP_DROP - squashedSize.Y / 2 - cframe.Position.Y, 0)

	local playing = tweens[squishy]
	if playing then
		playing:Cancel()
	end
	local squash = TweenService:Create(
		squishy,
		TweenInfo.new(SQUASH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = squashedSize, CFrame = squashedCFrame }
	)
	tweens[squishy] = squash
	squash.Completed:Connect(function(state)
		if state ~= Enum.PlaybackState.Completed then
			return
		end
		local wobble = TweenService:Create(
			squishy,
			TweenInfo.new(WOBBLE_TIME, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{ Size = size, CFrame = cframe }
		)
		tweens[squishy] = wobble
		wobble:Play()
	end)
	squash:Play()

	local effects = squishy:FindFirstChild("SquishEffects")
	local sound = effects and effects:FindFirstChild("SquishSound")
	if sound and sound:IsA("Sound") then
		sound.PlaybackSpeed = 0.8 + math.random() * 0.3 -- a slightly different squish each time
		sound:Play()
	end
	local puff = effects and effects:FindFirstChild("SquishPuff")
	if puff and puff:IsA("ParticleEmitter") then
		puff:Emit(14)
	end
end)
